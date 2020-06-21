import 'package:libpg/src/buffer/read_buffer.dart';
import 'package:libpg/src/message/message_header.dart';

class ErrorResponse {
  final String severity;

  final String code;

  final String message;

  final String detail;

  final String hint;

  final int position;

  final int internalPosition;

  final String internalQuery;

  final String where;

  final String schemaName;

  final String tableName;

  final String columnName;

  final String dataTypeName;

  final String constraintName;

  final String file;

  final String line;

  final String routine;

  ErrorResponse(
      {this.severity,
      this.code,
      this.message,
      this.detail,
      this.hint,
      this.position,
      this.internalPosition,
      this.internalQuery,
      this.where,
      this.schemaName,
      this.tableName,
      this.columnName,
      this.dataTypeName,
      this.constraintName,
      this.file,
      this.line,
      this.routine});

  String toString() => 'ErrorResponse($code, $message)';

  static ErrorResponse parse(ReadBuffer buffer, MessageHeader header) {
    String severity;
    String code;
    String message;
    String detail;
    String hint;
    int position;
    int internalPosition;
    String internalQuery;
    String where;
    String schemaName;
    String tableName;
    String columnName;
    String dataTypeName;
    String constraintName;
    String file;
    String line;
    String routine;

    String key = String.fromCharCode(buffer.readByte());
    while (key != '\x00') {
      final value = buffer.readUtf8String(header.length);
      switch (key) {
        case 'S':
          severity = value;
          break;
        case 'C':
          code = value;
          break;
        case 'M':
          message = value;
          break;
        case 'D':
          detail = value;
          break;
        case 'H':
          hint = value;
          break;
        case 'P':
          position = int.tryParse(value);
          break;
        case 'p':
          internalPosition = int.tryParse(value);
          break;
        case 'q':
          internalQuery = value;
          break;
        case 'W':
          where = value;
          break;
        case 's':
          schemaName = value;
          break;
        case 't':
          tableName = value;
          break;
        case 'c':
          columnName = value;
          break;
        case 'd':
          dataTypeName = value;
          break;
        case 'n':
          constraintName = value;
          break;
        case 'F':
          file = value;
          break;
        case 'L':
          line = value;
          break;
        case 'R':
          routine = value;
          break;
        default:
          // TODO
          break;
      }
      key = String.fromCharCode(buffer.readByte());
    }

    return ErrorResponse(
        severity: severity,
        code: code,
        message: message,
        detail: detail,
        hint: hint,
        position: position,
        internalPosition: internalPosition,
        internalQuery: internalQuery,
        where: where,
        schemaName: schemaName,
        tableName: tableName,
        columnName: columnName,
        dataTypeName: dataTypeName,
        constraintName: constraintName,
        file: file,
        line: line,
        routine: routine);
  }
}

abstract class ErrorResponseCode {
  static const uniqueViolation = "23505";
  static const invalidSqlStatementName = "26000";
}
