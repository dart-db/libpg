enum LogLevel { debug, info, warning, error }

enum LogType {
  log,
}

class LogMessage {
  final LogLevel level;

  final LogType type;

  final DateTime at;

  final String connectionName;

  final String connectionId;

  final String queryName;

  final String queryId;

  final String message;

  LogMessage(
      {this.level = LogLevel.debug,
      this.type = LogType.log,
      this.connectionName,
      this.connectionId,
      this.queryName,
      this.queryId,
      DateTime at,
      this.message})
      : at = at ?? DateTime.now();

  @override
  String toString() => '$at\t$level\t${queryId ?? ''}\t$message';
}

typedef Logger = void Function(LogMessage message);
