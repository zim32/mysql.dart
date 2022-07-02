import 'dart:typed_data';
import 'package:mysql_client/mysql_protocol.dart';
import 'package:mysql_client/mysql_protocol_extension.dart';

class MySQLPacketError extends MySQLPacketPayload {
  int header;
  int errorCode;
  String errorMessage;

  MySQLPacketError({
    required this.header,
    required this.errorCode,
    required this.errorMessage,
  });

  factory MySQLPacketError.decode(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);

    int offset = 0;

    final header = byteData.getUint8(offset);
    offset += 1;

    final errorCode = byteData.getInt2(offset);
    offset += 2;

    // skip sql_state_marker and sql_state
    offset += 6;

    // error message
    final errorMessage = buffer.getUtf8StringEOF(offset);

    return MySQLPacketError(
      header: header,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
