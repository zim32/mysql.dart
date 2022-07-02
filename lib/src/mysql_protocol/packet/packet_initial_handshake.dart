import 'dart:math';
import 'dart:typed_data';
import 'package:mysql_client/mysql_protocol.dart';
import 'package:mysql_client/mysql_protocol_extension.dart';

class MySQLPacketInitialHandshake extends MySQLPacketPayload {
  int protocolVersion;
  String serverVersion;
  int connectionID;
  Uint8List authPluginDataPart1;
  int capabilityFlags;
  int charset;
  Uint8List statusFlags;
  Uint8List? authPluginDataPart2;
  String? authPluginName;

  MySQLPacketInitialHandshake({
    required this.protocolVersion,
    required this.serverVersion,
    required this.connectionID,
    required this.authPluginDataPart1,
    required this.authPluginDataPart2,
    required this.capabilityFlags,
    required this.charset,
    required this.statusFlags,
    required this.authPluginName,
  });

  factory MySQLPacketInitialHandshake.decode(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    int offset = 0;

    // protocol version
    final protocolVersion = byteData.getUint8(offset);
    offset += 1;

    // server version
    final serverVersion = buffer.getUtf8NullTerminatedString(offset);
    offset += serverVersion.item2;

    // connection id
    final connectionID = byteData.getUint32(offset, Endian.little);
    offset += 4;

    // auth-plugin-data-part-1
    final authPluginDataPart1 =
        Uint8List.sublistView(buffer, offset, offset + 8);
    offset += 9; // 8 + filler;

    // capability flags (lower 2 bytes)
    final capabilitiesBytesData = ByteData(4);
    capabilitiesBytesData.setUint8(3, buffer[offset]);
    capabilitiesBytesData.setUint8(2, buffer[offset + 1]);
    offset += 2;

    // character set
    final charset = byteData.getUint8(offset);
    offset += 1;

    final statusFlags = Uint8List.sublistView(buffer, offset, offset + 2);
    offset += 2;

    // capability flags (upper 2 bytes)
    capabilitiesBytesData.setUint8(1, buffer[offset]);
    capabilitiesBytesData.setUint8(0, buffer[offset + 1]);
    offset += 2;

    final capabilityFlags = capabilitiesBytesData.getUint32(0, Endian.big);

    // length of auth-plugin-data
    int authPluginDataLength = 0;

    if (capabilityFlags & mysqlCapFlagClientPluginAuth != 0) {
      authPluginDataLength = byteData.getUint8(offset);
    }

    offset += 1;

    // reserved
    offset += 10;

    Uint8List? authPluginDataPart2;

    if (capabilityFlags & mysqlCapFlagClientSecureConnection != 0) {
      int length = max(13, authPluginDataLength - 8);

      authPluginDataPart2 =
          Uint8List.sublistView(buffer, offset, offset + length);

      offset += length;
    }

    String? authPluginName;

    if (capabilityFlags & mysqlCapFlagClientPluginAuth != 0) {
      authPluginName = buffer.getUtf8NullTerminatedString(offset).item1;
    }

    return MySQLPacketInitialHandshake(
      authPluginDataPart1: authPluginDataPart1,
      authPluginDataPart2: authPluginDataPart2,
      authPluginName: authPluginName,
      capabilityFlags: capabilityFlags,
      charset: charset,
      connectionID: connectionID,
      protocolVersion: protocolVersion,
      serverVersion: serverVersion.item1,
      statusFlags: statusFlags,
    );
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
