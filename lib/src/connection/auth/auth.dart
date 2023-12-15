import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:libpg/src/message/authreq.dart';

export 'sasl.dart';

abstract class Auth {
  List<int> handle(AuthMessage msg);

  bool get isDone;
}

class TrustedAuth implements Auth {
  @override
  List<int> handle(AuthMessage msg) {
    if (msg is AuthOkMessage) {
      return [];
    }
    throw Exception('unsupported message: ${msg.runtimeType} for trusted');
  }

  @override
  bool get isDone => true;
}

class MD5Auth implements Auth {
  final String username;
  final String password;

  MD5Auth({required this.username, required this.password});

  String _state = 'init';

  @override
  List<int> handle(AuthMessage msg) {
    if (msg is AuthMd5PasswordMessage) {
      return _handleQuestion(msg);
    } else if (msg is AuthOkMessage) {
      return _handleOk(msg);
    }
    throw Exception('unsupported message: ${msg.runtimeType} for MD5');
  }

  List<int> _handleQuestion(AuthMd5PasswordMessage msg) {
    if (_state != 'init') {
      throw Exception('invalid state');
    }
    _state = 'answered';
    return _encode(msg.salt).codeUnits.toList();
  }

  List<int> _handleOk(AuthOkMessage msg) {
    if (_state != 'answered') {
      throw Exception('invalid state');
    }
    _state = 'done';
    return [];
  }

  @override
  bool get isDone => _state != 'done';

  String _encode(List<int> salt) {
    final withoutSalt = _md5Encode(password + username);
    return 'md5' + _md5Encode(withoutSalt + String.fromCharCodes(salt));
  }

  static String _md5Encode(String s) {
    final bytes = md5.convert(s.codeUnits.toList()).bytes;
    return hex.encode(bytes);
  }
}

class CleartextPasswordAuth implements Auth {
  final String password;

  CleartextPasswordAuth({required this.password});

  String _state = 'init';

  @override
  List<int> handle(AuthMessage msg) {
    if(msg is AuthCleartextPasswordMessage) {
      return _handleInitial(msg);
    } else if (msg is AuthOkMessage) {
      return _handleOk(msg);
    }
    throw Exception('unsupported message: ${msg.runtimeType} for cleartext');
  }

  List<int> _handleInitial(AuthCleartextPasswordMessage msg) {
    if (_state != 'init') {
      throw Exception('invalid state');
    }

    _state = 'answered';
    return CleartextPasswordResponse(password).build();
  }

  List<int> _handleOk(AuthOkMessage msg) {
    if (_state != 'answered') {
      throw Exception('invalid state');
    }
    _state = 'done';
    return [];
  }

  @override
  bool get isDone => _state != 'done';
}
