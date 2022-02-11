import 'dart:typed_data';
import 'package:tuple/tuple.dart';
import 'package:mysql_client/mysql_protocol_extension.dart';

const mysqlColumnTypeDecimal = 0x00;
const mysqlColumnTypeTiny = 0x01;
const mysqlColumnTypeShort = 0x02;
const mysqlColumnTypeLong = 0x03;
const mysqlColumnTypeFloat = 0x04;
const mysqlColumnTypeDouble = 0x05;
const mysqlColumnTypeNull = 0x06;
const mysqlColumnTypeTimestamp = 0x07;
const mysqlColumnTypeLongLong = 0x08;
const mysqlColumnTypeInt24 = 0x09;
const mysqlColumnTypeDate = 0x0a;
const mysqlColumnTypeTime = 0x0b;
const mysqlColumnTypeDateTime = 0x0c;
const mysqlColumnTypeYear = 0x0d;
const mysqlColumnTypeNewDate = 0x0e;
const mysqlColumnTypeVarChar = 0x0f;
const mysqlColumnTypeBit = 0x10;
const mysqlColumnTypeTimestamp2 = 0x11;
const mysqlColumnTypeDateTime2 = 0x12;
const mysqlColumnTypeTime2 = 0x13;
const mysqlColumnTypeNewDecimal = 0xf6;
const mysqlColumnTypeEnum = 0xf7;
const mysqlColumnTypeSet = 0xf8;
const mysqlColumnTypeTinyBlob = 0xf9;
const mysqlColumnTypeMediumBlob = 0xfa;
const mysqlColumnTypeLongBlob = 0xfb;
const mysqlColumnTypeBlob = 0xfc;
const mysqlColumnTypeVarString = 0xfd;
const mysqlColumnTypeString = 0xfe;
const mysqlColumnTypeGeometry = 0xff;

Tuple2<String, int> parseBinaryColumnData(
  int columnType,
  ByteData data,
  Uint8List buffer,
  int startOffset,
) {
  switch (columnType) {
    case mysqlColumnTypeTiny:
      final value = data.getInt8(startOffset);
      return Tuple2(value.toString(), 1);
    case mysqlColumnTypeShort:
      final value = data.getInt16(startOffset, Endian.little);
      return Tuple2(value.toString(), 2);
    case mysqlColumnTypeLong:
    case mysqlColumnTypeInt24:
      final value = data.getInt32(startOffset, Endian.little);
      return Tuple2(value.toString(), 4);
    case mysqlColumnTypeLongLong:
      final value = data.getInt64(startOffset, Endian.little);
      return Tuple2(value.toString(), 8);
    case mysqlColumnTypeFloat:
      final value = data.getFloat32(startOffset, Endian.little);
      return Tuple2(value.toString(), 4);
    case mysqlColumnTypeDouble:
      final value = data.getFloat64(startOffset, Endian.little);
      return Tuple2(value.toString(), 8);
    case mysqlColumnTypeDate:
    case mysqlColumnTypeDateTime:
    case mysqlColumnTypeTimestamp:
      throw UnimplementedError("column type not implemented");
    case mysqlColumnTypeTime:
      throw UnimplementedError("column type not implemented");
    case mysqlColumnTypeString:
    case mysqlColumnTypeVarString:
    case mysqlColumnTypeVarChar:
    case mysqlColumnTypeEnum:
    case mysqlColumnTypeSet:
    case mysqlColumnTypeLongBlob:
    case mysqlColumnTypeMediumBlob:
    case mysqlColumnTypeBlob:
    case mysqlColumnTypeTinyBlob:
    case mysqlColumnTypeGeometry:
    case mysqlColumnTypeBit:
    case mysqlColumnTypeDecimal:
    case mysqlColumnTypeNewDecimal:
      return buffer.getLengthEncodedString(startOffset);
  }

  throw UnimplementedError(
    "Can not parse binary column data: column type $columnType is not implemented",
  );
}
