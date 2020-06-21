import 'dart:async';

import 'package:libpg/libpg.dart';
import 'package:libpg/src/codec/decoder/decoder.dart';
import 'query_entry.dart';
import 'package:libpg/src/connection/row.dart';
import 'package:libpg/src/exception/postgres_server.dart';
import 'package:libpg/src/message/error_response.dart';
import 'package:libpg/src/message/row_data.dart';
import 'package:libpg/src/message/row_description.dart';

class ExtendedQueryEntry implements QueueEntry {
  @override
  final String queryId;

  @override
  final String queryName;

  final List<dynamic> params;

  final PreparedQuery query;

  final _completer = Completer<CommandTag>();

  final _controller = StreamController<Row>();

  final dynamic paramFormats;

  CommandTag _commandTag;

  List<dynamic> _error = <dynamic>[];

  ExtendedQueryEntry(this.query, this.params,
      {this.paramFormats, this.queryId, this.queryName});

  Stream<Row> get stream => _controller.stream;

  List<FieldDescription> get fieldDescriptions => query.fieldDescriptions;

  int get fieldCount => fieldDescriptions.length;

  CommandTag get commandTag => _commandTag;

  Future<CommandTag> get onFinish => _completer.future;

  void addRow(RowData rowData) {
    final values = List<dynamic>(fieldDescriptions.length);
    final columns = List<Column>(fieldDescriptions.length);
    final columnsMap = <String, Column>{};
    final map = <String, dynamic>{};

    for (int i = 0; i < fieldDescriptions.length; i++) {
      final description = fieldDescriptions[i];
      final data = rowData[i];

      final value = decode(description, data);
      final column = Column(
          index: i,
          name: description.name,
          value: value,
          oid: description.oid,
          formatCode: description.formatType,
          typeModifier: description.typeModifier,
          typeLen: description.typeLen);

      values[i] = value;
      columns[i] = column;
      map[column.name] = value;
      columnsMap[column.name] = column;
    }

    _controller.add(Row(columns, columnsMap, values, map));
  }

  @override
  void addError(error, [StackTrace trace]) {
    if (error is ErrorResponse) {
      if (error.code == ErrorResponseCode.invalidSqlStatementName) {
        error = PreparedStatementNotExists(error, query.name);
      } else {
        error = PgServerException(error);
      }
    }
    _error.add(error);
    if (!_controller.isClosed) {
      _controller.addError(error, trace);
    }
  }

  void setCommandTag(CommandTag tag) {
    _commandTag = tag;
  }

  void finish() {
    _controller.close();

    if (_commandTag != null) {
      _completer.complete(_commandTag);
    } else if (_error.isNotEmpty) {
      _completer.completeError(_error.toList());
    } else {
      _completer.completeError('command tag not received');
    }
  }
}
