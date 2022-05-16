import 'dart:convert';
import 'dart:typed_data';
import 'package:buffer/buffer.dart' show ByteDataWriter;
import 'package:mysql_client/mysql_protocol.dart';
import 'package:mysql_client/mysql_protocol_extension.dart';

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
    buffer.write(utf8.encode(schemaName));

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
    buffer.write(utf8.encode(query));

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
    buffer.write(utf8.encode(query));

    return buffer.toBytes();
  }
}

class MySQLPacketCommStmtExecute extends MySQLPacketPayload {
  int stmtID;
  List<dynamic> params; // (type, value)

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
      // create null-bitmap
      final bitmapSize = ((params.length + 7) / 8).floor();
      final nullBitmap = Uint8List(bitmapSize);

      // write null values into null bitmap
      int paramIndex = 0;
      for (final param in params) {
        if (param == null) {
          final paramByteIndex = ((paramIndex) / 8).floor();
          final paramBitIndex = ((paramIndex) % 8);
          nullBitmap[paramByteIndex] =
              nullBitmap[paramByteIndex] | (1 << paramBitIndex);
        }
        paramIndex++;
      }

      // write null bitmap
      buffer.write(nullBitmap);

      // write new-param-bound flag
      buffer.writeUint8(1);

      // write not null values

      // write param types
      for (final param in params) {
        if (param != null) {
          buffer.writeUint8(mysqlColumnTypeVarString);
          // unsigned flag
          buffer.writeUint8(0);
        } else {
          buffer.writeUint8(mysqlColumnTypeNull);
          buffer.writeUint8(0);
        }
      }
      // write param values
      for (final param in params) {
        if (param != null) {
          final String value = param.toString();
          final encodedData = utf8.encode(value);
          buffer.writeVariableEncInt(encodedData.length);
          buffer.write(encodedData);
        }
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

class MySQLPacketCommStmtClose extends MySQLPacketPayload {
  int stmtID;

  MySQLPacketCommStmtClose({
    required this.stmtID,
  });

  @override
  Uint8List encode() {
    final buffer = ByteDataWriter(endian: Endian.little);

    // command type
    buffer.writeUint8(0x19);
    buffer.writeUint32(stmtID);

    return buffer.toBytes();
  }
}
