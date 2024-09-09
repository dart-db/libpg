import 'dart:async';

import 'package:libpg/libpg.dart';
import 'package:libpg/src/codec/decoder/decoder.dart';
import 'package:libpg/src/message/row_data.dart';
import 'package:libpg/src/message/row_description.dart';

import 'query_entry.dart';

class SimpleQueryEntry implements QueueEntry {
  final String statement;

  final DateTime startedAt;

  @override
  final String? queryId;

  @override
  final String? queryName;

  final _completer = Completer<CommandTag>();

  final _controller = StreamController<Row>();

  List<FieldDescription>? _fields;

  CommandTag? _commandTag;

  final _error = <dynamic>[];

  SimpleQueryEntry(this.statement,
      {DateTime? startedAt, this.queryId, this.queryName})
      : startedAt = startedAt ?? DateTime.now();

  Stream<Row> get stream => _controller.stream;

  Future<CommandTag> get onFinish => _completer.future..ignore();

  List<FieldDescription> get fieldDescriptions => _fields!;

  void setFieldsDescription(List<FieldDescription> fields) {
    _fields = fields;
  }

  int get fieldCount => _fields!.length;

  CommandTag? get commandTag => _commandTag;

  void addRow(RowData rowData) {
    final values = List<dynamic>.filled(_fields!.length, null);
    final columns = List<Column?>.filled(_fields!.length, null);
    final columnsMap = <String, Column>{};
    final map = <String, dynamic>{};

    for (int i = 0; i < _fields!.length; i++) {
      final description = _fields![i];
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

    _controller.add(Row(columns.cast<Column>(), columnsMap, values, map));
  }

  @override
  void addError(error, [StackTrace? trace]) {
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
      _completer.complete(commandTag);
    } else if (_error.isNotEmpty) {
      if(_error.length == 1) {
        _completer.completeError(_error.first);
      } else {
        _completer.completeError(_error.toList());
      }
    } else {
      _completer.completeError('command tag not received');
    }
  }
}
