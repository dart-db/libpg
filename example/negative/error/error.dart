import 'package:libpg/libpg.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  final conn = await Connection.connect(
      ConnSettings(username: 'learn', password: 'learning'),
      logger: log);

  await conn.query('SELECT sdsdf').finished.catchError((e) {
    print(e);
  });

  var rows = conn.query('select * from (values (1), (2)) data');
  await for (final row in rows) {
    print(row);
  }

  await conn.close();
}
