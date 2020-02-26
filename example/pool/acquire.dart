import 'package:libpg/libpg.dart';
import 'package:libpg/src/logger/logger.dart';
import 'package:libpg/src/pool/pool.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  final pool = PGPool(
    ConnSettings(
        username: 'teja', password: 'learning', databaseName: 'learning'),
    logger: log,
  );

  final conn = await pool.acquireConnection();

  final statement = await conn.prepare(
      'SELECT * FROM tint2 OFFSET \$1 LIMIT \$2',
      statementName: 'st1');

  var rows = await conn.queryPrepared(statement, ['3', 2]);
  await for (var r in rows) {
    print(r.asMap());
  }

  rows = await conn.queryPrepared(statement, ['3', 2]);
  await for (var r in rows) {
    print(r.asMap());
  }

  // TODO release prepared query

  conn.release();

  await pool.close();
}
