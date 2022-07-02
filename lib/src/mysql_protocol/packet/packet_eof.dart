import 'dart:typed_data';
import 'package:mysql_client/mysql_protocol.dart';

class MySQLPacketEOF extends MySQLPacketPayload {
  int header;
  int statusFlags;

  MySQLPacketEOF({
    required this.header,
    required this.statusFlags,
  });

  factory MySQLPacketEOF.decode(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    int offset = 0;

    final header = byteData.getUint8(offset);
    offset += 1;

    // skip warnings count
    offset += 2;

    final statusFlags = byteData.getUint16(offset, Endian.little);
    offset += 2;

    return MySQLPacketEOF(header: header, statusFlags: statusFlags);
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
