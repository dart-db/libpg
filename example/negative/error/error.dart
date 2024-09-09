import 'dart:async';

import 'package:libpg/libpg.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  final conn = await Connection.connect(
      ConnSettings(username: 'libpg', password: 'libpg_pwd'),
      logger: log);

  var rows = conn.query('SELECT sdsdf');
  try {
    await rows.one();
  } catch (e) {
    print(e);
  }

  var rows2 = conn.query('select * from (values (1), (2)) data');
  await for (final row in rows2) {
    print(row);
  }

  try {
    await rows.finished;
  } catch (e) {
    print(e);
  }

  print('Success!');

  await conn.close();
}
