import 'package:libpg/libpg.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  final conn = await Connection.connect(
      ConnSettings(username: 'libpg', password: 'libpg_pwd'),
      logger: log);
  await conn.query('SELECT sdsdf').finished.catchError((e) {
    print(e);
  });
  await conn.close();
}
