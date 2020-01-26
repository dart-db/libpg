import 'package:libpg/libpg.dart';

Future<void> main() async {
  await Connection.connect(ConnSettings(username: 'teja', password: 'learning'));
}
