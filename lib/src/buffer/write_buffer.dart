import 'dart:convert';

class WriteBuffer {
  final _data = <int>[];

  void addByte(int byte) {
    assert(byte >= 0 && byte < 256);
    _data.add(byte);
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
}
