import 'package:libpg/libpg.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  final conn = await Connection.connect(
      ConnSettings(
          username: 'teja', password: 'learning', databaseName: 'trying'),
      logger: log);
  final row = conn.query('SELECT 1');
  await for (final row in row) {
    print(row);
  }
  await conn.close();
}
