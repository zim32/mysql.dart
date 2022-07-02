import 'dart:convert';
import 'dart:typed_data';
import 'package:buffer/buffer.dart';
import 'package:mysql_client/exception.dart';
import 'package:tuple/tuple.dart';

extension MySQLUint8ListExtension on Uint8List {
  Tuple2<String, int> getUtf8NullTerminatedString(int startOffset) {
    final tmp = Uint8List.sublistView(this, startOffset)
        .takeWhile((value) => value != 0);

    return Tuple2(utf8.decode(tmp.toList()), tmp.length + 1);
  }

  String getUtf8StringEOF(int startOffset) {
    final tmp = Uint8List.sublistView(this, startOffset);
    return utf8.decode(tmp);
  }

  Tuple2<String, int> getUtf8LengthEncodedString(int startOffset) {
    final tmp = Uint8List.sublistView(this, startOffset);
    final bd = ByteData.sublistView(tmp);

    final strLength = bd.getVariableEncInt(0);

    final tmp2 = Uint8List.sublistView(
      tmp,
      strLength.item2,
      strLength.item2 + strLength.item1.toInt(),
    );

    return Tuple2(utf8.decode(tmp2), strLength.item2 + strLength.item1.toInt());
  }
}

extension MySQLByteDataExtension on ByteData {
  Tuple2<BigInt, int> getVariableEncInt(int startOffset) {
    int firstByte = getUint8(startOffset);

    if (firstByte < 0xfb) {
      return Tuple2(BigInt.from(firstByte), 1);
    }

    if (firstByte == 0xfc) {
      String radix =
          getUint8(startOffset + 2).toRadixString(16).padLeft(2, '0') +
              getUint8(startOffset + 1).toRadixString(16).padLeft(2, '0');

      return Tuple2(BigInt.parse(radix, radix: 16), 3);
    }

    if (firstByte == 0xfd) {
      String radix =
          getUint8(startOffset + 3).toRadixString(16).padLeft(2, '0') +
              getUint8(startOffset + 2).toRadixString(16).padLeft(2, '0') +
              getUint8(startOffset + 1).toRadixString(16).padLeft(2, '0');

      return Tuple2(BigInt.parse(radix, radix: 16), 4);
    }

    if (firstByte == 0xfe) {
      String radix =
          getUint8(startOffset + 8).toRadixString(16).padLeft(2, '0') +
              getUint8(startOffset + 7).toRadixString(16).padLeft(2, '0') +
              getUint8(startOffset + 6).toRadixString(16).padLeft(2, '0') +
              getUint8(startOffset + 5).toRadixString(16).padLeft(2, '0') +
              getUint8(startOffset + 4).toRadixString(16).padLeft(2, '0') +
              getUint8(startOffset + 3).toRadixString(16).padLeft(2, '0') +
              getUint8(startOffset + 2).toRadixString(16).padLeft(2, '0') +
              getUint8(startOffset + 1).toRadixString(16).padLeft(2, '0');

      return Tuple2(BigInt.parse(radix, radix: 16), 9);
    }

    throw MySQLProtocolException(
        "Wrong first byte, while decoding getVariableEncInt");
  }

  int getInt2(int startOffset) {
    final bd = ByteData(2);
    bd.setUint8(0, getUint8(startOffset));
    bd.setUint8(1, getUint8(startOffset + 1));

    return bd.getUint16(0, Endian.little);
  }

  int getInt3(int startOffset) {
    final bd = ByteData(4);
    bd.setUint8(0, getUint8(startOffset));
    bd.setUint8(1, getUint8(startOffset + 1));
    bd.setUint8(2, getUint8(startOffset + 2));
    bd.setUint8(3, 0);

    return bd.getUint32(0, Endian.little);
  }
}

extension MySQLByteWriterExtension on ByteDataWriter {
  writeVariableEncInt(int value) {
    if (value < 251) {
      writeUint8(value);
    } else if (value >= 251 && value < 65536) {
      writeUint8(0xfc);
      writeInt16(value);
    } else if (value >= 65536 && value < 16777216) {
      writeUint8(0xfd);
      final bd = ByteData(4);
      bd.setInt32(0, value, Endian.little);
      write(bd.buffer.asUint8List().sublist(0, 3));
    } else if (value >= 16777216) {
      writeUint8(0xfe);
      writeInt64(value);
    }
  }
}
