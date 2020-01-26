import 'dart:async';
import 'dart:collection';

import 'package:channel/channel.dart';
import 'package:libpg/libpg.dart';
import 'package:pedantic/pedantic.dart';

abstract class PGPool {
  factory PGPool(ConnSettings settings) => _PGPoolImpl(settings);

  ConnSettings get settings;

  set maxConnections(int value);

  int get maxConnections;

  set maxIdleConnections(int value);

  int get maxIdleConnections;

  Future<dynamic> query(String query);

  Future<dynamic> execute(String query);

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

  _PGPoolImpl(this.settings);

  @override
  int get maxConnections => _maxConnections;

  @override
  set maxConnections(int value) {
    _maxConnections = value;

    _whenExceedMaxConnections();
  }

  @override
  int get maxIdleConnections => _maxIdleConnections;

  @override
  set maxIdleConnections(int value) {
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
  Future<dynamic> query(String query) async {
    Connection connection;
    dynamic ret;
    try {
      connection = await _getConnection();
      ret = await connection.query(query);
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
  Future<dynamic> execute(String query) async {
    Connection connection;
    dynamic ret;
    try {
      connection = await _getConnection();
      ret = await connection.execute(query);
    } catch (e) {
      if (connection != null) {
        unawaited(_releaseConnectionToPool(connection));
      }
      rethrow;
    }

    unawaited(_releaseConnectionToPool(connection));

    return ret;
  }

  Future<Connection> _getConnection() async {
    if (_idleConnections.isEmpty) {
      if (_connections.length < _maxConnections) {
        final connection = await createConnection();
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
    if (_connections.length > _maxConnections) {
      return _removeConnection(connection);
    }

    // TODO check if connection is dead?

    _usedConnections.remove(connection);
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
    if (_idleConnections.isNotEmpty) {
      _idleTimer = Timer(
          DateTime.now().difference(_idleTimes[_idleConnections.first]),
          _doIdleTimer);
    }
  }

  void _doIdleTimer() {
    _whenExceedMaxConnections();
    _whenExceedIdleConnections();
    _whenBelowIdleConnections();

    _updateIdleTimer();
  }

  void _whenExceedMaxConnections() {
    _idleTimer?.cancel();

    while (_connections.length > _maxConnections) {
      final connection = _getLongestIdleConnection();
      if (connection == null) break;
      _removeConnection(connection);
    }
  }

  void _whenExceedIdleConnections() {
    _idleTimer?.cancel();

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

    while (_idleConnections.isNotEmpty) {
      final connection = _idleConnections.first;
      final at = _idleTimes[connection];
      if (DateTime.now().difference(at) < _idleConnectionTimeout) break;
      _removeConnection(connection);
    }
  }

  @override
  Future<Connection> createConnection() => Connection.connect(settings);
}

class PoolStats {
  // TODO
}
