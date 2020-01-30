import 'package:libpg/src/buffer/read_buffer.dart';

class AuthMethod {
  // static const error = 0;

  static const ok = 0;

  static const kerberosV5 = 2;

  static const cleartextPassword = 3;

  static const cryptPassword = 4;

  static const md5Password = 5;

  static const scmCredential = 6;
}

abstract class AuthMessageParser {
  int get method;

  static AuthMessageParser parse(ReadBuffer buffer) {
    final authMethod = buffer.readInt32();

    switch (authMethod) {
      // TODO case AuthMethod.error:
      //   return AuthErrorMessage();
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

/*
class AuthErrorMessage implements AuthMessageParser {
  @override
  final int method = AuthMethod.error;
}*/

class AuthOkMessage implements AuthMessageParser {
  @override
  final int method = AuthMethod.ok;
}

class AuthMd5PasswordMessage implements AuthMessageParser {
  @override
  final int method = AuthMethod.md5Password;

  final List<int> salt;

  AuthMd5PasswordMessage(this.salt);

  static AuthMd5PasswordMessage parse(ReadBuffer buffer) {
    final salt = buffer.readBytes(4);
    return AuthMd5PasswordMessage(salt);
  }
}

class UnsupportedAuthMessage implements AuthMessageParser {
  @override
  final int method;

  UnsupportedAuthMessage(this.method);
}

class UnknownAuthMessage implements AuthMessageParser {
  @override
  final int method;

  UnknownAuthMessage(this.method);
}
