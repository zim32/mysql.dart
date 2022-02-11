import 'dart:typed_data';
import 'package:buffer/buffer.dart' show ByteDataWriter;
import 'package:mysql_client/src/mysql_protocol/mysql_packet.dart';
import 'package:tuple/tuple.dart';

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

class MySQLPacketCommStmtPrepare extends MySQLPacketPayload {
  String query;

  MySQLPacketCommStmtPrepare({
    required this.query,
  });

  @override
  Uint8List encode() {
    final buffer = ByteDataWriter(endian: Endian.little);

    // command type
    buffer.writeUint8(0x16);
    buffer.write(query.codeUnits);

    return buffer.toBytes();
  }
}

class MySQLPacketCommStmtExecute extends MySQLPacketPayload {
  int stmtID;
  List<Tuple2<int, Uint8List>> params; // (type, value)

  MySQLPacketCommStmtExecute({
    required this.stmtID,
    required this.params,
  });

  @override
  Uint8List encode() {
    final buffer = ByteDataWriter(endian: Endian.little);

    // command type
    buffer.writeUint8(0x17);
    // stmt id
    buffer.writeUint32(stmtID, Endian.little);
    // flags
    buffer.writeUint8(0);
    // iteration count (always 1)
    buffer.writeUint32(1, Endian.little);

    // params
    if (params.isNotEmpty) {
      // write null-bitmap
      final bitmapSize = ((params.length + 7) / 8).floor();
      buffer.writeInt(bitmapSize, 0);

      // new-param-bound flag
      buffer.writeUint8(1);

      // write param types
      for (final param in params) {
        buffer.writeUint16(param.item1);
      }

      // write param values
      for (final param in params) {
        buffer.write(param.item2);
      }
    }

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
