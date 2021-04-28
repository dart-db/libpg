import 'package:libpg/src/message/error_response.dart';

abstract class PgServerException implements Exception {
  String? get code => error.code;

  String? get message => error.message;

  ErrorResponse get error;

  factory PgServerException(ErrorResponse response) = _PgServerExceptionImpl;
}

class _PgServerExceptionImpl implements PgServerException {
  @override
  final ErrorResponse error;

  _PgServerExceptionImpl(this.error);

  @override
  String? get code => error.code;

  @override
  String? get message => error.message;

  @override
  String toString() => 'PG server exception: $code. $message';
}

class PreparedStatementNotExists implements PgServerException {
  final String statementName;

  @override
  final ErrorResponse error;

  PreparedStatementNotExists(this.error, this.statementName);

  @override
  String? get code => error.code;

  @override
  String? get message => error.message;
}
