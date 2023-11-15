import 'package:libpg/src/buffer/read_buffer.dart';
import 'package:libpg/src/buffer/write_buffer.dart';
import 'package:libpg/src/message/message_header.dart';
import 'package:libpg/src/message/message_type.dart';

abstract class AuthMessage {
  int get method;

  static const ok = 0;
  static const kerberosV5 = 2;
  static const cleartextPassword = 3;
  static const cryptPassword = 4;
  static const md5Password = 5;
  static const scmCredential = 6;
  static const sasl = 10;
  static const saslContinue = 11;
  static const saslFinal = 12;

  static AuthMessage parse(ReadBuffer buffer, MessageHeader header) {
    final msgType = buffer.readInt32();

    switch (msgType) {
      case ok:
        return AuthOkMessage();
      case sasl:
        return AuthSasl.parse(buffer, header);
      case saslContinue:
        return AuthSaslContinue.parse(buffer, header);
      case saslFinal:
        return AuthSaslFinal.parse(buffer, header);
      case md5Password:
        return AuthMd5PasswordMessage.parse(buffer);
      case cleartextPassword:
        return AuthCleartextPasswordMessage();
      case kerberosV5:
      case cryptPassword:
      case scmCredential:
        return UnsupportedAuthMessage(msgType);
      default:
        return UnsupportedAuthMessage(msgType);
    }
  }
}

class AuthOkMessage implements AuthMessage {
  @override
  final int method = AuthMessage.ok;
}

class AuthMd5PasswordMessage implements AuthMessage {
  @override
  final int method = AuthMessage.md5Password;

  final List<int> salt;

  AuthMd5PasswordMessage(this.salt);

  static AuthMd5PasswordMessage parse(ReadBuffer buffer) {
    final salt = buffer.readBytes(4);
    return AuthMd5PasswordMessage(salt);
  }
}

class AuthCleartextPasswordMessage implements AuthMessage {
  @override
  final int method = AuthMessage.cleartextPassword;

  AuthCleartextPasswordMessage();
}

class AuthSasl implements AuthMessage {
  @override
  final int method = AuthMessage.sasl;

  final List<int> payload;

  AuthSasl(this.payload);

  static AuthSasl parse(ReadBuffer buffer, MessageHeader header) {
    return AuthSasl(buffer.readBytes(header.length - 4));
  }
}

class AuthSaslContinue implements AuthMessage {
  @override
  final int method = AuthMessage.saslContinue;

  final List<int> payload;

  AuthSaslContinue(this.payload);

  static AuthSaslContinue parse(ReadBuffer buffer, MessageHeader header) {
    return AuthSaslContinue(buffer.readBytes(header.length - 4));
  }
}

class AuthSaslFinal implements AuthMessage {
  @override
  final int method = AuthMessage.saslFinal;

  final List<int> payload;

  AuthSaslFinal(this.payload);

  static AuthSaslFinal parse(ReadBuffer buffer, MessageHeader header) {
    return AuthSaslFinal(buffer.readBytes(header.length - 4));
  }
}

class UnsupportedAuthMessage implements AuthMessage {
  @override
  final int method;

  UnsupportedAuthMessage(this.method);
}

class SaslInitialResponse {
  final List<int> payload;
  final String mechanismName;

  SaslInitialResponse({required this.payload, required this.mechanismName});

  List<int> build() {
    final buffer = WriteBuffer();
    buffer.addByte(MessageType.password);

    final encodedMechanismName = WriteBuffer.encodeUtf8String(mechanismName);
    buffer.addInt32(4 + encodedMechanismName.length + 4 + payload.length);
    buffer.addUtf8String(mechanismName);
    buffer.addInt32(payload.length);
    buffer.addBytes(payload);

    return buffer.data;
  }
}

class SaslResponse {
  final List<int> payload;

  SaslResponse(this.payload);

  List<int> build() {
    final buffer = WriteBuffer();
    buffer.addByte(MessageType.password);
    buffer.addInt32(4 + payload.length);
    buffer.addBytes(payload);
    return buffer.data;
  }
}

class CleartextPasswordResponse {
  final String password;

  CleartextPasswordResponse(this.password);

  List<int> build() {
    final buffer = WriteBuffer();
    buffer.addByte(MessageType.password);
    final encodedPassword = WriteBuffer.encodeUtf8String(password);
    buffer.addInt32(4 + encodedPassword.length + 1);
    buffer.addUtf8String(password);
    return buffer.data;
  }
}
