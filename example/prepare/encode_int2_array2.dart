import 'package:libpg/libpg.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  final conn = await Connection.connect(
      ConnSettings(
          username: 'teja', password: 'learning', databaseName: 'learning'),
      logger: log);
  final statement = await conn.prepare(r'INSERT INTO intss VALUES ($1);',
      statementName: 'st1');
  // final rows = await conn.queryPrepared(statement, [TextData([52]), TextData([51])]);
  final rows = conn.queryPrepared(statement, [
    <List<int>>[
      <int>[30, 31, 32, 33, 34],
      <int>[35, 36, 37, 38, 39]
    ]
  ]);
  await for (var r in rows) {
    print(r.asMap());
  }
  await conn.close();
}
