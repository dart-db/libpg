import 'package:libpg/libpg.dart';

Future<void> main() async {
  final conn = await ConnectionImpl.connect(
      ConnSettings(username: 'teja', password: 'learning'));
  await conn.query('SELECT 1');
}
