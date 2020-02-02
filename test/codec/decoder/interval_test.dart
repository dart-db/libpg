import 'package:libpg/src/codec/decoder/interval.dart';
import 'package:test/test.dart';

void main() {
  group('decoder.interval', () {
    test('from text positive', () {
      expect(decodeIntervalText('1 year').inMicroseconds, 31557600000000);
      expect(decodeIntervalText('2 year').inMicroseconds, 63115200000000);
      expect(
          decodeIntervalText('1 year 10 mons').inMicroseconds, 57477600000000);
      expect(
          decodeIntervalText('2 year 2 mons').inMicroseconds, 68299200000000);
      expect(
          decodeIntervalText('1 year 10 mons 00:00:00.000001').inMicroseconds,
          57477600000001);
      expect(decodeIntervalText('1 year 10 mons 00:00:00.001').inMicroseconds,
          57477600001000);
      expect(decodeIntervalText('1 year 1 month 1 day').inMicroseconds,
          34236000000000);
      expect(
          decodeIntervalText('1 year 1 month 1 day 2:3:4.567891')
              .inMicroseconds,
          34243384567891);
      expect(decodeIntervalText('23:59:59.999999').inMicroseconds, 86399999999);

      expect(
          decodeIntervalText('1 year 1 month 368 day 2:3:4.567891')
              .inMicroseconds,
          65952184567891);
    });
    test('from text negative', () {
      expect(decodeIntervalText('-1 year').inMicroseconds, -31557600000000);
      expect(decodeIntervalText('-1 year 1 month').inMicroseconds,
          -28512000000000);
      expect(decodeIntervalText('-1 year 1 month 1 day').inMicroseconds,
          -28425600000000);

      expect(decodeIntervalText('-1 year 1 month -1 day').inMicroseconds,
          -28598400000000);
      expect(decodeIntervalText('-1 year 1 month -32 day').inMicroseconds,
          -31276800000000);
      expect(decodeIntervalText('-1 year 1 month -368 day').inMicroseconds,
          -60307200000000);
      expect(
          decodeIntervalText('1 year 1 month 368 day -23:48:22.676767')
              .inMicroseconds,
          65859097323233);
      expect(
          decodeIntervalText('-1 year 1 month 368 day -23:48:22.676767')
              .inMicroseconds,
          3197497323233);
    });
  });
}
