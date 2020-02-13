import 'package:libpg/libpg.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  final conn = await Connection.connect(
      ConnSettings(
          username: 'teja', password: 'learning', databaseName: 'learning'),
      logger: log);
  final row = await (conn.query('SELECT * FROM TDate;'));
  await for (final row in row) {
    print(row);
  }
  await conn.close();
}
