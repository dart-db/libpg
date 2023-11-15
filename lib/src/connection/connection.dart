import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:libpg/libpg.dart';
import 'package:libpg/src/connection/impl/connection_impl.dart';
import 'package:libpg/src/connection/row.dart';
import 'package:libpg/src/util/generator.dart';
import 'package:libpg/src/logger/logger.dart';
import 'package:libpg/src/message/row_description.dart';

export 'row.dart';

final connectionIdGenerator = IdGenerator(prefix: 'conn');

class ConnSettings {
  final String hostname;
  final int port;
  final String databaseName;
  final String? username;
  final String? password;
  final String? timezone;

  ConnSettings({
    this.hostname = 'localhost',
    this.port = 5432,
    this.databaseName = 'postgres',
    required this.username,
    this.password,
    this.timezone,
  });

  factory ConnSettings.parse(/* String | Uri */ url, {String? timezone}) {
    Uri? uri;
    if (url is String) {
      uri = Uri.tryParse(url);
      if (uri == null) {
        throw Exception('Invalid url');
      }
    } else if (url is Uri) {
      uri = url;
    } else if (url == null) {
      throw Exception('url cannot be null');
    } else {
      throw Exception('unknown url type');
    }

    String? username;
    String? password;

    {
      final userInfoParts = uri.userInfo.split(':');
      if (userInfoParts.isNotEmpty) username = userInfoParts.first;
      if (userInfoParts.length > 2) password = userInfoParts[1];
    }
    String databaseName = 'postgres';
    if (uri.pathSegments.isNotEmpty) {
      databaseName = uri.pathSegments.first;
    }

    return ConnSettings(
      hostname: uri.host,
      port: uri.port,
      username: username,
      password: password,
      databaseName: databaseName,
      timezone: timezone,
    );
  }
}

void nopLogger(LogMessage msg) {}

abstract class Querier {
  ConnSettings get settings;

  Rows query(String query, {String? queryName});

  Future<CommandTag> execute(String query, {String? queryName});

  Future<PreparedQuery> prepare(String query,
      {String statementName = '',
      String? queryName,
      List<int> paramOIDs = const []});

  Rows queryPrepared(PreparedQuery query, List<dynamic> params,
      {String? queryName});

  Future<void> releasePrepared(PreparedQuery query);
}

abstract class Connection implements Querier {
  String get connectionId;

  String get connectionName;

  static Future<Connection> connect(ConnSettings settings,
          {String? connectionName,
          Logger? logger,
          IdGenerator? queryIdGenerator}) =>
      ConnectionImpl.connect(settings,
          connectionName: connectionName,
          logger: logger,
          queryIdGenerator: queryIdGenerator);

  Future<void> close();
}

class CommandTag {
  final String tagName;

  final String tag;

  final int rowsAffected;

  CommandTag(this.tagName, this.tag, this.rowsAffected);

  static CommandTag parse(String tag) {
    final parts = tag.split(' ');
    int ra = 0;
    switch(parts[0]) {
      case 'INSERT':
      case 'DELETE':
      case 'UPDATE':
      case 'SELECT':
      case 'MOVE':
      case 'FETCH':
      case 'COPY':
        ra = int.parse(parts.last);
    }
    return CommandTag(parts.first, tag, ra);
  }

  @override
  String toString() => 'CommandTag(tag: $tag, rowsAffected: $rowsAffected)';
}

class Rows extends StreamView<Row> {
  final Future<CommandTag> finished;

  Rows(Stream<Row> rows, this.finished) : super(rows);

  Future<Row?> one() async {
    try {
      return await first;
    } on StateError catch (e) {
      if (e.message == 'No element') {
        return null;
      }
      rethrow;
    }
  }
}

abstract class PreparedQuery {
  String get name;

  UnmodifiableListView<int> get paramOIDs;

  UnmodifiableListView<FieldDescription> get fieldDescriptions;

  Rows execute(List<dynamic> values);

  Future<void> release();
}

class PreparedQueryImpl implements PreparedQuery {
  @override
  final String name;

  @override
  final UnmodifiableListView<int> paramOIDs;

  @override
  final UnmodifiableListView<FieldDescription> fieldDescriptions;

  final Querier connection;

  PreparedQueryImpl(
      this.connection, this.name, this.paramOIDs, this.fieldDescriptions);

  @override
  Rows execute(List<dynamic> params, {String? queryName}) {
    return connection.queryPrepared(this, params, queryName: queryName);
  }

  @override
  Future<void> release() {
    return connection.releasePrepared(this);
  }

// TODO isOpen
}

abstract class FormattedData {
  int get format;

  List<int>? get data;
}

class BinaryData extends FormattedData {
  @override
  final List<int>? data;

  @override
  final int format = 1;

  BinaryData(this.data);
}

class TextData extends FormattedData {
  @override
  final List<int>? data;

  @override
  final int format = 0;

  TextData(this.data);

  @override
  String toString() => utf8.decode(data ?? []);
}

class ConnectionStats {
  final Duration averageQueryDuration;

  final Duration maxQueryDuration;

  final int numQueries;

  ConnectionStats(
      this.averageQueryDuration, this.maxQueryDuration, this.numQueries);
}
