import 'dart:math';
import 'dart:typed_data';
import 'package:buffer/buffer.dart' show ByteDataWriter;
import 'package:crypto/crypto.dart' as crypto;
import 'package:mysql_client/mysql_protocol.dart';
import 'package:tuple/tuple.dart' show Tuple2;
import 'package:mysql_client/mysql_protocol_extension.dart';

const mysqlCapFlagClientLongPassword = 0x1;
const mysqlCapFlagClientFoundRows = 0x2;
const mysqlCapFlagClientLongFlag = 0x4;
const mysqlCapFlagClientConnectWithDB = 0x8;
const mysqlCapFlagClientNoSchema = 0x10;
const mysqlCapFlagClientCompress = 0x20;
const mysqlCapFlagClientODBC = 0x40;
const mysqlCapFlagClientLocalFiles = 0x80;
const mysqlCapFlagClientIgnoreSpace = 0x100;
const mysqlCapFlagClientProtocol41 = 0x200;
const mysqlCapFlagClientInteractive = 0x400;
const mysqlCapFlagClientSsl = 0x800;
const mysqlCapFlagClientIgnoreSigPipe = 0x1000;
const mysqlCapFlagClientTransactions = 0x2000;
const mysqlCapFlagClientReserved = 0x4000;
const mysqlCapFlagClientSecureConnection = 0x8000;
const mysqlCapFlagClientMultiStatements = 0x10000;
const mysqlCapFlagClientMultiResults = 0x20000;
const mysqlCapFlagClientPsMultiResults = 0x40000;
const mysqlCapFlagClientPluginAuth = 0x80000;
const mysqlCapFlagClientPluginAuthLenEncClientData = 0x200000;
const mysqlCapFlagClientDeprecateEOF = 0x1000000;

class MySQLPacket {
  int sequenceID;
  int payloadLength;
  MySQLPacketPayload payload;

  MySQLPacket({
    required this.sequenceID,
    required this.payload,
    required this.payloadLength,
  });

  factory MySQLPacket.decodeInitialHandshake(Uint8List buffer) {
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
    offset += 1;

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
    offset += 1;

    final header = byteData.getUint8(offset);

    if (header != 0xfe) {
      throw Exception(
          "Can not decode AuthSwitchResponse packet: header is not 0xfe");
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
    offset += 1;

    final header = byteData.getUint8(offset);

    MySQLPacketPayload payload;

    if (header == 0x00 && payloadLength >= 7) {
      // OK packet
      payload = MySQLPacketOK.decode(Uint8List.sublistView(buffer, offset));
    } else if (header == 0xfe && payloadLength < 9) {
      // EOF packet
      payload = MySQLPacketOK.decode(Uint8List.sublistView(buffer, offset));
    } else if (header == 0xff) {
      payload = MySQLPacketError.decode(Uint8List.sublistView(buffer, offset));
    } else {
      throw Exception("Unsupported generic packet: $buffer");
    }

    return MySQLPacket(
      sequenceID: sequenceNumber,
      payloadLength: payloadLength,
      payload: payload,
    );
  }

  factory MySQLPacket.decodeCommQueryResponsePacket(Uint8List buffer) {
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
    offset += 1;

    final header = byteData.getUint8(offset);

    MySQLPacketPayload payload;

    if (header == 0x00) {
      // OK packet
      payload = MySQLPacketOK.decode(Uint8List.sublistView(buffer, offset));
    } else if (header == 0xff) {
      payload = MySQLPacketError.decode(Uint8List.sublistView(buffer, offset));
    } else if (header == 0xfb) {
      throw UnimplementedError(
        "COM_QUERY_RESPONSE of type 0xfb is not implemented",
      );
    } else {
      payload =
          MySQLPacketResultSet.decode(Uint8List.sublistView(buffer, offset));
    }

    return MySQLPacket(
      sequenceID: sequenceNumber,
      payloadLength: payloadLength,
      payload: payload,
    );
  }

  factory MySQLPacket.decodeCommPrepareStmtResponsePacket(Uint8List buffer) {
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
    offset += 1;

    final header = byteData.getUint8(offset);

    MySQLPacketPayload payload;

    if (header == 0x00) {
      // OK packet
      payload = MySQLPacketStmtPrepareOK.decode(
        Uint8List.sublistView(buffer, offset),
      );
    } else if (header == 0xff) {
      payload = MySQLPacketError.decode(Uint8List.sublistView(buffer, offset));
    } else {
      throw Exception(
        "Unexpected header type while decoding COM_STMT_PREPARE response: $header",
      );
    }

    return MySQLPacket(
      sequenceID: sequenceNumber,
      payloadLength: payloadLength,
      payload: payload,
    );
  }

  factory MySQLPacket.decodeCommPrepareStmtExecResponsePacket(
      Uint8List buffer) {
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
    offset += 1;

    final header = byteData.getUint8(offset);

    MySQLPacketPayload payload;

    if (header == 0x00) {
      // OK packet
      payload = MySQLPacketOK.decode(Uint8List.sublistView(buffer, offset));
    } else if (header == 0xff) {
      payload = MySQLPacketError.decode(Uint8List.sublistView(buffer, offset));
    } else if (header == 0xfb) {
      throw UnimplementedError(
        "COM_QUERY_RESPONSE of type 0xfb is not implemented",
      );
    } else {
      payload = MySQLPacketBinaryResultSet.decode(
        Uint8List.sublistView(buffer, offset),
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

abstract class MySQLPacketPayload {
  Uint8List encode();
}

class MySQLPacketOK extends MySQLPacketPayload {
  int header;
  BigInt affectedRows;
  BigInt lastInsertID;

  MySQLPacketOK({
    required this.header,
    required this.affectedRows,
    required this.lastInsertID,
  });

  factory MySQLPacketOK.decode(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    int offset = 0;

    final header = byteData.getUint8(offset);
    offset += 1;

    final affectedRows = byteData.getVariableEncInt(offset);
    offset += affectedRows.item2;

    final lastInsertID = byteData.getVariableEncInt(offset);
    offset += lastInsertID.item2;

    return MySQLPacketOK(
      header: header,
      affectedRows: affectedRows.item1,
      lastInsertID: lastInsertID.item1,
    );
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}

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
    final errorMessage = buffer.getStringEOF(offset);

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

    final authPluginName = buffer.getNullTerminatedString(offset);
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
    final serverVersion = buffer.getNullTerminatedString(offset);
    offset += serverVersion.length + 1;

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

    final capabilityFlags = capabilitiesBytesData.getUint32(0, Endian.little);

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
      authPluginName = buffer.getNullTerminatedString(offset);
    }

    return MySQLPacketInitialHandshake(
      authPluginDataPart1: authPluginDataPart1,
      authPluginDataPart2: authPluginDataPart2,
      authPluginName: authPluginName,
      capabilityFlags: capabilityFlags,
      charset: charset,
      connectionID: connectionID,
      protocolVersion: protocolVersion,
      serverVersion: serverVersion,
      statusFlags: statusFlags,
    );
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}

List<int> sha1(List<int> data) {
  return crypto.sha1.convert(data).bytes;
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
      buffer.writeUint8(20);
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
    final passwordBytes = password.codeUnits;

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
      capabilityFlags: mysqlCapFlagClientProtocol41 |
          mysqlCapFlagClientSecureConnection |
          mysqlCapFlagClientPluginAuth |
          mysqlCapFlagClientPluginAuthLenEncClientData |
          mysqlCapFlagClientSsl,
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

class MySQLPacketResultSet extends MySQLPacketPayload {
  BigInt columnCount;
  List<MySQLColumnDefinitionPacket> columns;
  List<MySQLResultSetRowPacket> rows;

  MySQLPacketResultSet({
    required this.columnCount,
    required this.columns,
    required this.rows,
  });

  factory MySQLPacketResultSet.decode(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    int offset = 0;

    final columnCount = byteData.getVariableEncInt(offset);
    offset += columnCount.item2;

    List<MySQLColumnDefinitionPacket> colDefList = [];

    // parse column definitions
    for (int x = 0; x < columnCount.item1.toInt(); x++) {
      final packet = MySQLColumnDefinitionPacket.decode(
        Uint8List.sublistView(buffer, offset),
      );

      colDefList.add(packet);
      offset += packet.packetLength + 4; // packet header + packet length
    }

    // EOF packet
    var eofPacket = MySQLPacket.decodeGenericPacket(
      Uint8List.sublistView(buffer, offset),
    );
    offset += eofPacket.payloadLength + 4;

    List<MySQLResultSetRowPacket> rows = [];

    // parse result set rows
    while (true) {
      // we need to check next packet length and header to find out if it's OK(EOF) packet or result set row packet
      var db = ByteData(4)
        ..setUint8(0, buffer[offset])
        ..setUint8(1, buffer[offset + 1])
        ..setUint8(2, buffer[offset + 2])
        ..setUint8(3, 0);

      final nextPacketLength = db.getUint32(0, Endian.little);
      final nextPacketHeader = byteData.getUint8(offset + 4);

      if ((nextPacketHeader == 0xfe && nextPacketLength < 9) ||
          (nextPacketHeader == 0x00 && nextPacketLength > 7)) {
        // this is OK(EOF) packet
        break;
      } else {
        // this is result set row packet
        final resultSetRowPacket = MySQLResultSetRowPacket.decode(
          Uint8List.sublistView(buffer, offset),
          columnCount.item1.toInt(),
        );

        rows.add(resultSetRowPacket);
        offset += resultSetRowPacket.packetLength + 4;
      }
    }

    return MySQLPacketResultSet(
      columnCount: columnCount.item1,
      columns: colDefList,
      rows: rows,
    );
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}

class MySQLPacketBinaryResultSet extends MySQLPacketPayload {
  BigInt columnCount;
  List<MySQLColumnDefinitionPacket> columns;
  List<MySQLBinaryResultSetRowPacket> rows;

  MySQLPacketBinaryResultSet({
    required this.columnCount,
    required this.columns,
    required this.rows,
  });

  factory MySQLPacketBinaryResultSet.decode(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    int offset = 0;

    final columnCount = byteData.getVariableEncInt(offset);
    offset += columnCount.item2;

    List<MySQLColumnDefinitionPacket> colDefList = [];

    // parse column definitions
    for (int x = 0; x < columnCount.item1.toInt(); x++) {
      final packet = MySQLColumnDefinitionPacket.decode(
        Uint8List.sublistView(buffer, offset),
      );

      colDefList.add(packet);
      offset += packet.packetLength + 4; // packet header + packet length
    }

    // EOF packet
    var eofPacket = MySQLPacket.decodeGenericPacket(
      Uint8List.sublistView(buffer, offset),
    );
    offset += eofPacket.payloadLength + 4;

    List<MySQLBinaryResultSetRowPacket> rows = [];

    // parse result set rows
    while (true) {
      // we need to check next packet length and header to find out if it's EOF packet or binary result set row packet
      var db = ByteData(4)
        ..setUint8(0, buffer[offset])
        ..setUint8(1, buffer[offset + 1])
        ..setUint8(2, buffer[offset + 2])
        ..setUint8(3, 0);

      final nextPacketLength = db.getUint32(0, Endian.little);
      final nextPacketHeader = byteData.getUint8(offset + 4);

      if (nextPacketHeader == 0xfe && nextPacketLength < 9) {
        // this is OK(EOF) packet
        break;
      } else {
        // this is result set row packet
        final resultSetRowPacket = MySQLBinaryResultSetRowPacket.decode(
          Uint8List.sublistView(buffer, offset),
          colDefList,
        );

        rows.add(resultSetRowPacket);
        offset += resultSetRowPacket.packetLength + 4;
      }
    }

    return MySQLPacketBinaryResultSet(
      columnCount: columnCount.item1,
      columns: colDefList,
      rows: rows,
    );
  }

  @override
  Uint8List encode() {
    throw UnimplementedError();
  }
}

class MySQLColumnDefinitionPacket {
  int sequenceID;
  int packetLength;
  String catalog;
  String schema;
  String table;
  String orgTable;
  String name;
  String orgName;
  int charset;
  int columnLength;
  int type;

  MySQLColumnDefinitionPacket({
    required this.sequenceID,
    required this.packetLength,
    required this.catalog,
    required this.schema,
    required this.table,
    required this.orgTable,
    required this.name,
    required this.orgName,
    required this.charset,
    required this.columnLength,
    required this.type,
  });

  factory MySQLColumnDefinitionPacket.decode(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);
    int offset = 0;

    // packet length
    var db = ByteData(4)
      ..setUint8(0, buffer[0])
      ..setUint8(1, buffer[1])
      ..setUint8(2, buffer[2])
      ..setUint8(3, 0);

    final packetLength = db.getUint32(0, Endian.little);
    offset += 3;

    // sequence number
    final sequenceNumber = byteData.getUint8(offset);
    offset += 1;

    final catalog = buffer.getLengthEncodedString(offset);
    offset += catalog.item2;

    final schema = buffer.getLengthEncodedString(offset);
    offset += schema.item2;

    final table = buffer.getLengthEncodedString(offset);
    offset += table.item2;

    final orgTable = buffer.getLengthEncodedString(offset);
    offset += orgTable.item2;

    final name = buffer.getLengthEncodedString(offset);
    offset += name.item2;

    final orgName = buffer.getLengthEncodedString(offset);
    offset += orgName.item2;

    final lengthOfFixedLengthFields = byteData.getVariableEncInt(offset);
    offset += lengthOfFixedLengthFields.item2;

    final charset = byteData.getUint16(offset, Endian.little);
    offset += 2;

    final columnLength = byteData.getUint32(offset, Endian.little);
    offset += 4;

    final type = byteData.getUint8(offset);
    offset += 1;

    return MySQLColumnDefinitionPacket(
      catalog: catalog.item1,
      charset: charset,
      columnLength: columnLength,
      name: name.item1,
      orgName: orgName.item1,
      orgTable: orgTable.item1,
      packetLength: packetLength,
      schema: schema.item1,
      sequenceID: sequenceNumber,
      table: table.item1,
      type: type,
    );
  }
}

class MySQLResultSetRowPacket {
  int packetLength;
  int sequenceID;
  List<String?> values;

  MySQLResultSetRowPacket({
    required this.packetLength,
    required this.sequenceID,
    required this.values,
  });

  factory MySQLResultSetRowPacket.decode(Uint8List buffer, int numOfCols) {
    final byteData = ByteData.sublistView(buffer);
    int offset = 0;

    // packet length
    var db = ByteData(4)
      ..setUint8(0, buffer[0])
      ..setUint8(1, buffer[1])
      ..setUint8(2, buffer[2])
      ..setUint8(3, 0);

    final packetLength = db.getUint32(0, Endian.little);
    offset += 3;

    // sequence number
    final sequenceNumber = byteData.getUint8(offset);
    offset += 1;

    List<String?> values = [];

    for (int x = 0; x < numOfCols; x++) {
      Tuple2<String, int> value;
      final nextByte = byteData.getUint8(offset);

      if (nextByte == 0xfb) {
        values.add(null);
        offset += 1;
      } else {
        value = buffer.getLengthEncodedString(offset);
        values.add(value.item1);
        offset += value.item2;
      }
    }

    return MySQLResultSetRowPacket(
      packetLength: packetLength,
      sequenceID: sequenceNumber,
      values: values,
    );
  }
}

class MySQLBinaryResultSetRowPacket {
  int packetLength;
  int sequenceID;
  List<String?> values;

  MySQLBinaryResultSetRowPacket({
    required this.packetLength,
    required this.sequenceID,
    required this.values,
  });

  factory MySQLBinaryResultSetRowPacket.decode(
    Uint8List buffer,
    List<MySQLColumnDefinitionPacket> colDefs,
  ) {
    final byteData = ByteData.sublistView(buffer);
    int offset = 0;

    // packet length
    var db = ByteData(4)
      ..setUint8(0, buffer[0])
      ..setUint8(1, buffer[1])
      ..setUint8(2, buffer[2])
      ..setUint8(3, 0);

    final packetLength = db.getUint32(0, Endian.little);
    offset += 3;

    // sequence number
    final sequenceNumber = byteData.getUint8(offset);
    offset += 1;

    // packet header (always should by 0x00)
    offset += 1;

    List<String?> values = [];

    // parse null bitmap
    int nullBitmapSize = ((colDefs.length + 9) / 8).floor();

    final nullBitmap = Uint8List.sublistView(
      buffer,
      offset,
      offset + nullBitmapSize,
    );

    offset += nullBitmapSize;

    // parse binary data
    for (int x = 0; x < colDefs.length; x++) {
      // check null bitmap first
      final bitmapByteIndex = ((x + 2) / 8).floor();
      final bitmapBitIndex = (x + 2) % 8;

      final byteToCheck = nullBitmap[bitmapByteIndex];
      final isNull = (byteToCheck & (1 << bitmapBitIndex)) != 0;

      if (isNull) {
        values.add(null);
      } else {
        final parseResult = parseBinaryColumnData(
          colDefs[x].type,
          byteData,
          buffer,
          offset,
        );
        offset += parseResult.item2;
        values.add(parseResult.item1);
      }
    }

    return MySQLBinaryResultSetRowPacket(
      packetLength: packetLength,
      sequenceID: sequenceNumber,
      values: values,
    );
  }
}
