import 'package:libpg/libpg.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  final conn = await Connection.connect(ConnSettings(
      username: 'teja', password: 'learning', databaseName: 'trying'));

  await conn.execute('DROP TABLE IF EXISTS Numbers');
  await conn.execute('CREATE TABLE Numbers(id integer);');
  for (int i = 0; i < 10; i++) {
    await conn
        .execute('INSERT INTO numbers VALUES (@{i})'.substitute({'i': i}));
  }

  await conn.execute('START TRANSACTION');
  for (int i = 10; i < 20; i++) {
    await conn
        .execute('INSERT INTO numbers VALUES (@{i})'.substitute({'i': i}));
  }
  await conn.execute('COMMIT');
  print(await conn.query('SELECT * FROM numbers').toList());
  await conn.execute('ROLLBACK');
  print(await conn.query('SELECT * FROM numbers').toList());

  await conn.execute('DROP TABLE IF EXISTS Numbers');

  await conn.close();

  await Future.delayed(Duration(seconds: 5));
}
