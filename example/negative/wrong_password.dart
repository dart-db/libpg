import 'package:libpg/libpg.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  await Connection.connect(ConnSettings(username: 'learn', password: 'learnin'),
          logger: log)
      .catchError((e) {
    print(e);
  });
}
