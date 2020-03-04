export 'extended_query_entry.dart';
export 'simple_query_entry.dart';
export 'close_prepared_entry.dart';
export 'parse_entry.dart';

abstract class QueueEntry {
  String get queryId;

  String get queryName;

  void addError(error, [StackTrace trace]);
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
