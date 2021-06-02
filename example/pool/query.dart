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

  // Query
  final row1 = pool.query('SELECT 1');
  print(await row1.toList());

  // Execute
  final row2 = pool.query("update person set name='Mark' where id = 1");
  print(await row2.finished);

  // Release all connections in the pool
  await pool.close();
}
