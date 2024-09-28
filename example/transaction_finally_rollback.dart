import 'package:libpg/libpg.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  final conn = await Connection.connect(ConnSettings(
      username: 'teja', password: 'learning', databaseName: 'trying'));

  await conn.execute('DROP TABLE IF EXISTS Numbers');
  await conn.execute('CREATE TABLE Numbers(id integer);');

  await go(conn, false);
  await go(conn, true);

  print(await conn.query('SELECT * FROM numbers').toList());
  await conn.execute('DROP TABLE IF EXISTS Numbers');

  await conn.close();
}

Future<void> go(Connection conn, bool thro) async {
  await conn.execute('START TRANSACTION');
  try {
    for (int i = 0; i < 10; i++) {
      await conn
          .execute('INSERT INTO numbers VALUES (@{i})'.substitute({'i': i}));
    }
    print(await conn.query('SELECT * FROM numbers').toList());
    if (thro) {
      throw Exception();
    }
    await conn.execute('COMMIT');
  } on Exception catch (_) {
    // Ignored
  } finally {
    await conn.execute('ROLLBACK');
  }
}
