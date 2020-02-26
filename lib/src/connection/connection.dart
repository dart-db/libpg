import 'dart:async';
import 'dart:collection';

import 'package:libpg/libpg.dart';
import 'package:libpg/src/connection/connection_impl.dart';
import 'package:libpg/src/connection/row.dart';
import 'package:libpg/src/id/generator.dart';
import 'package:libpg/src/logger/logger.dart';
import 'package:libpg/src/message/row_description.dart';

final connectionIdGenerator = IdGenerator(prefix: 'conn');

class ConnSettings {
  final String hostname;
  final int port;
  final String databaseName;
  final String username;
  final String password;
  final String timezone;

  ConnSettings({
    this.hostname = 'localhost',
    this.port = 5432,
    this.databaseName = 'postgres',
    this.username,
    this.password,
    this.timezone,
  });
}

void nopLogger(LogMessage msg) {}

abstract class Querier {
  ConnSettings get settings;

  Rows query(String query, {String queryName});

  Future<CommandTag> execute(String query, {String queryName});

  Future<PreparedQuery> prepare(String query,
      {String statementName = '',
      String queryName,
      List<int> paramOIDs = const []});

  Rows queryPrepared(PreparedQuery query, List<dynamic> params,
      {String queryName});

  Future<void> releasePrepared(PreparedQuery query);
}

abstract class Connection implements Querier {
  String get connectionId;

  String get connectionName;

  static Future<Connection> connect(ConnSettings settings,
          {String connectionName,
          Logger logger,
          IdGenerator queryIdGenerator}) =>
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
    return CommandTag(parts.first, tag, int.tryParse(parts.last));
  }
}

class Rows extends StreamView<Row> {
  final Future<CommandTag> finished;

  Rows(Stream<Row> rows, this.finished) : super(rows);
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
  Rows execute(List<dynamic> params, {String queryName}) {
    return connection.queryPrepared(this, params, queryName: queryName);
  }

  @override
  Future<void> release() {
    return connection.releasePrepared(this);
  }

// TODO isOpen
}

abstract class FormattedData {
  int get type;

  List<int> get data;
}

class BinaryData extends FormattedData {
  final List<int> data;

  @override
  final int type = 1;

  BinaryData(this.data);
}

class TextData extends FormattedData {
  final List<int> data;

  @override
  final int type = 0;

  TextData(this.data);
}

class ConnectionStats {
  final Duration averageQueryDuration;

  final Duration maxQueryDuration;

  final int numQueries;

  ConnectionStats(
      this.averageQueryDuration, this.maxQueryDuration, this.numQueries);
}
