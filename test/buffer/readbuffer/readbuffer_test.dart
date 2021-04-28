import 'package:libpg/src/buffer/read_buffer.dart';
import 'package:test/test.dart';

void main() {
  group('ReadBuffer', () {
    ReadBuffer buffer1 = ReadBuffer();
    buffer1.append(List<int>.generate(10, (i) => i));
    buffer1.append(List<int>.generate(10, (i) => 10 + i));
    buffer1.append(List<int>.generate(10, (i) => 20 + i));
    buffer1.append(List<int>.generate(10, (i) => 30 + i));

    setUp(() {});

    test('readRow', () {
      expect(buffer1.readBytes(5), List<int>.generate(5, (i) => i));

      // Read remaining bytes
      expect(buffer1.readRow(), List<int>.generate(5, (i) => 5 + i));

      // Read whole row
      expect(buffer1.readRow(), List<int>.generate(10, (i) => 10 + i));

      // Max 5 bytes
      expect(buffer1.readRow(5), List<int>.generate(5, (i) => 20 + i));
    });

    test('readBytes', () {
      expect(buffer1.readBytes(9), List<int>.generate(9, (i) => i));

      expect(buffer1.readBytes(1), List<int>.generate(1, (i) => 9 + i));

      expect(buffer1.readBytes(10), List<int>.generate(10, (i) => 10 + i));

      expect(buffer1.readBytes(5), List<int>.generate(5, (i) => 20 + i));

      expect(buffer1.readBytes(10), List<int>.generate(10, (i) => 25 + i));
    });
  });
}
