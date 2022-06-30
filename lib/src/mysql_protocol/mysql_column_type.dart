import 'dart:typed_data';
import 'package:tuple/tuple.dart';
import 'package:mysql_client/exception.dart';
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

class MySQLColumnType {
  final int _value;

  const MySQLColumnType._(int value) : _value = value;
  factory MySQLColumnType.create(int value) => MySQLColumnType._(value);
  int get intVal => _value;

  static const decimalType = MySQLColumnType._(mysqlColumnTypeDecimal);
  static const tinyType = MySQLColumnType._(mysqlColumnTypeTiny);
  static const shortType = MySQLColumnType._(mysqlColumnTypeShort);
  static const longType = MySQLColumnType._(mysqlColumnTypeLong);
  static const floatType = MySQLColumnType._(mysqlColumnTypeFloat);
  static const doubleType = MySQLColumnType._(mysqlColumnTypeDouble);
  static const nullType = MySQLColumnType._(mysqlColumnTypeNull);
  static const timestampType = MySQLColumnType._(mysqlColumnTypeTimestamp);
  static const longLongType = MySQLColumnType._(mysqlColumnTypeLongLong);
  static const int24Type = MySQLColumnType._(mysqlColumnTypeInt24);
  static const dateType = MySQLColumnType._(mysqlColumnTypeDate);
  static const timeType = MySQLColumnType._(mysqlColumnTypeTime);
  static const dateTimeType = MySQLColumnType._(mysqlColumnTypeDateTime);
  static const yearType = MySQLColumnType._(mysqlColumnTypeYear);
  static const newDateType = MySQLColumnType._(mysqlColumnTypeNewDate);
  static const vatChartType = MySQLColumnType._(mysqlColumnTypeVarChar);
  static const bitType = MySQLColumnType._(mysqlColumnTypeBit);
  static const timestamp2Type = MySQLColumnType._(mysqlColumnTypeTimestamp2);
  static const dateTime2Type = MySQLColumnType._(mysqlColumnTypeDateTime2);
  static const time2Type = MySQLColumnType._(mysqlColumnTypeTime2);
  static const newDecimalType = MySQLColumnType._(mysqlColumnTypeNewDecimal);
  static const enumType = MySQLColumnType._(mysqlColumnTypeEnum);
  static const setType = MySQLColumnType._(mysqlColumnTypeSet);
  static const tinyBlobType = MySQLColumnType._(mysqlColumnTypeTinyBlob);
  static const mediumBlobType = MySQLColumnType._(mysqlColumnTypeMediumBlob);
  static const longBlobType = MySQLColumnType._(mysqlColumnTypeLongBlob);
  static const blocType = MySQLColumnType._(mysqlColumnTypeBlob);
  static const varStringType = MySQLColumnType._(mysqlColumnTypeVarString);
  static const stringType = MySQLColumnType._(mysqlColumnTypeString);
  static const geometryType = MySQLColumnType._(mysqlColumnTypeGeometry);

  T? convertStringValueToProvidedType<T>(String? value, [int? columnLength]) {
    if (value == null) {
      return null;
    }

    if (T == String || T == dynamic) {
      return value as T;
    }

    if (T == bool) {
      if (_value == mysqlColumnTypeTiny && columnLength == 1) {
        return int.parse(value) > 0 as T;
      } else {
        throw MySQLProtocolException(
          "Can not convert MySQL type $_value to requested type bool",
        );
      }
    }

    // convert to int
    if (T == int) {
      switch (_value) {
        // types convertible to dart int
        case mysqlColumnTypeTiny:
        case mysqlColumnTypeShort:
        case mysqlColumnTypeLong:
        case mysqlColumnTypeLongLong:
        case mysqlColumnTypeInt24:
        case mysqlColumnTypeYear:
          return int.parse(value) as T;
        default:
          throw MySQLProtocolException(
            "Can not convert MySQL type $_value to requested type int",
          );
      }
    }

    if (T == double) {
      switch (_value) {
        case mysqlColumnTypeTiny:
        case mysqlColumnTypeShort:
        case mysqlColumnTypeLong:
        case mysqlColumnTypeLongLong:
        case mysqlColumnTypeInt24:
        case mysqlColumnTypeFloat:
        case mysqlColumnTypeDouble:
          return double.parse(value) as T;
        default:
          throw MySQLProtocolException(
            "Can not convert MySQL type $_value to requested type double",
          );
      }
    }

    if (T == num) {
      switch (_value) {
        case mysqlColumnTypeTiny:
        case mysqlColumnTypeShort:
        case mysqlColumnTypeLong:
        case mysqlColumnTypeLongLong:
        case mysqlColumnTypeInt24:
        case mysqlColumnTypeFloat:
        case mysqlColumnTypeDouble:
          return num.parse(value) as T;
        default:
          throw MySQLProtocolException(
            "Can not convert MySQL type $_value to requested type num",
          );
      }
    }

    throw MySQLProtocolException(
      "Can not convert MySQL type ${T.runtimeType} to requested type int",
    );
  }

  Type getBestMatchDartType(int columnLength) {
    switch (_value) {
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
        return String;
      case mysqlColumnTypeTiny:
        if (columnLength == 1) {
          return bool;
        } else {
          return int;
        }
      case mysqlColumnTypeShort:
      case mysqlColumnTypeLong:
      case mysqlColumnTypeLongLong:
      case mysqlColumnTypeInt24:
        return int;
      case mysqlColumnTypeFloat:
      case mysqlColumnTypeDouble:
        return double;
      default:
        return String;
    }
  }
}

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
      final initialOffset = startOffset;

      // read number of bytes (0, 4, 7, 11)
      final numOfBytes = data.getUint8(startOffset);
      startOffset += 1;

      if (numOfBytes == 0) {
        return Tuple2("0000-00-00 00:00:00", 1);
      }

      var year = 0;
      var month = 0;
      var day = 0;
      var hour = 0;
      var minute = 0;
      var second = 0;
      var microSecond = 0;

      if (numOfBytes >= 4) {
        year = data.getUint16(startOffset, Endian.little);
        startOffset += 2;

        month = data.getUint8(startOffset);
        startOffset += 1;

        day = data.getUint8(startOffset);
        startOffset += 1;
      }

      if (numOfBytes >= 7) {
        hour = data.getUint8(startOffset);
        startOffset += 1;

        minute = data.getUint8(startOffset);
        startOffset += 1;

        second = data.getUint8(startOffset);
        startOffset += 1;
      }

      if (numOfBytes >= 11) {
        microSecond = data.getUint32(startOffset, Endian.little);
        startOffset += 4;
      }

      final result = StringBuffer();
      result.write(year.toString() + '-');
      result.write(month.toString().padLeft(2, '0') + '-');
      result.write(day.toString().padLeft(2, '0') + ' ');
      result.write(hour.toString().padLeft(2, '0') + ':');
      result.write(minute.toString().padLeft(2, '0') + ':');
      result.write(second.toString().padLeft(2, '0') + '.');
      result.write(microSecond.toString());

      return Tuple2(result.toString(), startOffset - initialOffset);
    case mysqlColumnTypeTime:
      final initialOffset = startOffset;

      // read number of bytes (0, 8, 12)
      final numOfBytes = data.getUint8(startOffset);
      startOffset += 1;

      if (numOfBytes == 0) {
        return Tuple2("00:00:00", 1);
      }

      var isNegative = false;
      var days = 0;
      var hours = 0;
      var minutes = 0;
      var seconds = 0;
      var microSecond = 0;

      if (numOfBytes >= 8) {
        isNegative = data.getUint8(startOffset) > 0;
        startOffset += 1;

        days = data.getUint32(startOffset, Endian.little);
        startOffset += 4;

        hours = data.getUint8(startOffset);
        startOffset += 1;

        minutes = data.getUint8(startOffset);
        startOffset += 1;

        seconds = data.getUint8(startOffset);
        startOffset += 1;
      }

      if (numOfBytes >= 12) {
        microSecond = data.getUint32(startOffset, Endian.little);
        startOffset += 4;
      }

      hours += days * 24;

      final result = StringBuffer();
      if (isNegative) {
        result.write("-");
      }
      result.write(hours.toString().padLeft(2, '0') + ':');
      result.write(minutes.toString().padLeft(2, '0') + ':');
      result.write(seconds.toString().padLeft(2, '0') + '.');
      result.write(microSecond.toString());

      return Tuple2(result.toString(), startOffset - initialOffset);
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
      return buffer.getUtf8LengthEncodedString(startOffset);
  }

  throw MySQLProtocolException(
    "Can not parse binary column data: column type $columnType is not implemented",
  );
}
