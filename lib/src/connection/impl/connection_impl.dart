import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:libpg/libpg.dart';
import 'package:libpg/src/buffer/read_buffer.dart';
import 'package:libpg/src/codec/encode/encode.dart';
import 'package:libpg/src/connection/auth/auth.dart';
import 'query_queue_entry/query_entry.dart';
import 'package:libpg/src/connection/row.dart';
import 'package:libpg/src/util/generator.dart';
import 'package:libpg/src/logger/logger.dart';
import 'package:libpg/src/message/authreq.dart';
import 'package:libpg/src/message/backendkey.dart';
import 'package:libpg/src/message/error_response.dart';
import 'package:libpg/src/message/message_header.dart';
import 'package:libpg/src/message/parameter_description.dart';
import 'package:libpg/src/message/parameter_status.dart';
import 'package:libpg/src/message/parse.dart';
import 'package:libpg/src/message/password.dart';
import 'package:libpg/src/message/query.dart';
import 'package:libpg/src/message/row_data.dart';
import 'package:libpg/src/message/row_description.dart';
import 'package:libpg/src/message/startup.dart';
import 'package:libpg/src/message/terminate.dart';

import 'package:libpg/src/message/message_type.dart';

class ConnectionImpl implements Connection {
  final Socket _socket;

  @override
  final ConnSettings settings;

  @override
  final String connectionId;

  String? _connectionName;

  _ConnState? _state;

  final _connected = Completer<ConnectionImpl>();

  DateTime? _connectedAt;

  final Logger _logger;

  final _queryQueue = Queue<QueueEntry>();

  QueueEntry? _currentQuery;

  final IdGenerator _queryIdGenerator;

  StreamSubscription? _socketSubscription;

  ConnectionImpl._(this._socket, this.settings,
      {Logger? logger, String? connectionName, IdGenerator? queryIdGenerator})
      : _logger = logger ?? nopLogger,
        connectionId = connectionIdGenerator.get,
        _queryIdGenerator = queryIdGenerator ?? IdGenerator(prefix: 'query') {
    _connectionName = connectionName ?? connectionId;
    _state = _ConnState.socketConnected;

    _socketSubscription = _socket.listen(_gotData, onError: (e) {
      print(e); // TODO log instead
      // TODO
    }, onDone: () {
      // TODO
    });

    _sendStartupMessage();
  }

  @override
  String get connectionName => _connectionName!;

  void _sendStartupMessage() {
    if (_state != _ConnState.socketConnected) {
      throw Exception('Invalid state during startup');
    }

    final msg = StartupMessage(
        protocolVersion: _protocolVersion,
        username: settings.username ?? '',
        databaseName: settings.databaseName,
        timezone: settings.timezone);

    _socket.add(msg.build());

    _state = _ConnState.authenticating;
  }

  final _buffer = ReadBuffer();

  MessageHeader? _curMsgHeader;

  void _gotData(Uint8List data) {
    if (_state == _ConnState.closed) return;

    _buffer.append(data);

    while (true) {
      if (_curMsgHeader == null) {
        if (_buffer.bytesAvailable < 5) return;

        _curMsgHeader = MessageHeader.fromBuffer(_buffer);
      }

      if (_curMsgHeader!.length > _buffer.bytesAvailable) return;

      _handleMessage(_curMsgHeader!);

      _curMsgHeader = null;
    }
  }

  void _handleMessage(MessageHeader header) {
    final messageName = MessageType.name[_curMsgHeader!.messageType];
    _log(LogMessage(
        message:
            'Received backend message with type ${_curMsgHeader!.messageType} (${String.fromCharCode(_curMsgHeader!.messageType)}: ${messageName != null ? '$messageName' : ''})',
        connectionId: connectionId,
        connectionName: connectionName));
    switch (_curMsgHeader!.messageType) {
      case MessageType.rowData:
        _handleRowDataMsg();
        break;
      case MessageType.rowDescription:
        _handleRowDescriptionMsg();
        break;
      case MessageType.parameterDescription:
        _handleParameterDescriptionMsg();
        break;
      case MessageType.commandComplete:
        _handleCommandCompleteMsg();
        break;
      case MessageType.readyForQuery:
        _handleReadyForQueryMsg();
        break;
      case MessageType.noData:
        // TODO
        break;
      case MessageType.bindComplete:
        _handleBindCompleteMsg();
        break;
      case MessageType.parseComplete:
        _handleParseCompleteMsg();
        break;
      case MessageType.parameterStatus:
        _handleParameterStatusMsg();
        break;
      case MessageType.closeComplete:
        _handleCloseCompleteMsg();
        break;
      case MessageType.authRequest:
        _handleAuthRequestMsg(header);
        break;
      case MessageType.backendKey:
        _handleBackendKeyDataMsg();
        break;
      case MessageType.errorResponse:
        _handleErrorResponseMsg();
        break;
      case MessageType.noticeResponse:
        _handleErrorResponseMsg();
        break;
      default:
        throw Exception(
            'Unknown message type (${_curMsgHeader!.messageType}) received');
    }
  }

  void _removeCurrentQuery() {
    _state = _ConnState.idle;
    _currentQuery = null;
    _sendNext();
  }

  Auth? _auth;

  void _handleAuthRequestMsg(MessageHeader header) {
    if (_state != _ConnState.authenticating) {
      throw Exception('Invalid connection state while authenticating');
    }

    final msg = AuthMessage.parse(_buffer, header);

    _log(LogMessage(
        message: 'Authentication request received of type ${msg.method}',
        connectionName: connectionName,
        connectionId: connectionId));

    if (_auth == null) {
      if (msg is AuthMd5PasswordMessage) {
        _log(LogMessage(
            message: 'Performing MD5 password authentication',
            connectionName: connectionName,
            connectionId: connectionId));
        _auth = MD5Auth(
            username: settings.username ?? '',
            password: settings.password ?? '');
        return;
      } else if (msg is AuthSasl) {
        _log(LogMessage(
            message: 'Performing SASL password authentication',
            connectionName: connectionName,
            connectionId: connectionId));
        _auth = SCRAMAuth(
            username: settings.username ?? '',
            password: settings.password ?? '');
      } else if (msg is AuthCleartextPasswordMessage) {
        _log(LogMessage(
            message: 'Performing cleartext password authentication',
            connectionName: connectionName,
            connectionId: connectionId));
        _auth = CleartextPasswordAuth(password: settings.password ?? '');
      } else if(msg is AuthOkMessage) {
        _log(LogMessage(
            message: 'Trusted authentication',
            connectionName: connectionName,
            connectionId: connectionId));
        _auth = TrustedAuth();
      } else {
        _connectionError(Exception('Unsupported auth method: ${msg.method}'));
        return;
      }
    }

    try {
      final resp = _auth!.handle(msg);
      _socket.add(resp);
      if (_auth!.isDone) {
        _state = _ConnState.authenticated;
        return;
      }
    } on Exception catch (e) {
      _connectionError(e);
    }
  }

  void _connectionError(Exception err) {
    _connected.completeError(err);
    _shutdown();
  }

  void _handleReadyForQueryMsg() {
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
    final queryEntry = _currentQuery;

    _removeCurrentQuery();

    if (queryEntry != null) {
      _log(LogMessage(
          queryId: queryEntry.queryId,
          queryName: queryEntry.queryName,
          connectionName: connectionName,
          connectionId: connectionId,
          message: 'Query finished'));
      if (queryEntry is SimpleQueryEntry) {
        queryEntry.finish();
      } else if (queryEntry is ParseEntry) {
        final prepared = queryEntry.complete();
        if (prepared != null) {
          _prepared.add(prepared);
        }
      } else if (queryEntry is ExtendedQueryEntry) {
        queryEntry.finish();
      }
    }

    if (oldState == _ConnState.authenticated) {
      _connectedAt = DateTime.now();
      _connected.complete(this);
    }
  }

  void _handleParameterStatusMsg() {
    final message = ParameterStatus.parse(_buffer);

    _parameters[message.name] = message.value;

    _log(LogMessage(
        connectionId: connectionId,
        connectionName: connectionName,
        message: 'Received parameter ${message.name}=${message.value}'));

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
    final msg = RowDescription.parse(_buffer, _curMsgHeader!.length);
    _log(LogMessage(
        connectionName: connectionName,
        connectionId: connectionId,
        queryName: _currentQuery!.queryName,
        queryId: _currentQuery!.queryId,
        message:
            'Received row description with field count ${msg.fieldCount}'));
    if (_currentQuery is SimpleQueryEntry) {
      (_currentQuery as SimpleQueryEntry).setFieldsDescription(msg.fields);
    } else if (_currentQuery is ParseEntry) {
      (_currentQuery as ParseEntry).setFieldsDescription(msg.fields);
    } else {
      throw Exception(''); // TODO
    }
  }

  void _handleParameterDescriptionMsg() {
    final msg = ParameterDescriptionMsg.parse(_buffer);
    if (_currentQuery is ParseEntry) {
      // TODO (_currentQuery as ParseEntry).
    }
    // TODO
  }

  void _handleRowDataMsg() {
    final msg = RowData.parse(_buffer, _curMsgHeader!);
    _log(LogMessage(
        connectionName: connectionName,
        connectionId: connectionId,
        queryName: _currentQuery!.queryName,
        queryId: _currentQuery!.queryId,
        message: 'Received row data'));
    if (_currentQuery is SimpleQueryEntry) {
      (_currentQuery as SimpleQueryEntry).addRow(msg);
    } else if (_currentQuery is ExtendedQueryEntry) {
      (_currentQuery as ExtendedQueryEntry).addRow(msg);
    } else {
      throw Exception(''); // TODO
    }
  }

  void _handleCommandCompleteMsg() {
    final msg = CommandComplete.parse(_buffer, _curMsgHeader!);
    if (_currentQuery is SimpleQueryEntry) {
      (_currentQuery as SimpleQueryEntry)
          .setCommandTag(CommandTag.parse(msg.tag));
    } else if (_currentQuery is ExtendedQueryEntry) {
      (_currentQuery as ExtendedQueryEntry)
          .setCommandTag(CommandTag.parse(msg.tag));
    } else {
      throw Exception(''); // TODO
    }
  }

  void _handleErrorResponseMsg() {
    final msg = ErrorResponse.parse(_buffer, _curMsgHeader!);
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
      return;
    }
    // TODO handle fatal errors?

    if (_currentQuery != null) {
      _currentQuery!.addError(msg);
      return;
    }
  }

  void _handleCloseCompleteMsg() {
    // TODO log
    if (_currentQuery is ClosePreparedEntry) {
      (_currentQuery as ClosePreparedEntry).finish();
    } else {
      throw Exception('unexpected query entry');
    }
    _removeCurrentQuery();
  }

  final _parameters = <String, String>{};

  BackendKeyData? _backendKeyData;

  int? get pid => _backendKeyData?.pid;

  DateTime? get connectedAt => _connectedAt;

  void _sendNext() {
    if (_currentQuery != null) return;
    if (_queryQueue.isEmpty) return;
    if (_state == _ConnState.closed) return;

    if (_state != _ConnState.idle) {
      // TODO
      return;
    }

    _state = _ConnState.busy;
    _currentQuery = _queryQueue.removeFirst();
    if (_currentQuery is SimpleQueryEntry) {
      _logger(LogMessage(
          connectionId: connectionId,
          connectionName: connectionName,
          message: 'Sending simple query message'));
      _sendSimpleQuery(_currentQuery as SimpleQueryEntry);
    } else if (_currentQuery is ParseEntry) {
      _logger(LogMessage(
          connectionId: connectionId,
          connectionName: connectionName,
          message: 'Sending parse message'));
      _sendParseEntry(_currentQuery as ParseEntry);
      // TODO
    } else if (_currentQuery is ExtendedQueryEntry) {
      _logger(LogMessage(
          connectionId: connectionId,
          connectionName: connectionName,
          message: 'Sending extended query message'));
      _sendExtendedQueryEntry(_currentQuery as ExtendedQueryEntry);
    } else if (_currentQuery is ClosePreparedEntry) {
      _logger(LogMessage(
          connectionId: connectionId,
          connectionName: connectionName,
          message: 'Sending close prepared statement message'));
      _socket.add((_currentQuery as ClosePreparedEntry).message.build());
      _socket.add(SyncMessage().build());
    } else {
      throw Exception('Unknown queue entry');
    }
    // TODO transaction state
  }

  void _sendSimpleQuery(SimpleQueryEntry query) {
    _log(LogMessage(
        connectionName: connectionName,
        connectionId: connectionId,
        queryName: query.queryName,
        queryId: query.queryId,
        message: 'Sending new query ${query.queryId}'));
    _socket.add(QueryMessage(query.statement).build());
    // TODO transaction state
  }

  void _sendParseEntry(ParseEntry query) {
    final parseMsg = ParseMessage(query.statement,
        name: query.statementName, paramOIDs: query.paramOIDs);
    final describeMsg =
        DescribeMessage(DescribeMessage.statementType, query.statementName);
    final syncMsg = SyncMessage();

    _socket.add(parseMsg.build());
    _socket.add(describeMsg.build());
    _socket.add(syncMsg.build());
    query.state = ParseEntryState.sent;
  }

  void _sendExtendedQueryEntry(ExtendedQueryEntry query) {
    final bindMsg = Bind(query.params.cast<List<int>>(),
        statementName: query.query.name,
        portalName: '' /* TODO */,
        outputFormats: 0 /* TODO */,
        paramFormats: query.paramFormats);
    final executeMsg = Execute(portal: '' /* TODO */);
    final syncMsg = SyncMessage();

    _socket.add(bindMsg.build());
    _socket.add(executeMsg.build());
    _socket.add(syncMsg.build());
  }

  void _enqueueQuery(QueueEntry entry, {String? queryName}) {
    _queryQueue.add(entry);
    if (_queryQueue.length == 1) {
      _sendNext();
    }
  }

  void _handleParseCompleteMsg() {
    if (_currentQuery is! ParseEntry) {
      throw Exception('');
    }

    final query = _currentQuery as ParseEntry;
    query.state = ParseEntryState.parsed;
    _log(LogMessage(
        connectionName: connectionName,
        connectionId: connectionId,
        queryName: query.queryName,
        queryId: query.queryId,
        message: 'Parse complete!'));
  }

  void _handleBindCompleteMsg() {
    if (_currentQuery is! ExtendedQueryEntry) {
      throw Exception('');
    }
    // TODO
  }

  @override
  Rows query(String sql, {String? queryName}) {
    final queryId = _queryIdGenerator.get;
    final entry = SimpleQueryEntry(sql,
        queryId: queryId, queryName: queryName ?? queryId);
    _enqueueQuery(entry, queryName: queryName);
    return Rows(entry.stream.cast<Row>(), entry.onFinish);
  }

  @override
  Future<CommandTag> execute(String sql,
      {String? queryName, List<dynamic>? values}) async {
    // TODO values
    final rows = query(sql, queryName: queryName);
    return rows.finished;
  }

  @override
  Future<PreparedQuery> prepare(String query,
      {String statementName = '',
      String? queryName,
      List<int> paramOIDs = const []}) async {
    final entry = ParseEntry(this, query,
        statementName: statementName,
        paramOIDs: paramOIDs,
        queryId: _queryIdGenerator.get,
        queryName: queryName);
    _enqueueQuery(entry);
    return entry.future;
  }

  final _prepared = <PreparedQuery>{};

  @override
  Rows queryPrepared(PreparedQuery query, List<dynamic> params,
      {String? queryName}) {
    dynamic paramFormats = List<int>.filled(params.length, 1);
    int i = -1;
    bool hasTextFormat = false;
    params = params.map<List<int>?>((p) {
      i++;
      if (p is TextData) {
        hasTextFormat = true;
        paramFormats[i] = 0;
        return p.data;
      } else if (p is ToPgSql) {
        hasTextFormat = true;
        paramFormats[i] = 0;
        return utf8.encode(p.toPgSql());
      } else if (p is BinaryData) {
        return p.data;
      } else if (p is ToPGBinary) {
        return p.toPGBinary();
      } else {
        final data = encode(p);
        if (data.format == 0) {
          hasTextFormat = true;
          paramFormats[i] = 0;
        }
        return data.data;
      }
    }).toList();
    if (!hasTextFormat) {
      paramFormats = 1;
    }
    final entry = ExtendedQueryEntry(
      query,
      params,
      queryId: _queryIdGenerator.get,
      queryName: queryName,
      paramFormats: paramFormats,
    );
    _enqueueQuery(entry);
    return Rows(entry.stream, entry.onFinish);
  }

  @override
  Future<void> releasePrepared(PreparedQuery query, {String? queryName}) {
    final entry = ClosePreparedEntry(
        CloseMessage(query.name, type: CloseType.preparedStatement),
        queryId: _queryIdGenerator.get,
        queryName: queryName);
    _enqueueQuery(entry);
    return entry.onFinish;
  }

  @override
  Future<void> close() async {
    if (_state == _ConnState.closed) {
      return;
    }

    _log(LogMessage(
        connectionName: connectionName,
        connectionId: connectionId,
        message: 'Sending close message'));

    try {
      final msg = Terminate();
      _socket.add(msg.build());
      await _socket.flush();
    } catch (e) {
      // TODO
    }

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

  void _log(LogMessage msg) {
    _logger(msg);
  }

  static Future<ConnectionImpl> connect(ConnSettings settings,
      {String? connectionName,
      Logger? logger,
      IdGenerator? queryIdGenerator}) async {
    // TODO implement UNIX domain sockets
    Socket socket = await Socket.connect(settings.hostname, settings.port);

    // TODO ssl

    final conn = ConnectionImpl._(socket, settings,
        connectionName: connectionName,
        logger: logger,
        queryIdGenerator: queryIdGenerator);

    return conn._connected.future;
  }

  static const int _protocolVersion = 196608;
}

enum _ConnState {
  socketConnected,
  authenticating,
  authenticated,
  idle,
  busy,
  streaming,
  closed
}

abstract class ReadyQueryStatus {
  static const idle = 73;

  static const inTransaction = 84;

  static const inFailedTransaction = 69;
}
