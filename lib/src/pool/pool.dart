import 'dart:async';
import 'dart:collection';

import 'package:channel/channel.dart';
import 'package:libpg/libpg.dart';
import 'package:libpg/src/connection/row.dart';
import 'package:libpg/src/logger/logger.dart';
import 'package:pedantic/pedantic.dart';

abstract class PGPool implements Querier {
  factory PGPool(ConnSettings settings, {Logger logger}) =>
      _PGPoolImpl(settings, logger: logger);

  set maxConnections(int value);

  int get maxConnections;

  set maxIdleConnections(int value);

  int get maxIdleConnections;

  Future<Connection> createConnection();
}

class _PGPoolImpl implements PGPool {
  @override
  final ConnSettings settings;

  int _maxConnections;

  int _maxIdleConnections;

  Duration _idleConnectionTimeout;

  Duration _connectionReuseTimeout;

  final _connections = HashSet<Connection>();

  final _usedConnections = HashSet<Connection>();

  final _idleConnections = <Connection>{};

  final _idleTimes = HashMap<Connection, DateTime>();

  Timer _idleTimer;

  final _idleAdded = Channel<void>();

  final Logger _logger;

  _PGPoolImpl(this.settings, {Logger logger}) : _logger = logger ?? nopLogger;

  @override
  int get maxConnections => _maxConnections;

  @override
  set maxConnections(int value) {
    if (value <= 0) value = null;
    _maxConnections = value;

    _whenExceedMaxConnections();
  }

  @override
  int get maxIdleConnections => _maxIdleConnections;

  @override
  set maxIdleConnections(int value) {
    if (value <= 0) value = null;

    _maxIdleConnections = value;

    _whenExceedIdleConnections();
  }

  Duration get idleConnectionTimeout => _idleConnectionTimeout;

  set idleConnectionTimeout(Duration value) {
    _idleConnectionTimeout = value;
  }

  Duration get connectionReuseTimeout => _connectionReuseTimeout;

  set connectionReuseTimeout(Duration value) {
    _connectionReuseTimeout = value;
  }

  @override
  Rows query(String query, {String queryName}) {
    final controller = StreamController<Row>();
    final completer = Completer<void>();
    _getConnection().then((connection) {
      try {
        final ret = connection.query(query, queryName: queryName);
        controller.addStream(ret);
        ret.finished.then((_) => completer.complete(),
            onError: (e, s) => completer.completeError(e, s));
      } catch (e, s) {
        if (connection != null) {
          unawaited(_releaseConnectionToPool(connection));
        }
        controller.addError(e, s);
        completer.completeError(e, s);
      }
      unawaited(_releaseConnectionToPool(connection));
    });
    return Rows(controller.stream, completer.future);
  }

  @override
  Future<CommandTag> execute(String query, {String queryName}) async {
    Connection connection;
    dynamic ret;
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
      String queryName,
      List<int> paramOIDs = const []}) async {
    // TODO
  }

  @override
  Future<Tx> beginTransaction() {
    // TODO
  }

  Future<Connection> _getConnection() async {
    if (_idleConnections.isEmpty) {
      if (_maxConnections == null || _connections.length < _maxConnections) {
        final connection = await createConnection(logger: _logger);
        _connections.add(connection);
        _usedConnections.add(connection);
        return connection;
      }

      while (true) {
        if ((await _idleAdded.receive()).isClosed) {
          throw Exception('Closed');
        }

        final connection = _getLongestIdleConnection();
        if (connection != null) return connection;
      }
    }

    final connection = _getLongestIdleConnection();
    _usedConnections.add(connection);

    return connection;
  }

  Future<void> _removeConnection(Connection connection) {
    _usedConnections.remove(connection);
    _connections.remove(connection);
    _removeIdleConnection(connection);

    return connection.close().catchError((e) {
      // TODO
    });
  }

  Future<void> _releaseConnectionToPool(Connection connection) {
    _usedConnections.remove(connection);

    if (_maxConnections != null && _connections.length > _maxConnections) {
      return _removeConnection(connection);
    }

    // TODO check if connection is dead?

    _addIdleConnection(connection);

    return null;
  }

  Connection _getLongestIdleConnection() {
    final connection = _idleConnections.first;
    _removeIdleConnection(connection);

    return connection;
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

    Duration duration = _connectionReuseTimeout;

    if (_maxIdleConnections != null &&
        (_connections.length - _usedConnections.length) < _maxIdleConnections) {
      if (duration != null &&
          _idleConnectionTimeout != null &&
          _idleConnectionTimeout < duration) {
        duration = _idleConnectionTimeout;
      }
    }

    if (duration == null) return;

    DateTime.now().difference(_idleTimes[_idleConnections.first]);
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

    while (_connections.length > _maxConnections) {
      final connection = _getLongestIdleConnection();
      if (connection == null) break;
      _removeConnection(connection);
    }
  }

  void _whenExceedIdleConnections() {
    _idleTimer?.cancel();

    if (_maxIdleConnections == null || _connectionReuseTimeout == null) return;

    while (_idleConnections.isNotEmpty &&
        (_connections.length - _usedConnections.length) > _maxIdleConnections) {
      final connection = _idleConnections.first;
      final at = _idleTimes[connection];
      if (DateTime.now().difference(at) < _connectionReuseTimeout) break;
      _removeConnection(connection);
    }
  }

  void _whenBelowIdleConnections() {
    _idleTimer?.cancel();

    if (_idleConnectionTimeout == null) return;

    while (_idleConnections.isNotEmpty) {
      final connection = _idleConnections.first;
      final at = _idleTimes[connection];
      if (DateTime.now().difference(at) < _idleConnectionTimeout) break;
      _removeConnection(connection);
    }
  }

  @override
  Future<void> close() async {
    // TODO
  }

  @override
  Future<Connection> createConnection({String connectionName, Logger logger}) =>
      Connection.connect(settings,
          connectionName: connectionName, logger: logger);
}

class PoolStats {
  // TODO
}
