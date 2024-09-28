import 'package:libpg/libpg.dart';
import 'package:libpg/src/exception/postgres_server.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  final conn = await Connection.connect(
      ConnSettings(
          username: 'libpg', password: 'libpg_pwd', databaseName: 'libpg_db'),
      logger: log);

  await conn.execute('CREATE TEMP TABLE tint2 (a int)');
  for (var i = 0; i < 10; i++) {
    await conn.execute('INSERT INTO tint2 VALUES ($i)');
  }

  // Prepare a statement
  final st = await conn.prepare(r'SELECT * FROM tint2 LIMIT $1',
      statementName: 'query_tint2');

  // Query using prepared statement
  var row1 = conn.queryPrepared(st, [1]);
  await for (final r in row1) {
    print('result is $r');
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
    throw Exception('PreparedStatementNotExists exception expected');
  } on PreparedStatementNotExists catch (_) {
    // As expected!
  }

  await conn.close();
}
