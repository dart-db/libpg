import 'package:libpg/src/buffer/read_buffer.dart';

class MessageHeader {
  final int messageType;

  final int length;

  MessageHeader(this.messageType, this.length);

  factory MessageHeader.fromBuffer(ReadBuffer buffer) {
    return MessageHeader(buffer.readByte(), buffer.readInt32() - 4);
  }
}