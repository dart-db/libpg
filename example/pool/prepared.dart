import 'package:libpg/libpg.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  final pool = PGPool(
    ConnSettings(
        username: 'teja', password: 'learning', databaseName: 'learning'),
    logger: log,
  );

  final st = await pool.prepare(r'SELECT * FROM tint2 LIMIT $1',
      statementName: 'query_tint2');

  var row1 = pool.queryPrepared(st, [1]);
  await for (final r in row1) {
    print(r);
  }

  row1 = pool.queryPrepared(st, [2]);
  await for (final r in row1) {
    print(r);
  }

  /*
  final row1 = await pool.query('SELECT 1');
  await row1.finished;
  final row2 = await pool.query('SELECT 2');
  await row2.finished;
  final row3 = await pool.query('SELECT 3');
  await row3.finished;
   */

  await pool.close();
}
