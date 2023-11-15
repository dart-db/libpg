import 'dart:convert';

class WriteBuffer {
  final _data = <int>[];

  void addByte(int byte) {
    assert(byte >= 0 && byte < 256);
    _data.add(byte);
  }

  void addBytes(Iterable<int> bytes) {
    _data.addAll(bytes);
  }

  void addInt16(int i) {
    assert(i >= -32768 && i <= 32767);

    if (i < 0) {
      i = 0x10000 + i;
    }

    int a = (i >> 8) & 0x00FF;
    int b = i & 0x00FF;

    _data.add(a);
    _data.add(b);
  }

  void addInt32(int i) {
    assert(i >= -2147483648 && i <= 2147483647);

    if (i < 0) {
      i = 0x100000000 + i;
    }

    int a = (i >> 24) & 0x000000FF;
    int b = (i >> 16) & 0x000000FF;
    int c = (i >> 8) & 0x000000FF;
    int d = i & 0x000000FF;

    _data.add(a);
    _data.add(b);
    _data.add(c);
    _data.add(d);
  }

  void addInt64(int i) {
    int a = (i >> 56) & 0x000000FF;
    int b = (i >> 48) & 0x000000FF;
    int c = (i >> 40) & 0x000000FF;
    int d = (i >> 32) & 0x000000FF;
    int e = (i >> 24) & 0x000000FF;
    int f = (i >> 16) & 0x000000FF;
    int g = (i >> 8) & 0x000000FF;
    int h = i & 0x000000FF;

    _data.add(a);
    _data.add(b);
    _data.add(c);
    _data.add(d);
    _data.add(e);
    _data.add(f);
    _data.add(g);
    _data.add(h);
  }

  void addUtf8String(String s) {
    _data.addAll(utf8.encode(s));
    addByte(0);
  }

  void setLength({bool startup = false}) {
    int offset = 0;
    int i = _data.length;

    if (!startup) {
      offset = 1;
      i -= 1;
    }

    _data[offset] = (i >> 24) & 0x000000FF;
    _data[offset + 1] = (i >> 16) & 0x000000FF;
    _data[offset + 2] = (i >> 8) & 0x000000FF;
    _data[offset + 3] = i & 0x000000FF;
  }

  List<int> get data => _data;

  static List<int> encodeUtf8String(String s) => [...utf8.encode(s), 0];
}
