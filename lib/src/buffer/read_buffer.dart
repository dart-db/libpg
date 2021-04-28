import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

class ReadBuffer {
  ReadBuffer({List<int>? init}) {
    if (init != null) append(init);
  }

  int _position = 0;

  final _queue = Queue<List<int>>();

  int _totalLength = 0;

  int get bytesAvailable => _totalLength - _position;

  int readByte() {
    if (_queue.isEmpty) {
      throw Exception('Attempted to read from an empty buffer.');
    }

    int byte = _queue.first[_position];

    _position++;
    if (_position >= _queue.first.length) {
      _totalLength -= _queue.first.length;
      _queue.removeFirst();
      _position = 0;
    }

    return byte;
  }

  int readInt16() {
    int a = readByte();
    int b = readByte();

    assert(a < 256 && b < 256 && a >= 0 && b >= 0);
    int i = (a << 8) | b;

    if (i >= 0x8000) {
      i = -0x10000 + i;
    }

    return i;
  }

  int readInt32() {
    int a = readByte();
    int b = readByte();
    int c = readByte();
    int d = readByte();

    assert(a < 256 &&
        b < 256 &&
        c < 256 &&
        d < 256 &&
        a >= 0 &&
        b >= 0 &&
        c >= 0 &&
        d >= 0);
    int i = (a << 24) | (b << 16) | (c << 8) | d;

    if (i >= 0x80000000) {
      i = -0x100000000 + i;
    }

    return i;
  }

  List<int> readRow([int? max]) {
    final first = _queue.first;
    int available = _queue.first.length - _position;
    if (max == null || available <= max) {
      _queue.removeFirst();
      final ret = first.getRange(_position, first.length).toList();
      _totalLength -= first.length;
      _position = 0;
      return ret;
    }

    final ret = first.getRange(_position, _position + max).toList();
    _position += max;
    return ret;
  }

  List<int> readBytes(int bytes) {
    final ret = Uint8List(bytes);
    if (bytesAvailable < bytes) {
      throw RangeError.range(bytes, 0, bytesAvailable);
    }

    int remaining = bytes;
    while (remaining > 0) {
      final row = readRow(remaining);
      int start = bytes - remaining;
      ret.setRange(start, start + row.length, row);
      remaining -= row.length;
    }

    return ret;
  }

  String readUtf8StringN(int size) => utf8.decode(readBytes(size));

  /// Read a zero terminated utf8 string.
  String readUtf8String(int maxSize) {
    var bytes = <int>[];
    int c, i = 0;
    while ((c = readByte()) != 0) {
      if (i > maxSize) {
        throw Exception('Max size exceeded while reading string: $maxSize.');
      }
      bytes.add(c);
    }
    return utf8.decode(bytes);
  }

  void append(List<int> data) {
    if (data == null || data.isEmpty) {
      throw Exception('Attempted to append null or empty list.');
    }

    _queue.addLast(data);
    _totalLength += data.length;
  }
}
