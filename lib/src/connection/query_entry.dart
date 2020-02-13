import 'dart:async';
import 'dart:collection';

import 'package:libpg/libpg.dart';
import 'package:libpg/src/codec/decoder/decoder.dart';
import 'package:libpg/src/connection/row.dart';
import 'package:libpg/src/message/row_data.dart';
import 'package:libpg/src/message/row_description.dart';

abstract class QueueEntry {
  String get queryId;

  String get queryName;

  void addError(error, [StackTrace trace]);
}

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

enum ParseEntryState {
  unsent,
  sent,
  parsed,
  fieldDescriptionReceived,
  // TODO

  error,
  successful
}

class ParseEntry implements QueueEntry {
  final Connection connection;

  final String statement;

  final String statementName;

  final List<int> paramOIDs;

  @override
  final String queryName;

  @override
  final String queryId;

  final _completer = Completer<PreparedQuery>();

  ParseEntryState state = ParseEntryState.unsent;

  List<int> receivedParamOIDs;

  List<FieldDescription> _fieldDescription;

  ParseEntry(this.connection, this.statement,
      {this.statementName = '',
      this.paramOIDs = const [],
      this.queryId,
      this.queryName});

  Future<PreparedQuery> get future => _completer.future;

  void setFieldsDescription(List<FieldDescription> fields) {
    _fieldDescription = fields;
    state = ParseEntryState.fieldDescriptionReceived;
  }

  void setReceivedParamOIDs(List<int> value) {
    receivedParamOIDs = value;
  }

  @override
  void addError(error, [StackTrace stack]) {
    state = ParseEntryState.error;
    _completer.completeError(error, stack);
  }

  PreparedQuery complete() {
    final result = PreparedQuery(
        connection,
        statementName,
        UnmodifiableListView(receivedParamOIDs),
        UnmodifiableListView(_fieldDescription));
    state = ParseEntryState.successful;
    _completer.complete(result);
    return result;
  }
}

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

  dynamic _error;

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

class OIDs {
  static const bool = 16;
  static const bytea = 17;
  static const qChar = 18;
  static const name = 19;
  static const int8 = 20;
  static const int2 = 21;
  static const int4 = 23;
  static const text = 25;
  static const oid = 26;
  static const tid = 27;
  static const xid = 28;
  static const cid = 29;
  static const json = 114;
  static const point = 600;
  static const lseg = 601;
  static const path = 602;
  static const box = 603;
  static const polygon = 604;
  static const line = 628;
  static const cidr = 650;
  static const cidrArray = 651;
  static const float4 = 700;
  static const float8 = 701;
  static const circle = 718;
  static const unknown = 705;
  static const macaddr = 829;
  static const inet = 869;
  static const boolArray = 1000;
  static const int2Array = 1005;
  static const int4Array = 1007;
  static const textArray = 1009;
  static const byteaArray = 1001;
  static const BPCharArray = 1014;
  static const varcharArray = 1015;
  static const int8Array = 1016;
  static const float4Array = 1021;
  static const float8Array = 1022;
  static const ACLItem = 1033;
  static const ACLItemArray = 1034;
  static const inetArray = 1041;
  static const BPChar = 1042;
  static const varchar = 1043;
  static const date = 1082;
  static const time = 1083;
  static const timestamp = 1114;
  static const timestampArray = 1115;
  static const dateArray = 1182;
  static const timestamptz = 1184;
  static const timestamptzArray = 1185;
  static const interval = 1186;
  static const numericArray = 1231;
  static const bit = 1560;
  static const varbit = 1562;
  static const numeric = 1700;
  static const record = 2249;
  static const uuid = 2950;
  static const uuidArray = 2951;
  static const jsonb = 3802;
  static const daterange = 3912;
  static const int4range = 3904;
  static const numrange = 3906;
  static const tsrange = 3908;
  static const tstzrange = 3910;
  static const int8range = 3926;
}

abstract class FormatType {
  static const text = 0;

  static const binary = 1;
}
