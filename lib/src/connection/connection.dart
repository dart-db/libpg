import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:libpg/src/buffer/read_buffer.dart';
import 'package:libpg/src/connection/query_entry.dart';
import 'package:libpg/src/connection/row.dart';
import 'package:libpg/src/id/generator.dart';
import 'package:libpg/src/logger/logger.dart';
import 'package:libpg/src/message/authreq_parser.dart';
import 'package:libpg/src/message/backend_key_data_parser.dart';
import 'package:libpg/src/message/error_response.dart';
import 'package:libpg/src/message/parameter_status_parser.dart';
import 'package:libpg/src/message/password_builder.dart';
import 'package:libpg/src/message/query_builder.dart';
import 'package:libpg/src/message/row_data.dart';
import 'package:libpg/src/message/row_description.dart';
import 'package:libpg/src/message/startup_builder.dart';

import 'message_type.dart';

enum _ConnState {
  socketConnected,
  authenticating,
  authenticated,
  idle,
  busy,
  streaming,
  closed
}

final connectionIdGenerator = IdGenerator(prefix: 'conn');

class ConnSettings {
  final String hostname;
  final int port;
  final String databaseName;
  final String username;
  final String password;
  final String timezone;

  ConnSettings({
    this.hostname = 'localhost',
    this.port = 5432,
    this.databaseName = 'postgres',
    this.username,
    this.password,
    this.timezone,
  });
}

void nopLogger(LogMessage msg) {}

abstract class Querier {
  ConnSettings get settings;

  Rows query(String query, {String queryName});

  Future<CommandTag> execute(String execute, {String queryName});

  Future<Tx> beginTransaction();

  Future<void> close();
}

abstract class Tx implements Querier {
  Future<dynamic> commit();

  Future<dynamic> rollback();
}

abstract class Connection implements Querier {
  String get connectionId;

  String get connectionName;

  static Future<Connection> connect(ConnSettings settings,
          {String connectionName, Logger logger}) =>
      ConnectionImpl.connect(settings,
          connectionName: connectionName, logger: logger);
}

class ConnectionImpl implements Connection {
  final Socket _socket;

  @override
  final ConnSettings settings;

  @override
  final String connectionId;

  String _connectionName;

  _ConnState _state;

  final _connected = Completer<ConnectionImpl>();

  DateTime _connectedAt;

  final Logger _logger;

  final _queryQueue = Queue<QueryEntry>();

  QueryEntry _currentQuery;

  IdGenerator _queryIdGenerator;

  ConnectionImpl._(this._socket, this.settings,
      {Logger logger, String connectionName, IdGenerator queryIdGenerator})
      : _logger = logger ?? nopLogger,
        connectionId = connectionIdGenerator.get,
        _queryIdGenerator = queryIdGenerator ?? IdGenerator(prefix: 'query') {
    _connectionName = connectionName ?? connectionId;
    _state = _ConnState.socketConnected;

    _socket.listen(_gotData, onError: (e) {
      // TODO
    }, onDone: () {
      // TODO
    });

    _sendStartupMessage();
  }

  @override
  String get connectionName => _connectionName;

  void _sendStartupMessage() {
    if (_state != _ConnState.socketConnected) {
      throw Exception('Invalid state during startup');
    }

    final msg = StartupMessage(
        protocolVersion: _protocolVersion,
        username: settings.username,
        databaseName: settings.databaseName,
        timezone: settings.timezone);

    _socket.add(msg.build());

    _state = _ConnState.authenticating;
  }

  final _buffer = ReadBuffer();

  MessageHeader _curMsgHeader;

  void _gotData(Uint8List data) {
    if (_state == _ConnState.closed) return;

    _buffer.append(data);

    while (true) {
      if (_curMsgHeader == null) {
        if (_buffer.bytesAvailable < 5) return;

        _curMsgHeader = MessageHeader.fromBuffer(_buffer);

        // TODO validate message length based on type
      }

      if (_curMsgHeader.length > _buffer.bytesAvailable) return;

      _handleMessage();

      _curMsgHeader = null;
    }
  }

  static String _md5Encode(String s) {
    final bytes = md5.convert(s.codeUnits.toList()).bytes;
    return hex.encode(bytes);
  }

  void _handleMessage() {
    final messageName = MessageType.name[_curMsgHeader.messageType];
    _log(LogMessage(
        message:
            'Received backend message with type ${_curMsgHeader.messageType} ${messageName != null ? '($messageName)' : ''}',
        connectionId: connectionId,
        connectionName: connectionName));
    switch (_curMsgHeader.messageType) {
      case MessageType.rowData:
        _handleRowDataMsg();
        break;
      case MessageType.rowDescription:
        _handleRowDescriptionMsg();
        break;
      case MessageType.commandComplete:
        _handleCommandCompleteMsg();
        break;
      case MessageType.readyForQuery:
        _handleReadyForQuery();
        break;
      case MessageType.parameterStatus:
        _handleParameterStatusMsg();
        break;
      case MessageType.authRequest:
        _handleAuthRequest();
        break;
        break;
      case MessageType.backendKey:
        _handleBackendKeyDataMsg();
        break;
      case MessageType.errorResponse:
        _handleErrorResponseMsg();
        break;
      default:
        throw Exception(
            'Unknown message type (${_curMsgHeader.messageType}) received');
        break;
    }
  }

  void _handleAuthRequest() {
    if (_state != _ConnState.authenticating) {
      throw Exception('Invalid connection state while authenticating');
    }

    final msg = AuthMessageParser.parse(_buffer);

    _log(LogMessage(
        message: 'Authentication request received of type ${msg.method}',
        connectionName: connectionName,
        connectionId: connectionId));

    if (msg is AuthOkMessage) {
      _log(LogMessage(
          message: 'Authentication successfull',
          level: LogLevel.info,
          connectionName: connectionName,
          connectionId: connectionId));
      _state = _ConnState.authenticated;
      return;
    }

    if (msg is AuthMd5PasswordMessage) {
      _log(LogMessage(
          message: 'Performing MD5 password authentication',
          connectionName: connectionName,
          connectionId: connectionId));

      final withoutSalt = _md5Encode(settings.password + settings.username);
      final hash =
          'md5' + _md5Encode(withoutSalt + String.fromCharCodes(msg.salt));

      final resp = PasswordMessage(hash).build();
      _socket.add(resp);

      return;
    }

    /*
    if (msg is AuthErrorMessage) {
      throw Exception('Authentication error'); // TODO
    }*/

    if (msg is UnsupportedAuthMessage) {
      throw Exception('Unsupported auth method request received from server');
    }

    throw Exception('Unknown auth method request received from server');
  }

  void _handleReadyForQuery() {
    final status = _buffer.readByte();

    if (status == ReadyQueryStatus.idle) {
      // TODO
    } else if (status == ReadyQueryStatus.inTransaction) {
      // TODO
    } else if (status == ReadyQueryStatus.inFailedTransaction) {
      // TODO
    } else {
      throw Exception('Unknown ready for query transaction status');
    }

    final oldState = _state;

    _state = _ConnState.idle;

    if (_currentQuery != null) {
      _log(LogMessage(
          queryId: _currentQuery.queryId,
          queryName: _currentQuery.queryName,
          connectionName: connectionName,
          connectionId: connectionId,
          message: 'Query finished'));
      _currentQuery.finish();
      _currentQuery = null;
    }

    if (oldState == _ConnState.authenticated) {
      _connectedAt = DateTime.now();
      _connected.complete(this);
    }

    Timer.run(_sendQuery);
  }

  void _handleParameterStatusMsg() {
    final message = ParameterStatus.parse(_buffer);

    // _parameters[message.name] = message.value;

    _log(LogMessage(
        connectionId: connectionId,
        connectionName: connectionName,
        message: 'Received parameter ${message.name}'));

    switch (message.name) {
      case 'TimeZone':
      case 'client_encoding':
        _parameters[message.name] = message.value;
        break;
    }

    if (message.name == 'client_encoding' && message.value != 'UTF8') {
      // TODO warn that unexpected client_encoding requested by server
    }
  }

  void _handleBackendKeyDataMsg() {
    _backendKeyData = BackendKeyData.parse(_buffer);
  }

  void _handleRowDescriptionMsg() {
    final msg = RowDescription.parse(_buffer, _curMsgHeader.length);
    _log(LogMessage(
        connectionName: connectionName,
        connectionId: connectionId,
        queryName: _currentQuery.queryName,
        queryId: _currentQuery.queryId,
        message:
            'Received row description with field count ${msg.fieldCount}'));
    _currentQuery.setFieldsDescription(msg.fields);
  }

  void _handleRowDataMsg() {
    final msg = RowData.parse(_buffer, _curMsgHeader);
    _log(LogMessage(
        connectionName: connectionName,
        connectionId: connectionId,
        queryName: _currentQuery.queryName,
        queryId: _currentQuery.queryId,
        message: 'Received row data'));
    _currentQuery.addRow(msg);
  }

  void _handleCommandCompleteMsg() {
    final msg = CommandComplete.parse(_buffer, _curMsgHeader);
    _currentQuery.setCommandTag(CommandTag.parse(msg.tag));
  }

  void _handleErrorResponseMsg() {
    final msg = ErrorResponse.parse(_buffer, _curMsgHeader);
    _log(LogMessage(
      connectionName: connectionName,
      connectionId: connectionId,
      queryName: _currentQuery?.queryName,
      queryId: _currentQuery?.queryId,
      message: 'Received ErrorResponse code: ${msg.code} msg: ${msg.message}',
    ));
    if (!_connected.isCompleted) {
      _connected.completeError(msg);
      _shutdown();
    }
    // TODO
  }

  final _parameters = <String, String>{};

  BackendKeyData _backendKeyData;

  int get pid => _backendKeyData?.pid;

  DateTime get connectedAt => _connectedAt;

  void _sendQuery() {
    if (_currentQuery != null) return;
    if (_queryQueue.isEmpty) return;
    if (_state == _ConnState.closed) return;

    if (_state != _ConnState.idle) {
      // TODO
      return;
    }

    _state = _ConnState.busy;
    _currentQuery = _queryQueue.removeFirst();
    _log(LogMessage(
        connectionName: connectionName,
        connectionId: connectionId,
        queryName: _currentQuery.queryName,
        queryId: _currentQuery.queryId,
        message: 'Sending new query ${_currentQuery.queryId}'));
    _socket.add(QueryMessage(_currentQuery.statement).build());
    // TODO transaction state
  }

  QueryEntry _enqueueQuery(String query, {String queryName}) {
    final queryId = _queryIdGenerator.get;
    final entry =
        QueryEntry(query, queryId: queryId, queryName: queryName ?? queryId);
    _queryQueue.add(entry);
    if (_queryQueue.length == 1) _sendQuery();
    return entry;
  }

  @override
  Rows query(String query, {String queryName}) {
    final entry = _enqueueQuery(query, queryName: queryName);
    return Rows(entry.stream.cast<Row>(), entry.onFinish);
  }

  @override
  Future<CommandTag> execute(String query, {String queryName}) async {
    final entry = _enqueueQuery(query, queryName: queryName);
    await entry.onFinish;
    return entry.commandTag;
  }

  @override
  Future<Tx> beginTransaction() async {
    // TODO
  }

  @override
  Future<void> close() async {
    // TODO
    await _shutdown();
  }

  Future<void> _shutdown() async {
    if (_state != _ConnState.closed) {
      _log(LogMessage(
          connectionName: connectionName,
          connectionId: connectionId,
          message: 'Closing down socket'));
      await _socket.close();
      _state = _ConnState.closed;
    }
  }

  void _log(LogMessage msg) async {
    _logger(msg);
  }

  static Future<ConnectionImpl> connect(ConnSettings settings,
      {String connectionName, Logger logger}) async {
    Socket socket;
    socket = await Socket.connect(settings.hostname, settings.port);
    /*
    try {
      socket = await Socket.connect(settings.hostname, settings.port);
    } on SocketException catch (e) {}
    */
    // TODO ssl

    final conn = ConnectionImpl._(socket, settings,
        connectionName: connectionName, logger: logger);

    return conn._connected.future;
  }

  static const int _protocolVersion = 196608;
}

class MessageHeader {
  final int messageType;

  final int length;

  MessageHeader(this.messageType, this.length);

  factory MessageHeader.fromBuffer(ReadBuffer buffer) {
    return MessageHeader(buffer.readByte(), buffer.readInt32() - 4);
  }
}

abstract class ReadyQueryStatus {
  static const idle = 73;

  static const inTransaction = 84;

  static const inFailedTransaction = 69;
}

class CommandTag {
  final String tagName;

  final String tag;

  final int rowsAffected;

  CommandTag(this.tagName, this.tag, this.rowsAffected);

  static CommandTag parse(String tag) {
    final parts = tag.split(' ');
    return CommandTag(parts.first, tag, int.tryParse(parts.last));
  }
}

class Rows {
  final Stream<Row> rows;

  final Future<void> finished;

  Rows(this.rows, this.finished);
}
