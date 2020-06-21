import 'dart:async';
import 'dart:collection';

import 'package:libpg/libpg.dart';
import 'query_entry.dart';
import 'package:libpg/src/message/row_description.dart';

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
    _error = error;
  }

  PreparedQuery complete() {
    if (_error != null) {
      final result = PreparedQueryImpl(
          connection,
          statementName,
          UnmodifiableListView(receivedParamOIDs),
          UnmodifiableListView(_fieldDescription));
      state = ParseEntryState.successful;
      _completer.complete(result);
      return result;
    }
    _completer.completeError(_error);
    return null;
  }

  dynamic _error;
}
