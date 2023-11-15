import 'package:libpg/libpg.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  final conn = await Connection.connect(
      ConnSettings(
          username: 'tejag', password: 'learning', databaseName: 'libpg_dart'),
      logger: log);
  await conn.close();
}
