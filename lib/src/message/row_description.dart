import 'package:libpg/src/buffer/read_buffer.dart';

class FieldDescription {
  /// Name of the field.
  final String name;

  /// Object id of the table if the field can be identified by a column in a
  /// specific table.
  final int tableOid;

  /// Attribute number of the column if the field can be identified as a column
  /// of a specific table.
  final int columnAttributeNumber;

  /// Object id of the field's data type.
  final int oid;

  final int typeLen;

  final int typeModifier;

  final int formatType;

  FieldDescription(
      {required this.name,
      required this.tableOid,
      required this.columnAttributeNumber,
      required this.oid,
      required this.typeLen,
      required this.typeModifier,
      required this.formatType});

  static FieldDescription parse(ReadBuffer buffer, int msgLength) {
    final String name = buffer.readUtf8String(msgLength);
    final int tableOid = buffer.readInt32();
    final int columnAttributeNumber = buffer.readInt16();
    final int oid = buffer.readInt32();
    final int typeLen = buffer.readInt16();
    final int typeModifier = buffer.readInt32();
    final int formatCode = buffer.readInt16();

    return FieldDescription(
        name: name,
        tableOid: tableOid,
        columnAttributeNumber: columnAttributeNumber,
        oid: oid,
        typeLen: typeLen,
        typeModifier: typeModifier,
        formatType: formatCode);
  }
}

class RowDescription {
  /// Number of fields in the row.
  final int fieldCount;

  final List<FieldDescription> fields;

  RowDescription({required this.fieldCount, required this.fields});

  static RowDescription parse(ReadBuffer buffer, int length) {
    final fieldCount = buffer.readInt16();

    final columns = List<FieldDescription>.generate(
        fieldCount, (i) => FieldDescription.parse(buffer, length));

    return RowDescription(fieldCount: fieldCount, fields: columns);
  }
}
