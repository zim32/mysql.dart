import 'dart:typed_data';
import 'package:mysql_client/mysql_protocol.dart';

class MySQLPacketStmtPrepareOK extends MySQLPacketPayload {
  int header;
  int stmtID;
  int numOfCols;
  int numOfParams;
  int numOfWarnings;

  MySQLPacketStmtPrepareOK({
    required this.header,
    required this.stmtID,
    required this.numOfCols,
    required this.numOfParams,
    required this.numOfWarnings,
  });

  factory MySQLPacketStmtPrepareOK.decode(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    int offset = 0;

    final header = byteData.getUint8(offset);
    offset += 1;

    final statementID = byteData.getUint32(offset, Endian.little);
    offset += 4;

    final numColumns = byteData.getUint16(offset, Endian.little);
    offset += 2;

    final numParams = byteData.getUint16(offset, Endian.little);
    offset += 2;

    // filler
    offset += 1;

    final numWarnings = byteData.getUint16(offset, Endian.little);
    offset += 2;

    return MySQLPacketStmtPrepareOK(
      header: header,
      stmtID: statementID,
      numOfCols: numColumns,
      numOfParams: numParams,
      numOfWarnings: numWarnings,
    );
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}
