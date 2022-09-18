import 'dart:typed_data';
import 'package:buffer/buffer.dart' show ByteDataWriter;
import 'package:crypto/crypto.dart' as crypto;
import 'package:mysql_client/mysql_protocol.dart';
import 'package:mysql_client/exception.dart';
import 'package:tuple/tuple.dart' show Tuple2;

const mysqlCapFlagClientLongPassword = 0x00000001;
const mysqlCapFlagClientFoundRows = 0x00000002;
const mysqlCapFlagClientLongFlag = 0x00000004;
const mysqlCapFlagClientConnectWithDB = 0x00000008;
const mysqlCapFlagClientNoSchema = 0x00000010;
const mysqlCapFlagClientCompress = 0x00000020;
const mysqlCapFlagClientODBC = 0x00000040;
const mysqlCapFlagClientLocalFiles = 0x00000080;
const mysqlCapFlagClientIgnoreSpace = 0x00000100;
const mysqlCapFlagClientProtocol41 = 0x00000200;
const mysqlCapFlagClientInteractive = 0x00000400;
const mysqlCapFlagClientSsl = 0x00000800;
const mysqlCapFlagClientIgnoreSigPipe = 0x00001000;
const mysqlCapFlagClientTransactions = 0x00002000;
const mysqlCapFlagClientReserved = 0x00004000;
const mysqlCapFlagClientSecureConnection = 0x00008000;
const mysqlCapFlagClientMultiStatements = 0x00010000;
const mysqlCapFlagClientMultiResults = 0x00020000;
const mysqlCapFlagClientPsMultiResults = 0x00040000;
const mysqlCapFlagClientPluginAuth = 0x00080000;
const mysqlCapFlagClientPluginAuthLenEncClientData = 0x00200000;
const mysqlCapFlagClientDeprecateEOF = 0x01000000;

const mysqlServerFlagMoreResultsExists = 0x0008;

enum MySQLGenericPacketType { ok, error, eof, other }

abstract class MySQLPacketPayload {
  Uint8List encode();
}

class MySQLPacket {
  int sequenceID;
  int payloadLength;
  MySQLPacketPayload payload;

  MySQLPacket({
    required this.sequenceID,
    required this.payload,
    required this.payloadLength,
  });

  static int getPacketLength(Uint8List buffer) {
    // payloadLength
    var db = ByteData(4)
      ..setUint8(0, buffer[0])
      ..setUint8(1, buffer[1])
      ..setUint8(2, buffer[2])
      ..setUint8(3, 0);

    final payloadLength = db.getUint32(0, Endian.little);

    return payloadLength + 4;
  }

  static Tuple2<int, int> decodePacketHeader(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    int offset = 0;

    // payloadLength
    var db = ByteData(4)
      ..setUint8(0, buffer[0])
      ..setUint8(1, buffer[1])
      ..setUint8(2, buffer[2])
      ..setUint8(3, 0);

    final payloadLength = db.getUint32(0, Endian.little);
    offset += 3;

    // sequence number
    final sequenceNumber = byteData.getUint8(offset);

    return Tuple2(payloadLength, sequenceNumber);
  }

  static MySQLGenericPacketType detectPacketType(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    int offset = 0;

    final header = MySQLPacket.decodePacketHeader(buffer);
    offset += 4;

    final payloadLength = header.item1;
    final type = byteData.getUint8(offset);

    if (type == 0x00 && payloadLength >= 7) {
      // OK packet
      return MySQLGenericPacketType.ok;
    } else if (type == 0xfe && payloadLength < 9) {
      // EOF packet
      return MySQLGenericPacketType.eof;
    } else if (type == 0xff) {
      return MySQLGenericPacketType.error;
    } else {
      return MySQLGenericPacketType.other;
    }
  }

  factory MySQLPacket.decodeInitialHandshake(Uint8List buffer) {
    int offset = 0;

    final header = MySQLPacket.decodePacketHeader(buffer);
    offset += 4;
    final payloadLength = header.item1;
    final sequenceNumber = header.item2;

    final payload = MySQLPacketInitialHandshake.decode(
      Uint8List.sublistView(buffer, offset),
    );

    return MySQLPacket(
      sequenceID: sequenceNumber,
      payloadLength: payloadLength,
      payload: payload,
    );
  }

  factory MySQLPacket.decodeAuthSwitchRequestPacket(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    int offset = 0;

    final header = MySQLPacket.decodePacketHeader(buffer);
    offset += 4;
    final payloadLength = header.item1;
    final sequenceNumber = header.item2;

    final type = byteData.getUint8(offset);

    if (type != 0xfe) {
      throw MySQLProtocolException(
          "Can not decode AuthSwitchResponse packet: type is not 0xfe");
    }

    final payload = MySQLPacketAuthSwitchRequest.decode(
        Uint8List.sublistView(buffer, offset));

    return MySQLPacket(
      sequenceID: sequenceNumber,
      payloadLength: payloadLength,
      payload: payload,
    );
  }

  factory MySQLPacket.decodeGenericPacket(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    int offset = 0;

    final header = MySQLPacket.decodePacketHeader(buffer);
    offset += 4;
    final payloadLength = header.item1;
    final sequenceNumber = header.item2;

    final type = byteData.getUint8(offset);

    MySQLPacketPayload payload;

    if (type == 0x00 && payloadLength >= 7) {
      // OK packet
      payload = MySQLPacketOK.decode(Uint8List.sublistView(buffer, offset));
    } else if (type == 0xfe && payloadLength < 9) {
      // EOF packet
      payload = MySQLPacketEOF.decode(Uint8List.sublistView(buffer, offset));
    } else if (type == 0xff) {
      payload = MySQLPacketError.decode(Uint8List.sublistView(buffer, offset));
    } else if (type == 0x01) {
      payload = MySQLPacketExtraAuthData.decode(
          Uint8List.sublistView(buffer, offset));
    } else {
      throw MySQLProtocolException("Unsupported generic packet: $buffer");
    }

    return MySQLPacket(
      sequenceID: sequenceNumber,
      payloadLength: payloadLength,
      payload: payload,
    );
  }

  factory MySQLPacket.decodeColumnCountPacket(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    int offset = 0;

    final header = MySQLPacket.decodePacketHeader(buffer);
    offset += 4;
    final payloadLength = header.item1;
    final sequenceNumber = header.item2;

    final type = byteData.getUint8(offset);

    MySQLPacketPayload payload;

    if (type == 0x00) {
      // OK packet
      payload = MySQLPacketOK.decode(Uint8List.sublistView(buffer, offset));
    } else if (type == 0xff) {
      payload = MySQLPacketError.decode(Uint8List.sublistView(buffer, offset));
    } else if (type == 0xfb) {
      throw MySQLProtocolException(
        "COM_QUERY_RESPONSE of type 0xfb is not implemented",
      );
    } else {
      payload =
          MySQLPacketColumnCount.decode(Uint8List.sublistView(buffer, offset));
    }

    return MySQLPacket(
      sequenceID: sequenceNumber,
      payloadLength: payloadLength,
      payload: payload,
    );
  }

  factory MySQLPacket.decodeColumnDefPacket(Uint8List buffer) {
    int offset = 0;

    final header = MySQLPacket.decodePacketHeader(buffer);
    offset += 4;
    final payloadLength = header.item1;
    final sequenceNumber = header.item2;

    final payload = MySQLColumnDefinitionPacket.decode(
      Uint8List.sublistView(buffer, offset),
    );

    return MySQLPacket(
      sequenceID: sequenceNumber,
      payloadLength: payloadLength,
      payload: payload,
    );
  }

  factory MySQLPacket.decodeResultSetRowPacket(
    Uint8List buffer,
    int numOfCols,
  ) {
    int offset = 0;

    final header = MySQLPacket.decodePacketHeader(buffer);
    offset += 4;
    final payloadLength = header.item1;
    final sequenceNumber = header.item2;

    final payload = MySQLResultSetRowPacket.decode(
      Uint8List.sublistView(buffer, offset),
      numOfCols,
    );

    return MySQLPacket(
      sequenceID: sequenceNumber,
      payloadLength: payloadLength,
      payload: payload,
    );
  }

  factory MySQLPacket.decodeBinaryResultSetRowPacket(
    Uint8List buffer,
    List<MySQLColumnDefinitionPacket> colDefs,
  ) {
    int offset = 0;

    final header = MySQLPacket.decodePacketHeader(buffer);
    offset += 4;
    final payloadLength = header.item1;
    final sequenceNumber = header.item2;

    final payload = MySQLBinaryResultSetRowPacket.decode(
      Uint8List.sublistView(buffer, offset),
      colDefs,
    );

    return MySQLPacket(
      sequenceID: sequenceNumber,
      payloadLength: payloadLength,
      payload: payload,
    );
  }

  factory MySQLPacket.decodeCommPrepareStmtResponsePacket(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    int offset = 0;

    final header = MySQLPacket.decodePacketHeader(buffer);
    offset += 4;
    final payloadLength = header.item1;
    final sequenceNumber = header.item2;

    final type = byteData.getUint8(offset);

    MySQLPacketPayload payload;

    if (type == 0x00) {
      // OK packet
      payload = MySQLPacketStmtPrepareOK.decode(
        Uint8List.sublistView(buffer, offset),
      );
    } else if (type == 0xff) {
      payload = MySQLPacketError.decode(Uint8List.sublistView(buffer, offset));
    } else {
      throw MySQLProtocolException(
        "Unexpected header type while decoding COM_STMT_PREPARE response: $header",
      );
    }

    return MySQLPacket(
      sequenceID: sequenceNumber,
      payloadLength: payloadLength,
      payload: payload,
    );
  }

  bool isOkPacket() {
    final _payload = payload;

    return _payload is MySQLPacketOK;
  }

  bool isErrorPacket() {
    final _payload = payload;
    return _payload is MySQLPacketError;
  }

  bool isEOFPacket() {
    final _payload = payload;

    if (_payload is MySQLPacketEOF) {
      return true;
    }

    return _payload is MySQLPacketOK &&
        _payload.header == 0xfe &&
        payloadLength < 9;
  }

  Uint8List encode() {
    final payloadData = payload.encode();

    final byteData = ByteData(4);
    byteData.setInt32(0, payloadData.lengthInBytes, Endian.little);
    byteData.setInt8(3, sequenceID);

    final buffer = ByteDataWriter(endian: Endian.little);
    buffer.write(byteData.buffer.asUint8List());
    buffer.write(payloadData);

    return buffer.toBytes();
  }
}

List<int> sha1(List<int> data) {
  return crypto.sha1.convert(data).bytes;
}

List<int> sha256(List<int> data) {
  return crypto.sha256.convert(data).bytes;
}

Uint8List xor(List<int> aList, List<int> bList) {
  final a = Uint8List.fromList(aList);
  final b = Uint8List.fromList(bList);

  if (a.lengthInBytes == 0 || b.lengthInBytes == 0) {
    throw ArgumentError.value(
        "lengthInBytes of Uint8List arguments must be > 0");
  }

  bool aIsBigger = a.lengthInBytes > b.lengthInBytes;
  int length = aIsBigger ? a.lengthInBytes : b.lengthInBytes;

  Uint8List buffer = Uint8List(length);

  for (int i = 0; i < length; i++) {
    int aa, bb;
    try {
      aa = a.elementAt(i);
    } catch (e) {
      aa = 0;
    }
    try {
      bb = b.elementAt(i);
    } catch (e) {
      bb = 0;
    }

    buffer[i] = aa ^ bb;
  }

  return buffer;
}
