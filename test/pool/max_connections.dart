import 'package:libpg/libpg.dart';
import 'package:libpg/src/pool/pool.dart';
import 'package:test/test.dart';

void log(LogMessage msg) {
  print('${msg.at}\t${msg.connectionId}\t${msg.message}');
}

void main() {
  group('pool', () {
    test('MultipleSequentialQueries', () async {
      final pool = PGPool(
        ConnSettings(username: 'teja', password: 'learning'),
        maxConnections: 3,
        logger: log,
      );

      final row1 = pool.query('select pg_sleep(10), 1;');
      // expect((await row1.first).toList(), [1]);

      final row2 = pool.query('select pg_sleep(10), 2;');
      // expect((await row1.first).toList(), [1]);

      final row3 = pool.query('select pg_sleep(10), 3;');
      // expect((await row1.first).toList(), [1]);

      final row4 = pool.query('select pg_sleep(10), 4;');
      // expect((await row1.first).toList(), [1]);

      var start = DateTime.now();

      await Future.wait([row1.finished, row2.finished, row3.finished]);

      var stop1 = DateTime.now();
      expect(stop1.difference(start), greaterThan(Duration(seconds: 10)));

      expect((await row1.one())?.toList()[1], 1);
      expect((await row2.one())?.toList()[1], 2);
      expect((await row3.one())?.toList()[1], 3);

      await row4.finished;

      var stop2 = DateTime.now();
      expect(stop2.difference(stop1), greaterThan(Duration(seconds: 10)));

      expect((await row4.one())?.toList()[1], 4);

      expect(pool.poolStats.totalConnectionsMade, 3);

      await pool.close();
    });
  });
}
