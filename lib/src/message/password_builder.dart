import 'package:libpg/src/buffer/write_buffer.dart';

class PasswordMessage {
  final String password;

  PasswordMessage(this.password);

  List<int> build() {
    final buffer = WriteBuffer();
    buffer.addByte(112);
    buffer.addInt32(0);
    buffer.addUtf8String(password);
    buffer.setLength();
    return buffer.data;
  }
}
