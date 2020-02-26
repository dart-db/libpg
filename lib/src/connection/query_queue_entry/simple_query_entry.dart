import 'dart:async';

import 'package:libpg/libpg.dart';
import 'package:libpg/src/codec/decoder/decoder.dart';
import 'package:libpg/src/connection/query_queue_entry/query_entry.dart';
import 'package:libpg/src/connection/row.dart';
import 'package:libpg/src/message/row_data.dart';
import 'package:libpg/src/message/row_description.dart';

class SimpleQueryEntry implements QueueEntry {
  final String statement;

  final DateTime startedAt;

  @override
  final String queryId;

  @override
  final String queryName;

  final _completer = Completer<CommandTag>();

  final _controller = StreamController<Row>();

  List<FieldDescription> _fields;

  CommandTag _commandTag;

  dynamic _error;

  SimpleQueryEntry(this.statement,
      {DateTime startedAt, this.queryId, this.queryName})
      : startedAt = startedAt ?? DateTime.now();

  Stream<Row> get stream => _controller.stream;

  Future<CommandTag> get onFinish => _completer.future;

  List<FieldDescription> get fieldDescriptions => _fields;

  void setFieldsDescription(List<FieldDescription> fields) {
    _fields = fields;
  }

  int get fieldCount => _fields.length;

  CommandTag get commandTag => _commandTag;

  void addRow(RowData rowData) {
    final values = List<dynamic>(_fields.length);
    final columns = List<Column>(_fields.length);
    final columnsMap = <String, Column>{};
    final map = <String, dynamic>{};

    for (int i = 0; i < _fields.length; i++) {
      final description = _fields[i];
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
    _error ??= error;
    if (!_controller.isClosed) {
      _controller.addError(error, trace);
    }
    _completer.completeError(error, trace); // TODO should we do this?
  }

  void setCommandTag(CommandTag tag) {
    _commandTag = tag;
  }

  void finish() {
    _controller.close();
    if (_error == null) {
      _completer.complete(_commandTag);
    } else {
      _completer.completeError(_error);
    }
  }
}
