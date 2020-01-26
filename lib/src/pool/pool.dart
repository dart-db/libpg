import 'dart:collection';
import 'package:pedantic/pedantic.dart';

import 'package:channel/channel.dart';
import 'package:libpg/libpg.dart';

abstract class PGPool {
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
  final ConnSettings settings;

  int _maxConnections;

  int _maxIdleConnections;

  DateTime _idleConnectionTimeout;

  DateTime _connectionReuseTimeout;

  final _connections = HashSet<Connection>();

  final _usedConnections = HashSet<Connection>();

  final _idleConnections = SplayTreeMap<DateTime, HashSet<Connection>>();

  final _idleAdded = Channel<void>();

  // TODO final _ =

  _PGPoolImpl(this.settings);

  @override
  int get maxConnections => _maxConnections;

  @override
  set maxConnections(int value) {
    _maxConnections = value;
    while (_connections.length > _maxConnections) {
      final connection = _getShortestIdleConnection();
      if (connection == null) break;
      _removeConnection(connection);
    }
  }

  @override
  int get maxIdleConnections => _maxIdleConnections;

  @override
  set maxIdleConnections(int value) {
    _maxIdleConnections = value;

    while((_connections.length - _usedConnections.length) > _maxIdleConnections) {
      final connection = _getShortestIdleConnection();
      if (connection == null) break;
      _removeConnection(connection);
    }
  }

  DateTime get idleConnectionTimeout => _idleConnectionTimeout;

  set idleConnectionTimeout(DateTime value) {
    _idleConnectionTimeout = value;
    // TODO
  }

  DateTime get connectionReuseTimeout => _connectionReuseTimeout;

  set connectionReuseTimeout(DateTime value) {
    _connectionReuseTimeout = value;
    // TODO
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
    final key = _idleConnections.firstKey();
    final connections = _idleConnections[key];

    final connection = connections.first;
    connections.remove(connection);
    if (connections.isEmpty) {
      _idleConnections.remove(key);
    }

    return connection;
  }

  Connection _getShortestIdleConnection() {
    final key = _idleConnections.lastKey();
    final connections = _idleConnections[key];

    final connection = connections.first;
    connections.remove(connection);
    if (connections.isEmpty) {
      _idleConnections.remove(key);
    }

    return connection;
  }

  void _addIdleConnection(Connection connection) {
    HashSet<Connection> connections = _idleConnections[connection.connectedAt];
    if (connections == null) {
      connections = HashSet<Connection>();
      _idleConnections[connection.connectedAt] = connections;
    }
    connections.add(connection);
    _idleAdded.send(null);
  }

  void _removeIdleConnection(Connection connection) {
    final key = connection.connectedAt;
    final connections = _idleConnections[key];
    if (connections == null) return;

    connections.remove(connection);
    if (connections.isEmpty) {
      _idleConnections.remove(key);
    }
  }

  @override
  Future<Connection> createConnection() => Connection.connect(settings);
}

class PoolStats {
  // TODO
}

// Find oldest idle connection to execute query
// Remove newest idle connection when max connections exceeds, after transient idle connection timeout
// ====> Set based on insert into connectedAt
// Ability to find the entry quick to remove

// Find connections with idle timeouts
// ====> Timer based trigger

//
// idle connections
// connections in use
