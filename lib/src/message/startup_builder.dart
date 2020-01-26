import 'package:libpg/src/buffer/write_buffer.dart';

class StartupMessageBuilder {
  final int protocolVersion;

  final String username;

  final String databaseName;

  final String timezone;

  final String applicationName;

  StartupMessageBuilder(
      {this.protocolVersion,
      this.username,
      this.databaseName,
      this.timezone,
      this.applicationName});

  List<int> build() {
    final buffer = WriteBuffer();

    buffer.addInt32(0); // Length padding.
    buffer.addInt32(protocolVersion);
    buffer.addUtf8String('user');
    buffer.addUtf8String(username);
    buffer.addUtf8String('database');
    buffer.addUtf8String(databaseName);
    buffer.addUtf8String('client_encoding');
    buffer.addUtf8String('UTF8');
    if (timezone != null) {
      buffer.addUtf8String('TimeZone');
      buffer.addUtf8String(timezone);
    }
    if (applicationName != null) {
      buffer.addUtf8String('application_name');
      buffer.addUtf8String(applicationName);
    }
    buffer.addByte(0);
    buffer.setLength(startup: true);

    return buffer.data;
  }
}
