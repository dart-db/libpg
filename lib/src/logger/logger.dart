enum LogLevel {
  DEBUG,
  INFO,
  WARNING,
  ERROR
}

class LogMessage {
  final LogLevel level;

  final DateTime at;

  final String queryId;

  final String message;

  const LogMessage({this.level, this.at, this.queryId, this.message});

  @override
  String toString() => '$at\t$level\t${queryId??''}\t$message';
}

typedef Logger = void Function(LogMessage message);
