import 'package:libpg/libpg.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

Future<void> main() async {
  final conn = await Connection.connect(
      ConnSettings(
          username: 'teja', password: 'learning', databaseName: 'trying'),
      logger: log);

  var row = conn.query(substitute('SELECT @{number}', values: {'number': 1}));
  await for (final row in row) {
    print(row);
  }

  row = conn
      .query(substitute('SELECT @{text}', values: {'text': "Hello ' there!"}));
  await for (final row in row) {
    print(row);
  }

  row = conn.query(substitute('SELECT @{timestamp}',
      values: {'timestamp': DateTime(2019, 01, 01, 2, 3, 4, 123, 456)}));
  await for (final row in row) {
    print(row);
  }

  row = conn.query(substitute(
      'SELECT @{interval1}, @{interval2}, @{interval3}, @{interval4}',
      values: {
        'interval1': Duration(
            days: 28,
            hours: 23,
            minutes: 59,
            seconds: 58,
            milliseconds: 123,
            microseconds: 456),
        'interval2': Duration(
            days: 28, hours: 23, minutes: 59, seconds: 58, milliseconds: 123),
        'interval3': Duration(days: 28, hours: 23, minutes: 59, seconds: 58),
        'interval4': -Duration(
            days: 28,
            hours: 23,
            minutes: 59,
            seconds: 58,
            milliseconds: 123,
            microseconds: 456),
      }));
  await for (final row in row) {
    print(row);
  }

  await conn.close();
}
