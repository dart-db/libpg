import 'package:libpg/libpg.dart';
import 'package:libpg/src/pool/pool.dart';
import 'package:test/test.dart';

void main() {
  group('pool', () {
    test('MultipleSequentialQueries', () async {
      final pool = PGPool(
        ConnSettings(username: 'teja', password: 'learning'),
      );
      final row1 = pool.query('SELECT 1');
      await row1.finished;
      expect((await row1.first).toList(), [1]);
      final row2 = pool.query('SELECT 2');
      await row2.finished;
      expect((await row2.first).toList(), [2]);
      final row3 = pool.query('SELECT 3');
      await row3.finished;
      expect((await row3.first).toList(), [3]);

      expect(pool.poolStats.totalConnectionsMade, 1);

      await pool.close();
    });
  });
}
