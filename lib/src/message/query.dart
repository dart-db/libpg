import 'package:libpg/src/message/message_type.dart';
import 'package:libpg/src/buffer/write_buffer.dart';

class QueryMessage {
  final String sql;

  QueryMessage(this.sql);

  List<int> build() {
    final buffer = WriteBuffer();
    buffer.addByte(MessageType.query);
    buffer.addInt32(0); // Length padding.
    buffer.addUtf8String(sql);
    buffer.setLength();
    return buffer.data;
  }
}
