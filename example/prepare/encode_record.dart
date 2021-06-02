import 'package:libpg/libpg.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

class Custom implements ToPGRecord {
  int num;
  String name;

  Custom(this.num, this.name);

  @override
  PGRecord toPGRecord() => PGRecord([num, name]);
}

Future<void> main() async {
  final conn = await Connection.connect(
      ConnSettings(
          username: 'teja', password: 'learning', databaseName: 'learning'),
      logger: log);
  final statement = await conn.prepare(r'INSERT INTO customs VALUES ($1);',
      statementName: 'st1');
  // final rows = await conn.queryPrepared(statement, [TextData([52]), TextData([51])]);
  final rows = conn.queryPrepared(statement, [Custom(5, '5')]);
  await for (var r in rows) {
    print(r.asMap());
  }
  await conn.close();
}
