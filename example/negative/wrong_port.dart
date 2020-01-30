import 'package:libpg/libpg.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  await ConnectionImpl.connect(
          ConnSettings(username: 'teja', password: 'learning', port: 5433),
          logger: log)
      .catchError((e) {
    print(e);
  });
}
