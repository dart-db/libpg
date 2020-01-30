import 'package:libpg/libpg.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  await ConnectionImpl.connect(
      ConnSettings(username: 'tej', password: 'learning'),
      logger: log).catchError((e) {
        print('Connection error: $e');
  });
}
