import 'package:libpg/libpg.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  final conn = await Connection.connect(
      ConnSettings(
          username: 'teja', password: 'learning', databaseName: 'learning'),
      logger: log);
  final statement = await conn.prepare(r'SELECT * FROM jsons;',
      statementName: 'st1');
  final rows = await conn.queryPrepared(statement, []);
  await for (var r in rows) {
    print(r.asMap());
  }
  await conn.close();
}
