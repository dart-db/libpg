import 'package:libpg/src/buffer/read_buffer.dart';

class AuthMethod {
  static const ok = 0;

  static const kerberosV5 = 2;

  static const cleartextPassword = 3;

  static const cryptPassword = 4;

  static const md5Password = 5;

  static const scmCredential = 6;
}

abstract class AuthMessage {
  int get method;

  static AuthMessage parse(ReadBuffer buffer) {
    final authMethod = buffer.readInt32();

    switch (authMethod) {
      case AuthMethod.ok:
        return AuthOkMessage();
      case AuthMethod.md5Password:
        return AuthMd5PasswordMessage.parse(buffer);
      case AuthMethod.kerberosV5:
      case AuthMethod.cleartextPassword:
      case AuthMethod.cryptPassword:
      case AuthMethod.scmCredential:
        return UnsupportedAuthMessage(authMethod);
      default:
        return UnsupportedAuthMessage(authMethod);
    }
  }
}

class AuthOkMessage implements AuthMessage {
  @override
  final int method = AuthMethod.ok;
}

class AuthMd5PasswordMessage implements AuthMessage {
  @override
  final int method = AuthMethod.md5Password;

  final List<int> salt;

  AuthMd5PasswordMessage(this.salt);

  static AuthMd5PasswordMessage parse(ReadBuffer buffer) {
    final salt = buffer.readBytes(4);
    return AuthMd5PasswordMessage(salt);
  }
}

class UnsupportedAuthMessage implements AuthMessage {
  @override
  final int method;

  UnsupportedAuthMessage(this.method);
}

class UnknownAuthMessage implements AuthMessage {
  @override
  final int method;

  UnknownAuthMessage(this.method);
}
