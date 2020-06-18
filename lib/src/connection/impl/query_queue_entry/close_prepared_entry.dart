import 'dart:async';

import 'query_entry.dart';
import 'package:libpg/src/message/parse.dart';

class ClosePreparedEntry implements QueueEntry {
  @override
  final String queryId;

  @override
  final String queryName;

  final CloseMessage message;

  final _completer = Completer<void>();

  ClosePreparedEntry(this.message, {this.queryId, this.queryName});

  @override
  void addError(error, [StackTrace trace]) {
    _completer.completeError(error, trace);
  }

  void finish() {
    _completer.complete();
  }

  Future<void> get onFinish => _completer.future;
}
