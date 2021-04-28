import 'package:libpg/src/buffer/write_buffer.dart';
import 'package:libpg/src/message/message_type.dart';

class ParseMessage {
  final String name;

  final String query;

  final List<int> paramOIDs;

  ParseMessage(this.query, {this.name = '', this.paramOIDs = const <int>[]});

  List<int> build() {
    final buffer = WriteBuffer();
    buffer.addByte(MessageType.parse);
    buffer.addInt32(0); // Length padding.
    buffer.addUtf8String(name);
    buffer.addUtf8String(query);
    buffer.addInt16(paramOIDs.length);
    for (final oid in paramOIDs) {
      buffer.addInt32(oid);
    }
    buffer.setLength();
    return buffer.data;
  }
}

class DescribeMessage {
  final int type;

  final String name;

  DescribeMessage(this.type, this.name);

  List<int> build() {
    final buffer = WriteBuffer();
    buffer.addByte(MessageType.describe);
    buffer.addInt32(0); // Length padding.
    buffer.addByte(type);
    buffer.addUtf8String(name);
    buffer.setLength();
    return buffer.data;
  }

  static const statementType = 83;

  static const portalType = 80;
}

class Bind {
  final List<List<int>?> params;

  final String statementName;

  final String portalName;

  final dynamic /* int | List<int> */ paramFormats;

  final dynamic /* int | List<int> */ outputFormats;

  Bind(this.params,
      {/* int | List<int> */ this.paramFormats,
      /* int | List<int> */ this.outputFormats,
      this.statementName = '',
      this.portalName = ''});

  List<int> build() {
    final buffer = WriteBuffer();
    buffer.addByte(MessageType.bind);
    buffer.addInt32(0); // Padding for length
    buffer.addUtf8String(portalName);
    buffer.addUtf8String(statementName);

    if (paramFormats == null || paramFormats == 0) {
      buffer.addInt16(0);
    } else if (paramFormats == 1) {
      buffer.addInt16(1);
      buffer.addInt16(1);
    } else if (paramFormats is List<int>) {
      buffer.addInt16(paramFormats.length);
      for (int i = 0; i < paramFormats.length; i++) {
        buffer.addInt16(paramFormats[i]);
      }
    } else {
      throw Exception();
    }

    buffer.addInt16(params.length);
    for (int i = 0; i < params.length; i++) {
      final value = params[i];
      if (value == null) {
        buffer.addInt32(-1);
      } else {
        buffer.addInt32(value.length);
        for (int j = 0; j < value.length; j++) {
          buffer.addByte(value[j]);
        }
      }
    }

    if (outputFormats == null || outputFormats == 0) {
      buffer.addInt16(0);
    } else if (outputFormats == 1) {
      buffer.addInt16(1);
      buffer.addInt16(1);
    } else if (outputFormats is List<int>) {
      buffer.addInt16(outputFormats.length);
      for (int i = 0; i < outputFormats.length; i++) {
        buffer.addInt16(outputFormats[i]);
      }
    } else {
      throw Exception();
    }

    buffer.setLength();
    return buffer.data;
  }
}

class Execute {
  final String portal;

  final int rowLimit;

  Execute({this.portal = '', this.rowLimit = 0});

  List<int> build() {
    final buffer = WriteBuffer();
    buffer.addByte(MessageType.execute);
    buffer.addInt32(0);
    buffer.addUtf8String(portal);
    buffer.addInt32(rowLimit);
    buffer.setLength();
    return buffer.data;
  }
}

class SyncMessage {
  List<int> build() {
    final buffer = WriteBuffer();
    buffer.addByte(MessageType.sync);
    buffer.addInt32(0);
    buffer.setLength();
    return buffer.data;
  }
}

enum CloseType { preparedStatement, portal }

class CloseMessage {
  final CloseType type;

  final String name;

  CloseMessage(this.name, {this.type = CloseType.preparedStatement});

  List<int> build() {
    final buffer = WriteBuffer();

    buffer.addByte(MessageType.close);
    buffer.addInt32(0);
    if (type == CloseType.preparedStatement) {
      buffer.addByte(DescribeMessage.statementType);
    } else {
      buffer.addByte(DescribeMessage.portalType);
    }
    buffer.addUtf8String(name);
    buffer.setLength();

    return buffer.data;
  }
}
