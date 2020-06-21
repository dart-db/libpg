import 'dart:convert';

import 'package:libpg/libpg.dart';
import 'package:libpg/src/buffer/write_buffer.dart';

FormattedData encode(dynamic value) {
  if (value == null) return BinaryData(null);
  if (value is int) {
    return encodeInt(value);
  }
  if (value is String) {
    return encodeString(value);
  }
  if (value is List) {
    return TextData(utf8.encode(arrayToSql(value)));
  }
  if (value is PGRecord) {
    return TextData(utf8.encode(recordToSql(value)));
  }
  if (value is ToPGRecord) {
    return TextData(utf8.encode(recordToSql(value.toPGRecord())));
  }
  throw Exception('Unknown type');
}

BinaryData encodeInt(int value) {
  return encodeInt8(value);
}

BinaryData encodeInt2(int value) {
  final data = (WriteBuffer()..addInt16(value)).data;
  return BinaryData(data);
}

BinaryData encodeInt4(int value) {
  final data = (WriteBuffer()..addInt32(value)).data;
  return BinaryData(data);
}

BinaryData encodeInt8(int value) {
  final data = (WriteBuffer()..addInt64(value)).data;
  return BinaryData(data);
}

TextData encodeString(String value) {
  return TextData(utf8.encode(value));
}

abstract class ToPGBinary {
  List<int> toPGBinary();
}

/*
BinaryData encodeArray(List value) {
  if (value is List<int>) {
    final header = ArrayHeader(OIDs.int4, [ArrayDimension(value.length, 1)],
        value.any((v) => v == null));
    final buffer = WriteBuffer();
    buffer.addBytes(header.encode());
    for (int i = 0; i < value.length; i++) {
      buffer.addInt32(4);
      buffer.addBytes(encodeInt4(value[i]).data);
    }
    return BinaryData(buffer.data);
  } else if (value is List<List<int>>) {
    final dims = value.map((v) => ArrayDimension(v.length, 1)).toList();
    final header = ArrayHeader(OIDs.int2, dims, value.any((v) => v == null));
    final buffer = WriteBuffer();
    buffer.addBytes(header.encode());
    for (int i = 0; i < value.length; i++) {
      final a = value[i];
      for (int j = 0; j < a.length; j++) {
        buffer.addInt32(2);
        buffer.addBytes(encodeInt2(a[j]).data);
      }
    }
    return BinaryData(buffer.data);
  }
}*/
