import 'package:libpg/src/buffer/read_buffer.dart';

class ParameterStatus {
  final String name;

  final String value;

  ParameterStatus(this.name, this.value);

  static ParameterStatus parse(ReadBuffer buffer) {
    String name = buffer.readUtf8String(10000);
    String value = buffer.readUtf8String(10000);

    return ParameterStatus(name, value);
  }
}
