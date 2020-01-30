import 'package:libpg/libpg.dart';
import 'package:libpg/src/logger/logger.dart';
import 'package:libpg/src/pool/pool.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  final pool = PGPool(
    ConnSettings(username: 'teja', password: 'learning'),
    logger: log,
  );
  final row1 = await pool.query('SELECT 1');
  await row1.finished;
  final row2 = await pool.query('SELECT 2');
  await row2.finished;
  final row3 = await pool.query('SELECT 3');
  await row3.finished;

  await Future.delayed(Duration(seconds: 10));
}
