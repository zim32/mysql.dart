import 'dart:typed_data';
import 'package:buffer/buffer.dart';
import 'package:mysql_client/mysql_protocol.dart';
import 'package:mysql_client/mysql_protocol_extension.dart';

class MySQLPacketHandshakeResponse41 extends MySQLPacketPayload {
  int capabilityFlags;
  int maxPacketSize;
  int characterSet;
  Uint8List authResponse;
  String authPluginName;
  String username;
  String? database;

  MySQLPacketHandshakeResponse41({
    required this.capabilityFlags,
    required this.maxPacketSize,
    required this.characterSet,
    required this.authResponse,
    required this.authPluginName,
    required this.username,
    this.database,
  });

  factory MySQLPacketHandshakeResponse41.createWithNativePassword({
    required String username,
    required String password,
    required MySQLPacketInitialHandshake initialHandshakePayload,
  }) {
    assert(initialHandshakePayload.authPluginDataPart2 != null);
    assert(initialHandshakePayload.authPluginName != null);

    final challenge = initialHandshakePayload.authPluginDataPart1 +
        initialHandshakePayload.authPluginDataPart2!.sublist(0, 12);

    assert(challenge.length == 20);

    final passwordBytes = password.codeUnits;

    final authData = xor(
      sha1(passwordBytes),
      sha1(challenge + sha1(sha1(passwordBytes))),
    );

    return MySQLPacketHandshakeResponse41(
      capabilityFlags: mysqlCapFlagClientProtocol41 |
          mysqlCapFlagClientSecureConnection |
          mysqlCapFlagClientPluginAuth |
          mysqlCapFlagClientPluginAuthLenEncClientData,
      maxPacketSize: 50 * 1024 * 1024,
      authPluginName: initialHandshakePayload.authPluginName!,
      characterSet: initialHandshakePayload.charset,
      authResponse: authData,
      username: username,
    );
  }

  factory MySQLPacketHandshakeResponse41.createWithCachingSha2Password({
    required String username,
    required String password,
    required MySQLPacketInitialHandshake initialHandshakePayload,
  }) {
    final challenge = initialHandshakePayload.authPluginDataPart1 +
        initialHandshakePayload.authPluginDataPart2!.sublist(0, 12);

    assert(challenge.length == 20);

    final passwordBytes = password.codeUnits;

    final authData = xor(
      sha256(passwordBytes),
      sha256(sha256(sha256(passwordBytes)) + challenge),
    );

    return MySQLPacketHandshakeResponse41(
      capabilityFlags: mysqlCapFlagClientProtocol41 |
          mysqlCapFlagClientSecureConnection |
          mysqlCapFlagClientPluginAuth |
          mysqlCapFlagClientPluginAuthLenEncClientData,
      maxPacketSize: 50 * 1024 * 1024,
      authPluginName: initialHandshakePayload.authPluginName!,
      characterSet: initialHandshakePayload.charset,
      authResponse: authData,
      username: username,
    );
  }

  @override
  Uint8List encode() {
    final buffer = ByteDataWriter(endian: Endian.little);

    if (database != null) {
      capabilityFlags = capabilityFlags | mysqlCapFlagClientConnectWithDB;
    }

    buffer.writeUint32(capabilityFlags);
    buffer.writeUint32(maxPacketSize);
    buffer.writeUint8(characterSet);
    buffer.write(List.filled(23, 0));
    buffer.write(username.codeUnits);
    buffer.writeUint8(0);

    if (capabilityFlags & mysqlCapFlagClientSecureConnection != 0) {
      buffer.writeVariableEncInt(authResponse.lengthInBytes);
      buffer.write(authResponse);
    }

    if (database != null &&
        capabilityFlags & mysqlCapFlagClientConnectWithDB != 0) {
      buffer.write(database!.codeUnits);
      buffer.writeUint8(0);
    }

    if (capabilityFlags & mysqlCapFlagClientPluginAuth != 0) {
      buffer.write(authPluginName.codeUnits);
      buffer.writeUint8(0);
    }

    return buffer.toBytes();
  }
}
