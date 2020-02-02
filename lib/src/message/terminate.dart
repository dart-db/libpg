import 'package:libpg/src/buffer/write_buffer.dart';
import 'package:libpg/src/connection/message_type.dart';

class Terminate {
  List<int> build() {
    final buffer = WriteBuffer();
    buffer.addByte(MessageType.terminate);
    buffer.addInt32(0);
    buffer.setLength();

    return buffer.data;
  }
}