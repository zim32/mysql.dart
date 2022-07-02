import 'dart:typed_data';
import 'package:buffer/buffer.dart';
import 'package:mysql_client/mysql_protocol.dart';

const _supportedCapabitilies = mysqlCapFlagClientProtocol41 |
    mysqlCapFlagClientSecureConnection |
    mysqlCapFlagClientPluginAuth |
    mysqlCapFlagClientPluginAuthLenEncClientData |
    mysqlCapFlagClientMultiStatements |
    mysqlCapFlagClientMultiResults |
    mysqlCapFlagClientSsl;

class MySQLPacketSSLRequest extends MySQLPacketPayload {
  int capabilityFlags;
  int maxPacketSize;
  int characterSet;
  bool connectWithDB;

  MySQLPacketSSLRequest._({
    required this.capabilityFlags,
    required this.maxPacketSize,
    required this.characterSet,
    required this.connectWithDB,
  });

  factory MySQLPacketSSLRequest.createDefault({
    required MySQLPacketInitialHandshake initialHandshakePayload,
    required bool connectWithDB,
  }) {
    return MySQLPacketSSLRequest._(
      capabilityFlags: _supportedCapabitilies,
      maxPacketSize: 50 * 1024 * 1024,
      characterSet: initialHandshakePayload.charset,
      connectWithDB: connectWithDB,
    );
  }

  @override
  Uint8List encode() {
    if (connectWithDB) {
      capabilityFlags = capabilityFlags | mysqlCapFlagClientConnectWithDB;
    }

    final buffer = ByteDataWriter(endian: Endian.little);

    buffer.writeUint32(capabilityFlags);
    buffer.writeUint32(maxPacketSize);
    buffer.writeUint8(characterSet);
    buffer.write(List.filled(23, 0));

    return buffer.toBytes();
  }
}
