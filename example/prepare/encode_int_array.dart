import 'package:libpg/libpg.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  final conn = await Connection.connect(
      ConnSettings(
          username: 'teja', password: 'learning', databaseName: 'learning'),
      logger: log);
  final statement =
      await conn.prepare(r'INSERT INTO ints VALUES ($1)', statementName: 'st1');
  // final rows = await conn.queryPrepared(statement, [TextData([52]), TextData([51])]);
  final rows = await conn.queryPrepared(statement, [
    [10, 15]
  ]);
  await for (var r in rows) {
    print(r.asMap());
  }
  await conn.close();
}
