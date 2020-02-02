import 'dart:async';

import 'package:libpg/src/connection/connection_impl.dart';
import 'package:libpg/src/connection/row.dart';
import 'package:libpg/src/id/generator.dart';
import 'package:libpg/src/logger/logger.dart';

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

  Future<CommandTag> execute(String execute, {String queryName});

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
  final Future<void> finished;

  Rows(Stream<Row> rows, this.finished) : super(rows);
}
