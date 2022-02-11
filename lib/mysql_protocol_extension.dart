import 'dart:typed_data';
import 'package:tuple/tuple.dart';

extension ParseUtils on Uint8List {
  String getNullTerminatedString(int startOffset) {
    final tmp = Uint8List.sublistView(this, startOffset)
        .takeWhile((value) => value != 0);

    return String.fromCharCodes(tmp);
  }

  String getStringEOF(int startOffset) {
    final tmp = Uint8List.sublistView(this, startOffset);
    return String.fromCharCodes(tmp);
  }

  Tuple2<String, int> getLengthEncodedString(int startOffset) {
    final tmp = Uint8List.sublistView(this, startOffset);
    final bd = ByteData.sublistView(tmp);

    final strLength = bd.getVariableEncInt(0);

    final tmp2 = Uint8List.sublistView(
      tmp,
      strLength.item2,
      strLength.item1.toInt() + 1,
    );

    return Tuple2(
        String.fromCharCodes(tmp2), strLength.item2 + strLength.item1.toInt());
  }
}

extension ByteDataParseUtils on ByteData {
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

    throw UnimplementedError();
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
