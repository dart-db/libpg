import 'dart:async';
import 'dart:collection';

import 'package:channel/channel.dart';
import 'package:libpg/libpg.dart';
import 'package:libpg/src/connection/row.dart';
import 'package:libpg/src/util/generator.dart';
import 'package:libpg/src/logger/logger.dart';
import 'package:libpg/src/message/row_description.dart';
import 'package:pedantic/pedantic.dart';

abstract class PGPool implements Querier {
  factory PGPool(ConnSettings settings,
          {Logger? logger,
          int? maxConnections,
          int? maxIdleConnections,
          Duration? idleConnectionTimeout,
          Duration? connectionReuseTimeout}) =>
      _PGPoolImpl(settings,
          logger: logger,
          maxConnections: maxConnections,
          maxIdleConnections: maxIdleConnections,
          idleConnectionTimeout: idleConnectionTimeout,
          connectionReuseTimeout: connectionReuseTimeout);

  set maxConnections(int? value);

  int? get maxConnections;

  set maxIdleConnections(int? value);

  int? get maxIdleConnections;

  Future<Connection> createConnection();

  PoolStats get poolStats;

  Future<PoolQuerier> acquireConnection();

  Future<void> close();
}

class _PGPoolImpl implements PGPool {
  @override
  final ConnSettings settings;

  int? _maxConnections;

  int? _maxIdleConnections;

  Duration? _idleConnectionTimeout;

  Duration? _connectionReuseTimeout;

  final _connections = HashSet<Connection>();

  final _usedConnections = HashSet<Connection>();

  final _idleConnections = <Connection>{};

  final _idleTimes = HashMap<Connection, DateTime>();

  Timer? _idleTimer;

  final _idleAdded = Channel<void>();

  final Logger _logger;

  final IdGenerator _queryIdGenerator;

  _PGPoolImpl(this.settings,
      {Logger? logger,
      IdGenerator? queryIdGenerator,
      int? maxConnections,
      int? maxIdleConnections,
      Duration? idleConnectionTimeout,
      Duration? connectionReuseTimeout})
      : _logger = logger ?? nopLogger,
        _queryIdGenerator = queryIdGenerator ?? IdGenerator(prefix: 'query') {
    this.maxConnections = maxConnections;
    this.maxIdleConnections = maxIdleConnections;
    this.idleConnectionTimeout = idleConnectionTimeout;
    this.connectionReuseTimeout = connectionReuseTimeout;
  }

  @override
  int? get maxConnections => _maxConnections;

  @override
  set maxConnections(int? value) {
    if (value != null && value <= 0) value = null;
    _maxConnections = value;

    _whenExceedMaxConnections();
  }

  @override
  int? get maxIdleConnections => _maxIdleConnections;

  @override
  set maxIdleConnections(int? value) {
    if (value != null && value <= 0) value = null;

    _maxIdleConnections = value;

    _whenExceedIdleConnections();
  }

  Duration? get idleConnectionTimeout => _idleConnectionTimeout;

  set idleConnectionTimeout(Duration? value) {
    if (value != null && value.isNegative) value = null;

    _idleConnectionTimeout = value;
  }

  Duration? get connectionReuseTimeout => _connectionReuseTimeout;

  set connectionReuseTimeout(Duration? value) {
    if (value != null && value.isNegative) value = null;

    _connectionReuseTimeout = value;
  }

  @override
  Rows query(String query, {String? queryName}) {
    if (_closed) throw Exception('Closed');

    final controller = StreamController<Row>();
    final completer = Completer<CommandTag>();
    _getConnection().then((connection) {
      _logger(LogMessage(
          connectionName: connection.connectionName,
          connectionId: connection.connectionId,
          queryName: queryName,
          message: 'Got connection from the pool'));
      try {
        final ret = connection.query(query, queryName: queryName);
        controller.addStream(ret, cancelOnError: true).then((_) {
          controller.close();
        }).catchError((e, t) {
          controller.addError(e, t);
        });
        ret.finished.then((tag) {
          completer.complete(tag);
          unawaited(_releaseConnectionToPool(connection));
        }, onError: (e, s) {
          completer.completeError(e, s);
          unawaited(_releaseConnectionToPool(connection));
        });
      } catch (e, s) {
        if (connection != null) {
          unawaited(_releaseConnectionToPool(connection));
        }
        controller.addError(e, s);
        completer.completeError(e, s);
      }
    });
    return Rows(controller.stream, completer.future);
  }

  @override
  Future<CommandTag> execute(String query, {String? queryName}) async {
    if (_closed) throw Exception('Closed');

    Connection? connection;
    CommandTag ret;
    try {
      connection = await _getConnection();
      ret = await connection.execute(query, queryName: queryName);
    } catch (e) {
      if (connection != null) {
        unawaited(_releaseConnectionToPool(connection));
      }
      rethrow;
    }

    unawaited(_releaseConnectionToPool(connection));

    return ret;
  }

  @override
  Future<PreparedQuery> prepare(String query,
      {String statementName = '',
      String? queryName,
      List<int> paramOIDs = const []}) async {
    if (_closed) throw Exception('Closed');

    Connection? connection;
    PreparedQuery ret;

    try {
      connection = await _getConnection();
      ret = await connection.prepare(query,
          statementName: statementName,
          queryName: queryName,
          paramOIDs: paramOIDs);
      unawaited(_releaseConnectionToPool(connection));
      return PoolPreparedQuery(this, ret as PreparedQueryImpl);
    } catch (e) {
      if (connection != null) {
        unawaited(_releaseConnectionToPool(connection));
      }
      rethrow;
    }
  }

  @override
  Rows queryPrepared(PreparedQuery query, List<dynamic> params,
      {String? queryName}) {
    if (_closed) throw Exception('Closed');

    if (query is! PoolPreparedQuery) {
      throw Exception(
          'PreparedQuery does not belong to a connection in this pool');
    }

    final connection = query._inner.connection as Connection;
    if (!_connections.contains(connection)) {
      throw Exception(
          'PreparedQuery does not belong to a connection in this pool');
    }

    final controller = StreamController<Row>();
    final completer = Completer<CommandTag>();
    _awaitForConnection(connection).then((connection) {
      try {
        final ret =
            connection.queryPrepared(query, params, queryName: queryName);
        controller.addStream(ret, cancelOnError: true).then((_) {
          controller.close();
        }).catchError((e, t) {
          controller.addError(e, t);
        });
        ret.finished.then((tag) {
          unawaited(_releaseConnectionToPool(connection));
          completer.complete(tag);
        }, onError: (e, s) {
          unawaited(_releaseConnectionToPool(connection));
          completer.completeError(e, s);
        });
      } catch (e, s) {
        if (connection != null) {
          unawaited(_releaseConnectionToPool(connection));
        }
        controller.addError(e, s);
        completer.completeError(e, s);
      }
    });
    return Rows(controller.stream, completer.future);
  }

  @override
  Future<void> releasePrepared(PreparedQuery query) async {
    if (_closed) throw Exception('Closed');

    if (query is! PoolPreparedQuery) {
      throw Exception(
          'PreparedQuery does not belong to a connection in this pool');
    }

    final connection = query._inner.connection as Connection;
    if (!_connections.contains(connection)) {
      throw Exception(
          'PreparedQuery does not belong to a connection in this pool');
    }

    await _awaitForConnection(connection);
    try {
      await connection.releasePrepared(query._inner);
    } catch (_) {
      unawaited(_releaseConnectionToPool(connection));
      rethrow;
    }
    unawaited(_releaseConnectionToPool(connection));
  }

  @override
  Future<PoolQuerier> acquireConnection() async {
    if (_closed) throw Exception('Closed');

    final connection = await _getConnection();
    if (connection == null) {
      throw Exception('error acquiring connection');
    }

    return _Connection(this, connection);
  }

  Future<void>? _getConnectionSequencer;

  Future<Connection> _getConnection() async {
    while (_getConnectionSequencer != null) {
      await _getConnectionSequencer;
    }

    final completer = Completer<void>();

    _getConnectionSequencer = completer.future;

    try {
      final ret = await _getConnectionInner();
      completer.complete();
      _getConnectionSequencer = null;
      return ret;
    } catch (_) {
      completer.complete();
      _getConnectionSequencer = null;
      rethrow;
    }
  }

  Future<Connection> _getConnectionInner() async {
    if (_idleConnections.isEmpty) {
      if (_maxConnections == null || _connections.length < _maxConnections!) {
        final connection = await createConnection(logger: _logger);
        _poolStats.totalConnectionsMade++;

        _logger(LogMessage(
            connectionName: connection.connectionName,
            connectionId: connection.connectionId,
            message: 'Established new connection for the pool'));

        _connections.add(connection);
        _usedConnections.add(connection);
        return connection;
      }

      DateTime start = DateTime.now();
      while (true) {
        if ((await _idleAdded.receive()).isClosed) {
          throw Exception('Closed');
        }

        final connection = _getLongestIdleConnection();
        if (connection != null) {
          _poolStats.addIdleWaitTime(DateTime.now().difference(start));
          return connection;
        }
      }
    }

    final connection = _getLongestIdleConnection()!;
    _usedConnections.add(connection);

    return connection;
  }

  Future<void> _removeConnection(Connection connection) {
    _logger(LogMessage(
        connectionName: connection.connectionName,
        connectionId: connection.connectionId,
        message: 'Closing and removing connection from the pool'));

    _usedConnections.remove(connection);
    _connections.remove(connection);
    _removeIdleConnection(connection);

    final completers = _waiting[connection];
    if (completers != null) {
      for (final completer in completers) {
        completer.completeError(Exception('Closed'));
      }
    }

    return connection.close().catchError((e) {
      // TODO
    });
  }

  Future<void> _releaseConnectionToPool(Connection connection,
      {String? queryName}) {
    _logger(LogMessage(
        connectionName: connection.connectionName,
        connectionId: connection.connectionId,
        queryName: queryName,
        message: 'Releasing connection to the pool'));
    _usedConnections.remove(connection);

    if (_closed) return _removeConnection(connection);

    if (_maxConnections != null && _connections.length > _maxConnections!) {
      return _removeConnection(connection);
    }

    // TODO check if connection is dead?

    final completers = _waiting[connection];
    if (completers != null) {
      final completer = completers.removeAt(0);
      if (completers.isEmpty) {
        _waiting.remove(connection);
      }
      completer.complete(connection);
      return Future.value();
    }
    _addIdleConnection(connection);

    return Future.value();
  }

  final _waiting = <Connection, List<Completer<Connection>>>{};

  Future<Connection> _awaitForConnection(Connection connection) async {
    if (_idleConnections.contains(connection)) {
      _removeIdleConnection(connection);
      return connection;
    }

    final completer = Completer<Connection>();
    List<Completer<Connection>>? completers = _waiting[connection];
    completers ??= _waiting[connection] = <Completer<Connection>>[];
    completers.add(completer);
    return completer.future;
  }

  Connection? _getLongestIdleConnection() {
    if (_idleConnections.isNotEmpty) {
      final connection = _idleConnections.first;
      _removeIdleConnection(connection);

      return connection;
    }

    return null;
  }

  void _addIdleConnection(Connection connection) {
    _idleTimer?.cancel();

    _idleConnections.add(connection);
    _idleTimes[connection] = DateTime.now();

    _idleAdded.send(null);

    _updateIdleTimer();
  }

  void _removeIdleConnection(Connection connection) {
    _idleTimer?.cancel();

    _idleConnections.remove(connection);
    _idleTimes.remove(connection);

    _updateIdleTimer();
  }

  void _updateIdleTimer() {
    _idleTimer = null;

    if (_idleConnections.isEmpty) return;

    Duration? duration = _connectionReuseTimeout;

    if (_maxIdleConnections != null &&
        (_connections.length - _usedConnections.length) < _maxIdleConnections!) {
      if (duration != null &&
          _idleConnectionTimeout != null &&
          _idleConnectionTimeout! < duration) {
        duration = _idleConnectionTimeout;
      }
    }

    if (duration == null) return;

    DateTime.now().difference(_idleTimes[_idleConnections.first]!);
    _idleTimer = Timer(duration, _doIdleTimer);
  }

  void _doIdleTimer() {
    _whenExceedMaxConnections();
    _whenExceedIdleConnections();
    _whenBelowIdleConnections();

    _updateIdleTimer();
  }

  void _whenExceedMaxConnections() {
    _idleTimer?.cancel();

    if (_maxConnections == null) return;

    while (_connections.length > _maxConnections!) {
      final connection = _getLongestIdleConnection();
      if (connection == null) break;
      _removeConnection(connection);
    }
  }

  void _whenExceedIdleConnections() {
    _idleTimer?.cancel();

    if (_maxIdleConnections == null || _connectionReuseTimeout == null) return;

    while (_idleConnections.isNotEmpty &&
        (_connections.length - _usedConnections.length) > _maxIdleConnections!) {
      final connection = _idleConnections.first;
      final at = _idleTimes[connection]!;
      if (DateTime.now().difference(at) < _connectionReuseTimeout!) break;
      _removeConnection(connection);
    }
  }

  void _whenBelowIdleConnections() {
    _idleTimer?.cancel();

    if (_idleConnectionTimeout == null) return;

    while (_idleConnections.isNotEmpty) {
      final connection = _idleConnections.first;
      final at = _idleTimes[connection]!;
      if (DateTime.now().difference(at) < _idleConnectionTimeout!) break;
      _removeConnection(connection);
    }
  }

  bool _closed = false;

  @override
  Future<void> close() async {
    if (_closed) return;

    _closed = true;

    while (_idleConnections.isNotEmpty) {
      await _removeConnection(_idleConnections.first);
    }
  }

  final _poolStats = _PoolStats();

  @override
  PoolStats get poolStats =>
      _poolStats.toImmutable(_connections.length, _idleConnections.length);

  @override
  Future<Connection> createConnection(
      {String? connectionName, Logger? logger}) async {
    final connection = await Connection.connect(settings,
        connectionName: connectionName,
        logger: logger,
        queryIdGenerator: _queryIdGenerator);

    return connection;
  }
}

class _PoolStats {
  Duration idleWaitTime = Duration();

  int totalConnectionsMade = 0;

  PoolStats toImmutable(int open, int idle) => PoolStats(
      open: open,
      idle: idle,
      idleWaitTime: idleWaitTime,
      totalConnectionsMade: totalConnectionsMade);

  void addIdleWaitTime(Duration duration) {
    idleWaitTime = idleWaitTime + duration;
  }
}

class PoolStats {
  final int open;

  final int idle;

  final Duration idleWaitTime;

  final int totalConnectionsMade;

  PoolStats(
      {required this.open,
      required this.idle,
      required this.idleWaitTime,
      required this.totalConnectionsMade});
}

abstract class PoolQuerier implements Querier {
  void release();
}

class _Connection implements PoolQuerier {
  final _PGPoolImpl pool;

  Connection? _connection;

  _Connection(this.pool, this._connection);

  @override
  ConnSettings get settings {
    if (_connection == null) {
      throw Exception('connection already released');
    }

    return _connection!.settings;
  }

  @override
  Rows query(String query, {String? queryName}) {
    if (_connection == null) {
      throw Exception('connection already released');
    }

    return _connection!.query(query, queryName: queryName);
  }

  @override
  Future<CommandTag> execute(String query, {String? queryName}) {
    if (_connection == null) {
      throw Exception('connection already released');
    }

    return _connection!.execute(query, queryName: queryName);
  }

  @override
  Future<PreparedQuery> prepare(String query,
      {String statementName = '',
      String? queryName,
      List<int> paramOIDs = const []}) {
    if (_connection == null) {
      throw Exception('connection already released');
    }

    return _connection!.prepare(query,
        statementName: statementName,
        queryName: queryName,
        paramOIDs: paramOIDs);
  }

  @override
  Rows queryPrepared(PreparedQuery query, List<dynamic> params,
      {String? queryName}) {
    if (_connection == null) {
      throw Exception('connection already released');
    }

    return _connection!.queryPrepared(query, params, queryName: queryName);
  }

  @override
  Future<void> releasePrepared(PreparedQuery query) {
    if (_connection == null) {
      throw Exception('connection already released');
    }

    return _connection!.releasePrepared(query);
  }

  @override
  void release() {
    if (_connection == null) {
      return;
    }

    final connection = _connection!;
    _connection = null;
    pool._releaseConnectionToPool(connection);
  }
}

class PoolPreparedQuery implements PreparedQuery {
  final PGPool pool;

  final PreparedQueryImpl _inner;

  PoolPreparedQuery(this.pool, this._inner);

  @override
  String get name => _inner.name;

  @override
  UnmodifiableListView<int> get paramOIDs => _inner.paramOIDs;

  @override
  UnmodifiableListView<FieldDescription> get fieldDescriptions =>
      _inner.fieldDescriptions;

  @override
  Rows execute(List<dynamic> values) {
    return pool.queryPrepared(_inner, values);
  }

  @override
  Future<void> release() {
    return pool.releasePrepared(_inner);
  }
}
