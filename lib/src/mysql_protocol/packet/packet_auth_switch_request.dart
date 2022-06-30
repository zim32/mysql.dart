import 'dart:typed_data';
import 'package:mysql_client/mysql_protocol.dart';
import 'package:mysql_client/mysql_protocol_extension.dart';

class MySQLPacketAuthSwitchRequest extends MySQLPacketPayload {
  int header;
  String authPluginName;
  Uint8List authPluginData;

  MySQLPacketAuthSwitchRequest({
    required this.header,
    required this.authPluginData,
    required this.authPluginName,
  });

  factory MySQLPacketAuthSwitchRequest.decode(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);

    int offset = 0;

    final header = byteData.getUint8(offset);
    offset += 1;

    final authPluginName = buffer.getAsciNullTerminatedString(offset);
    offset += authPluginName.length + 1;

    final authPluginData = Uint8List.sublistView(buffer, offset);

    return MySQLPacketAuthSwitchRequest(
      header: header,
      authPluginData: authPluginData,
      authPluginName: authPluginName,
    );
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
