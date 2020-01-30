import 'dart:async';

import 'package:libpg/libpg.dart';
import 'package:libpg/src/message/row_data.dart';
import 'package:libpg/src/message/row_description.dart';

class QueryEntry {
  final String statement;

  final DateTime startedAt;

  final String queryId;

  final String queryName;

  final _completer = Completer<void>();

  final _controller = StreamController<dynamic>();

  List<FieldDescription> _fields;

  CommandTag _commandTag;

  QueryEntry(this.statement, {DateTime startedAt, this.queryId, this.queryName})
      : startedAt = startedAt ?? DateTime.now();

  Stream<dynamic> get stream => _controller.stream;
  
  Future<void> get onFinish => _completer.future;

  List<FieldDescription> get fieldDescriptions => _fields;

  void setFieldsDescription(List<FieldDescription> fields) {
    _fields = fields;
  }

  int get fieldCount => _fields.length;

  CommandTag get commandTag => _commandTag;

  void addRow(RowData rowData) {
    // TODO
  }

  void setCommandTag(CommandTag tag) {
    _commandTag = tag;
  }

  void finish() {
    _controller.close();
    _completer.complete();
  }
}
