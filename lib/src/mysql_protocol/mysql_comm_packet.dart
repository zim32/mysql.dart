import 'dart:typed_data';
import 'package:buffer/buffer.dart' show ByteDataWriter;
import 'package:mysql/src/mysql_protocol/mysql_packet.dart';

class MySQLPacketCommInitDB extends MySQLPacketPayload {
  String schemaName;

  MySQLPacketCommInitDB({
    required this.schemaName,
  });

  @override
  Uint8List encode() {
    final buffer = ByteDataWriter(endian: Endian.little);

    // command type
    buffer.writeUint8(2);
    buffer.write(schemaName.codeUnits);

    return buffer.toBytes();
  }
}

class MySQLPacketCommQuery extends MySQLPacketPayload {
  String query;

  MySQLPacketCommQuery({
    required this.query,
  });

  @override
  Uint8List encode() {
    final buffer = ByteDataWriter(endian: Endian.little);

    // command type
    buffer.writeUint8(3);
    buffer.write(query.codeUnits);

    return buffer.toBytes();
  }
}

class MySQLPacketCommQuit extends MySQLPacketPayload {
  @override
  Uint8List encode() {
    final buffer = ByteDataWriter(endian: Endian.little);

    // command type
    buffer.writeUint8(1);

    return buffer.toBytes();
  }
}
