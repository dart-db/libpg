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

  /// Represents character 'X'
  static const terminate = 88;

  /// Represents character 'P'
  static const parse = 80;

  /// Represents character 'D'
  static const describe = 68;

  /// Represents character 'B'
  static const bind = 66;

  /// Represents character 'E'
  static const execute = 69;

  /// Represents character 'S'
  static const sync = 83;

  /// Represents character '1'
  static const parseComplete = 49;

  /// Represents character '2'
  static const bindComplete = 50;

  /// Represents character '2'
  static const closeComplete = 51;

  /// Represents character 't'
  static const parameterDescription = 116;

  /// Represents character 'n'
  static const noData = 110;

  /// Represents character 'C'
  static const close = 67;

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
    parseComplete: 'Prase complete',
    parameterDescription: 'Parameter description',
    closeComplete: 'Close complete'
  };
}

abstract class ErrorResponseType {
  static const fatal = 83;
}
