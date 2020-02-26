import 'dart:convert';

import 'package:libpg/libpg.dart';
import 'package:libpg/src/buffer/read_buffer.dart';
import 'package:libpg/src/codec/decoder/interval.dart';
import 'package:libpg/src/codec/decoder/parser/parser.dart';
import 'package:libpg/src/codec/decoder/timestamp.dart';
import 'package:libpg/src/connection/query_queue_entry/query_entry.dart';
import 'package:libpg/src/message/row_description.dart';

dynamic decode(final FieldDescription description, List<int> data) {
  if (data == null) return null;
  switch (description.formatType) {
    case FormatType.text:
      try {
        return _decodeText(
            description, String.fromCharCodes(data)); // TODO encoding
      } catch(e) {
        return TextData(data);
      }
      break;
    case FormatType.binary:
      return _decodeBinary(description, data);
    default:
      throw Exception('Unkown format type');
  }
}

dynamic _decodeBinary(final FieldDescription description, List<int> data) {
  switch (description.oid) {
    case OIDs.int4:
      if (data.length != 4) throw Exception('Invalid length for int4');
      final buffer = ReadBuffer(init: data);
      return buffer.readInt32();
    case OIDs.text:
      return String.fromCharCodes(data); // TODO encoding
    default:
      return BinaryData(data);
  }
}

dynamic _decodeText(final FieldDescription description, String data) {
  switch (description.oid) {
    case OIDs.int2:
      return int.parse(data);
    case OIDs.int4:
      return int.parse(data);
    case OIDs.int8:
      return int.parse(data);
    case OIDs.float4:
      return double.parse(data);
    case OIDs.float8:
      return double.parse(data);
    case OIDs.text:
      return data;
    case OIDs.timestamp:
    case OIDs.timestamptz:
    case OIDs.date:
      return decodeTimestampText(description.oid, data);
    case OIDs.interval:
      return decodeIntervalText(data);
    case OIDs.json:
    case OIDs.jsonb:
      return jsonDecode(data);
    default:
      return parse(data);
  }
}
