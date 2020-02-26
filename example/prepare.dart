import 'package:libpg/libpg.dart';
import 'package:libpg/src/exception/postgres_server.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  final conn = await Connection.connect(
      ConnSettings(
          username: 'teja', password: 'learning', databaseName: 'learning'),
      logger: log);

  // Prepare a statement
  final st = await conn.prepare(r'SELECT * FROM tint2 LIMIT $1',
      statementName: 'query_tint2');

  // Query using prepared statement
  var row1 = conn.queryPrepared(st, [1]);
  await for (final r in row1) {
    print(r);
  }

  // Query again using prepared statement
  row1 = conn.queryPrepared(st, [2]);
  await for (final r in row1) {
    print(r);
  }

  // Release prepared statement
  await conn.releasePrepared(st);

  // Querying closed statement should produce [PreparedStatementNotExists] exception
  try {
    await conn.queryPrepared(st, [2]).finished;
    throw Exception('expcected statement not found expected');
  } on PreparedStatementNotExists {
    // As expected!
  }

  await conn.close();
}
