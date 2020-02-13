import 'package:libpg/src/buffer/read_buffer.dart';

class BackendKeyData {
  final int pid;

  final int secretKey;

  BackendKeyData(this.pid, this.secretKey);

  static BackendKeyData parse(ReadBuffer buffer) {
    final pid = buffer.readInt32();
    final secretKey = buffer.readInt32();

    return BackendKeyData(pid, secretKey);
  }
}
