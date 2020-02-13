import 'package:libpg/src/buffer/read_buffer.dart';

class ParameterDescriptionMsg {
  final List<int> paramOIDs;

  ParameterDescriptionMsg(this.paramOIDs);

  static ParameterDescriptionMsg parse(ReadBuffer buffer) {
    final count = buffer.readInt16();
    final paramOIDs = List<int>.generate(count, (_) => buffer.readInt32());
    return ParameterDescriptionMsg(paramOIDs);
  }
}
