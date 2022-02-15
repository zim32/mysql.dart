import 'dart:convert';
import 'dart:typed_data';
import 'package:buffer/buffer.dart';
import 'package:mysql_client/mysql_protocol.dart';

class MySQLPacketAuthSwitchResponse extends MySQLPacketPayload {
  Uint8List authData;

  MySQLPacketAuthSwitchResponse({
    required this.authData,
  });

  factory MySQLPacketAuthSwitchResponse.createWithNativePassword({
    required String password,
    required Uint8List challenge,
  }) {
    assert(challenge.length == 20);
    final passwordBytes = utf8.encode(password);

    final authData =
        xor(sha1(passwordBytes), sha1(challenge + sha1(sha1(passwordBytes))));

    return MySQLPacketAuthSwitchResponse(
      authData: authData,
    );
  }

  @override
  Uint8List encode() {
    final buffer = ByteDataWriter(endian: Endian.little);
    buffer.write(authData);

    return buffer.toBytes();
  }
}
