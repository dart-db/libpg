import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:libpg/src/buffer/read_buffer.dart';
import 'package:libpg/src/logger/logger.dart';
import 'package:libpg/src/message/authreq_parser.dart';
import 'package:libpg/src/message/password_builder.dart';
import 'package:libpg/src/message/startup_builder.dart';

enum _ConnState {
  socketConnected,
  authenticating,
  authenticated,
  idle,
  busy,
  streaming,
  closed
}

abstract class MessageType {
  /// Authentication request message type sent by the backend.
  /// Represents character 'R'
  static const authRequest = 82;

  /// Password message sent by frontend to the backend.
  /// Represents character 'p'
  static const password = 112;

  /// Ready for accepting queries message sent by backend.
  /// Represents character 'Z'.
  static const readyForQuery = 90;
}

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

class Connection {
  final Socket _socket;

  final ConnSettings settings;

  _ConnState _state;

  final _connected = Completer<Connection>();

  DateTime _connectedAt;

  Logger _logger;

  Connection._(this._socket, this.settings) {
    _state = _ConnState.socketConnected;

    _socket.listen(_readData, onError: (e) {
      // TODO
    }, onDone: () {
      // TODO
    });

    _sendStartupMessage();
  }

  void _sendStartupMessage() {
    if (_state != _ConnState.socketConnected) {
      throw Exception('Invalid state during startup');
    }

    final msg = StartupMessageBuilder(
        protocolVersion: _protocolVersion,
        username: settings.username,
        databaseName: settings.databaseName,
        timezone: settings.timezone);

    _socket.add(msg.build());

    _state = _ConnState.authenticating;
  }

  final _buffer = ReadBuffer();

  _MessageHeader _curMsgHeader;

  void _readData(Uint8List data) {
    if (_state == _ConnState.closed) return;

    _buffer.append(data);

    if (_curMsgHeader == null) {
      if (_buffer.bytesAvailable < 5) return;

      _curMsgHeader = _MessageHeader.fromBuffer(_buffer);

      // TODO validate message length based on type
    }

    if (_curMsgHeader.length > _buffer.bytesAvailable) return;

    _handleMessage();

    _curMsgHeader = null;
  }

  static String _md5Encode(String s) {
    final bytes = md5.convert(s.codeUnits.toList()).bytes;
    return hex.encode(bytes);
  }

  void _handleMessage() {
    switch (_curMsgHeader.messageType) {
      case MessageType.authRequest:
        _handleAuthRequest();
        break;
      case MessageType.readyForQuery:
        _handleReadyForQuery();
        break;
      default:
        throw Exception('Unknown message type received');
        break;
    }
  }

  void _handleAuthRequest() {
    if (_state != _ConnState.authenticating) {
      throw Exception('Invalid connection state while authenticating');
    }

    final msg = AuthMessageParser.parse(_buffer);

    if (msg is AuthOkMessage) {
      _state = _ConnState.authenticated;
      return;
    }

    if (msg is AuthMd5PasswordMessage) {
      final withoutSalt = _md5Encode(settings.password + settings.username);
      final hash =
          'md5' + _md5Encode(withoutSalt + String.fromCharCodes(msg.salt));

      final resp = PasswordMessageBuilder(hash).build();
      _socket.add(resp);

      return;
    }

    if (msg is AuthErrorMessage) {
      throw Exception('Authentication error'); // TODO
    }

    if (msg is UnsupportedAuthMessage) {
      throw Exception('Unsupported auth method request received from server');
    }

    throw Exception('Unknown auth method request received from server');
  }

  void _handleReadyForQuery() {
    final status = _buffer.readByte();

    if(status == ReadyQueryStatus.idle) {
      // TODO
    } else if(status == ReadyQueryStatus.inTransaction) {
      // TODO
    } else if(status == ReadyQueryStatus.inFailedTransaction) {
      // TODO
    } else {
      throw Exception('Unknown ready for query transaction status');
    }

    final oldState = _state;

    _state = _ConnState.idle;

    // TODO close query

    if(oldState == _ConnState.authenticated) {
      // TODO complete connection Future
      _connectedAt = DateTime.now();
      _connected.complete(this);
    }

    // TODO send next query in the queue
  }

  DateTime get connectedAt => _connectedAt;

  Future<dynamic> query(String query) async {
    // TODO
  }

  Future<dynamic> execute(String query) async {
    // TODO
  }

  Future<void> close() async {
    // TODO
  }

  static Future<Connection> connect(ConnSettings settings) async {
    final socket = await Socket.connect(settings.hostname, settings.port);

    // TODO ssl

    final conn = Connection._(socket, settings);

    return conn._connected.future;
  }

  static const int _protocolVersion = 196608;
}

class _MessageHeader {
  final int messageType;

  final int length;

  _MessageHeader(this.messageType, this.length);

  factory _MessageHeader.fromBuffer(ReadBuffer buffer) {
    return _MessageHeader(buffer.readByte(), buffer.readInt32() - 4);
  }
}

abstract class ReadyQueryStatus {
  static const idle = 73;

  static const inTransaction = 84;

  static const inFailedTransaction = 69;
}