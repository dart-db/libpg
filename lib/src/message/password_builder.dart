import 'package:libpg/src/buffer/write_buffer.dart';

class PasswordMessageBuilder {
  final String password;

  PasswordMessageBuilder(this.password);

  List<int> build() {
    final buffer = WriteBuffer();
    buffer.addByte(112);
    buffer.addInt32(0);
    buffer.addUtf8String(password);
    buffer.setLength();
    return buffer.data;
  }
}
