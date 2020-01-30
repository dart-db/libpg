abstract class MessageType {
  /// Backend key data message sent by backend.
  /// Represents character 'K'
  static const backendKey = 75;

  /// Represents character 'E'
  static const errorResponse = 69;

  /// Authentication request message type sent by the backend.
  /// Represents character 'R'
  static const authRequest = 82;

  /// Password message sent by frontend to the backend.
  /// Represents character 'p'
  static const password = 112;

  /// Ready for accepting queries message sent by backend.
  /// Represents character 'Z'.
  static const readyForQuery = 90;

  /// Parameter status message sent by backend.
  /// Represents character 'S'.
  static const parameterStatus = 83;

  /// Represents character 'Q'
  static const query = 81;

  /// Represents character 'T'
  static const rowDescription = 84;

  /// Represents character 'D'
  static const rowData = 68;

  /// Represents character 'C'
  static const commandComplete = 67;

  static const name = <int, String>{
    backendKey: 'Backend key',
    authRequest: 'Authentication',
    password: 'Password',
    readyForQuery: 'Ready for query',
    parameterStatus: 'Parameter status',
    query: 'Query',
    rowDescription: 'Row description',
    rowData: 'Row data',
    commandComplete: 'Command complete',
  };
}

abstract class ErrorResponseType {
  static const fatal = 83;
}