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

  Future<Tx> beginTransaction();

  Future<void> close();
}

abstract class Tx implements Querier {
  Future<dynamic> commit();

  Future<dynamic> rollback();
}

abstract class Connection implements Querier {
  String get connectionId;

  String get connectionName;

  Rows queryPrepared(PreparedQuery query, List params, {String queryName});

  static Future<Connection> connect(ConnSettings settings,
          {String connectionName, Logger logger}) =>
      ConnectionImpl.connect(settings,
          connectionName: connectionName, logger: logger);
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

class PreparedQuery {
  final String name;

  final UnmodifiableListView<int> paramOIDs;

  final UnmodifiableListView<FieldDescription> fieldDescriptions;

  final Connection _conn;

  PreparedQuery(this._conn, this.name, this.paramOIDs, this.fieldDescriptions);

  Future<Rows> execute(List<dynamic> values) async {
    // TODO check if closed

    // TODO
  }

  Future<void> release() async {
    // TODO
  }

  bool get isOpen {
    // TODO
  }
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
