import 'package:libpg/src/buffer/write_buffer.dart';

class ArrayDimension {
  final int length;

  final int lowerBound;

  ArrayDimension(this.length, this.lowerBound);
}

class ArrayHeader {
  final bool containsNull;

  final int elementOID;

  final List<ArrayDimension> dimensions;

  ArrayHeader(this.elementOID, this.dimensions, this.containsNull);

  List<int> encode() {
    final buffer = WriteBuffer();
    buffer.addInt32(dimensions.length);
    buffer.addInt32(containsNull ? 1 : 0);
    buffer.addInt32(elementOID);

    for(int i = 0; i < dimensions.length; i++) {
      final dimension = dimensions[i];
      buffer.addInt32(dimension.length);
      buffer.addInt32(dimension.lowerBound);
    }

    return buffer.data;
  }
}
