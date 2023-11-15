import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:libpg/src/connection/auth/auth.dart';
import 'package:libpg/src/message/authreq.dart';
import 'package:sasl_scram/sasl_scram.dart';

class SCRAMAuth implements Auth {
  late final ScramAuthenticator _auther;

  SCRAMAuth({required String username, required String password}) {
    _auther = ScramAuthenticator('SCRAM-SHA-256', sha256,
        UsernamePasswordCredential(username: username, password: password));
  }

  String _state = 'init';

  @override
  bool get isDone => _state == 'done';

  @override
  List<int> handle(AuthMessage msg) {
    if (msg is AuthSasl) {
      return _handleInitial(msg);
    } else if (msg is AuthSaslContinue) {
      return _handleContinue(msg);
    } else if (msg is AuthSaslFinal) {
      return _handleFinal(msg);
    } else if (msg is AuthOkMessage) {
      return _handleOk(msg);
    }
    throw Exception('unsupported message: ${msg.runtimeType} for SASL');
  }

  List<int> _handleInitial(AuthSasl msg) {
    if (_state != 'init') {
      throw Exception('invalid state');
    }
    _state = 'continue';
    final payload = _auther.handleMessage(
        SaslMessageType.AuthenticationSASL, Uint8List.fromList(msg.payload))!;
    return SaslInitialResponse(
            payload: payload, mechanismName: _auther.mechanism.name)
        .build();
  }

  List<int> _handleContinue(AuthSaslContinue msg) {
    if (_state != 'continue') {
      throw Exception('invalid state');
    }
    final payload = _auther.handleMessage(
        SaslMessageType.AuthenticationSASLContinue,
        Uint8List.fromList(msg.payload))!;
    return SaslResponse(payload).build();
  }

  List<int> _handleFinal(AuthSaslFinal msg) {
    if (_state != 'continue') {
      throw Exception('invalid state');
    }
    _auther.handleMessage(SaslMessageType.AuthenticationSASLFinal,
        Uint8List.fromList(msg.payload));
    _state = 'final';
    return [];
  }

  List<int> _handleOk(AuthOkMessage msg) {
    if (_state != 'final') {
      throw Exception('invalid state');
    }
    _state = 'done';
    return [];
  }
}
