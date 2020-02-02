import 'package:libpg/src/buffer/read_buffer.dart';
import 'package:libpg/src/message/message_header.dart';

class RowData {
  final List<List<int>> fieldValues;

  RowData(this.fieldValues);

  List<int> operator[](int index) => fieldValues[index];

  static RowData parse(ReadBuffer buffer, MessageHeader header) {
    final count = buffer.readInt16();

    final fieldValues = List<List<int>>(count);

    for(int i = 0; i < count; i++) {
      final length = buffer.readInt32();
      if(length == -1) continue;
      final bytes = buffer.readBytes(length);
      fieldValues[i] = bytes;
    }

    return RowData(fieldValues);
  }
}

class CommandComplete {
  final String tag;

  CommandComplete(this.tag);

  static CommandComplete parse(ReadBuffer buffer, MessageHeader header) {
    final tag = buffer.readUtf8String(header.length);
    return CommandComplete(tag);
  }
}