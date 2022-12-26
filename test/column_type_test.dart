import 'package:mysql_client/mysql_protocol.dart';
import 'package:test/test.dart';

void main() {
  test(
    "testing decimal type",
    () {
      final sqlType = MySQLColumnType.create(mysqlColumnTypeDecimal);

      dynamic result =
          sqlType.convertStringValueToProvidedType<String>('10.00');
      result = sqlType.convertStringValueToProvidedType<String>('-10.00');
      expect(result, '-10.00');
      result = sqlType.convertStringValueToProvidedType<String>('0');
      expect(result, '0');
      result = sqlType.convertStringValueToProvidedType<String>('9999.99');
      expect(result, '9999.99');
      result = sqlType.convertStringValueToProvidedType<String>('1000123');
      expect(result, '1000123');

      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('10.00'),
        throwsException,
      );

      expect(
        () => sqlType.convertStringValueToProvidedType<int>('10.00'),
        throwsException,
      );

      expect(
        () => sqlType.convertStringValueToProvidedType<double>('10.00'),
        throwsException,
      );

      expect(
        () => sqlType.convertStringValueToProvidedType<num>('10.00'),
        throwsException,
      );
    },
  );

  test(
    "testing tiny type",
    () {
      final sqlType = MySQLColumnType.create(mysqlColumnTypeTiny);

      dynamic result = sqlType.convertStringValueToProvidedType<bool>('1', 1);
      expect(result, true);
      result = sqlType.convertStringValueToProvidedType<bool>('0', 1);
      expect(result, false);
      result = sqlType.convertStringValueToProvidedType<bool>('10', 1);
      expect(result, true);
      result = sqlType.convertStringValueToProvidedType<int>('1', 1);
      expect(result, 1);
      result = sqlType.convertStringValueToProvidedType<int>('0', 1);
      expect(result, 0);
      result = sqlType.convertStringValueToProvidedType<int>('2', 1);
      expect(result, 2);
      result = sqlType.convertStringValueToProvidedType<double>('10', 1);
      expect(result, 10.00);
      result = sqlType.convertStringValueToProvidedType<num>('10', 1);
      expect(result, 10);
      result = sqlType.convertStringValueToProvidedType<String>('10', 1);
      expect(result, '10');

      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('1', 2),
        throwsException,
      );
    },
  );

  test(
    "testing short type",
    () {
      final sqlType = MySQLColumnType.create(mysqlColumnTypeShort);

      dynamic result = sqlType.convertStringValueToProvidedType<int>('1');
      expect(result, 1);
      result = sqlType.convertStringValueToProvidedType<int>('0');
      expect(result, 0);
      result = sqlType.convertStringValueToProvidedType<int>('2');
      expect(result, 2);
      result = sqlType.convertStringValueToProvidedType<double>('10');
      expect(result, 10.00);
      result = sqlType.convertStringValueToProvidedType<num>('10');
      expect(result, 10);
      result = sqlType.convertStringValueToProvidedType<String>('10');
      expect(result, '10');

      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('1'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('0'),
        throwsException,
      );
    },
  );

  test(
    "testing long type",
    () {
      final sqlType = MySQLColumnType.create(mysqlColumnTypeLong);

      dynamic result = sqlType.convertStringValueToProvidedType<int>('1');
      expect(result, 1);
      result = sqlType.convertStringValueToProvidedType<int>('0');
      expect(result, 0);
      result = sqlType.convertStringValueToProvidedType<int>('2');
      expect(result, 2);
      result = sqlType.convertStringValueToProvidedType<double>('10');
      expect(result, 10.00);
      result = sqlType.convertStringValueToProvidedType<num>('10');
      expect(result, 10);
      result = sqlType.convertStringValueToProvidedType<String>('10');
      expect(result, '10');

      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('1'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('0'),
        throwsException,
      );
    },
  );

  test(
    "testing long long type",
    () {
      final sqlType = MySQLColumnType.create(mysqlColumnTypeLongLong);

      dynamic result = sqlType.convertStringValueToProvidedType<int>('1');
      expect(result, 1);
      result = sqlType.convertStringValueToProvidedType<int>('0');
      expect(result, 0);
      result = sqlType.convertStringValueToProvidedType<int>('2');
      expect(result, 2);
      result = sqlType.convertStringValueToProvidedType<double>('10');
      expect(result, 10.00);
      result = sqlType.convertStringValueToProvidedType<num>('10');
      expect(result, 10);
      result = sqlType.convertStringValueToProvidedType<String>('10');
      expect(result, '10');

      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('1'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('0'),
        throwsException,
      );
    },
  );

  test(
    "testing int24 type",
    () {
      final sqlType = MySQLColumnType.create(mysqlColumnTypeLongLong);

      dynamic result = sqlType.convertStringValueToProvidedType<int>('1');
      expect(result, 1);
      result = sqlType.convertStringValueToProvidedType<int>('0');
      expect(result, 0);
      result = sqlType.convertStringValueToProvidedType<int>('2');
      expect(result, 2);
      result = sqlType.convertStringValueToProvidedType<double>('10');
      expect(result, 10.00);
      result = sqlType.convertStringValueToProvidedType<num>('10');
      expect(result, 10);
      result = sqlType.convertStringValueToProvidedType<String>('10');
      expect(result, '10');

      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('1'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('0'),
        throwsException,
      );
    },
  );

  test(
    "testing float type",
    () {
      final sqlType = MySQLColumnType.create(mysqlColumnTypeFloat);

      dynamic result =
          sqlType.convertStringValueToProvidedType<double>('10.00');
      expect(result, 10.00);
      result = sqlType.convertStringValueToProvidedType<double>('-10.00');
      expect(result, -10.00);
      result = sqlType.convertStringValueToProvidedType<num>('10.00');
      expect(result, 10.00);
      result = sqlType.convertStringValueToProvidedType<String>('10.00');
      expect(result, '10.00');

      expect(
        () => sqlType.convertStringValueToProvidedType<int>('1.0'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('1.0'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('0.0'),
        throwsException,
      );
    },
  );

  test(
    "testing double type",
    () {
      final sqlType = MySQLColumnType.create(mysqlColumnTypeDouble);

      dynamic result =
          sqlType.convertStringValueToProvidedType<double>('10.00');
      expect(result, 10.00);
      result = sqlType.convertStringValueToProvidedType<double>('-10.00');
      expect(result, -10.00);
      result = sqlType.convertStringValueToProvidedType<num>('10.00');
      expect(result, 10.00);
      result = sqlType.convertStringValueToProvidedType<String>('10.00');
      expect(result, '10.00');

      expect(
        () => sqlType.convertStringValueToProvidedType<int>('1.0'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('1.0'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('0.0'),
        throwsException,
      );
    },
  );

  test(
    "testing timestamp type",
    () {
      final sqlType = MySQLColumnType.create(mysqlColumnTypeTimestamp);

      dynamic result =
          sqlType.convertStringValueToProvidedType<String>('123451234');
      expect(result, '123451234');

      expect(
        () => sqlType.convertStringValueToProvidedType<int>('123451234'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<double>('123451234'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<num>('123451234'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('123451234'),
        throwsException,
      );
    },
  );

  test(
    "testing date type",
    () {
      final sqlType = MySQLColumnType.create(mysqlColumnTypeDate);

      dynamic result =
          sqlType.convertStringValueToProvidedType<String>('2022-01-02');
      expect(result, '2022-01-02');

      expect(
        () => sqlType.convertStringValueToProvidedType<int>('2022-01-02'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<double>('2022-01-02'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<num>('2022-01-02'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('2022-01-02'),
        throwsException,
      );
    },
  );

  test(
    "testing time type",
    () {
      final sqlType = MySQLColumnType.create(mysqlColumnTypeDate);

      dynamic result =
          sqlType.convertStringValueToProvidedType<String>('02:00:34');
      expect(result, '02:00:34');

      expect(
        () => sqlType.convertStringValueToProvidedType<int>('02:00:34'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<double>('02:00:34'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<num>('02:00:34'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('02:00:34'),
        throwsException,
      );
    },
  );

  test(
    "testing datetime type",
    () {
      final sqlType = MySQLColumnType.create(mysqlColumnTypeDate);

      dynamic result = sqlType
          .convertStringValueToProvidedType<String>('2022-01-05 02:00:34');
      expect(result, '2022-01-05 02:00:34');

      dynamic resultAsDate = sqlType
          .convertStringValueToProvidedType<DateTime>('2022-01-05 02:00:34');
      expect(resultAsDate, DateTime.parse('2022-01-05 02:00:34'));

      expect(
        () => sqlType
            .convertStringValueToProvidedType<int>('2022-01-05 02:00:34'),
        throwsException,
      );
      expect(
        () => sqlType
            .convertStringValueToProvidedType<double>('2022-01-05 02:00:34'),
        throwsException,
      );
      expect(
        () => sqlType
            .convertStringValueToProvidedType<num>('2022-01-05 02:00:34'),
        throwsException,
      );
      expect(
        () => sqlType
            .convertStringValueToProvidedType<bool>('2022-01-05 02:00:34'),
        throwsException,
      );
    },
  );

  test(
    "testing year type",
    () {
      final sqlType = MySQLColumnType.create(mysqlColumnTypeYear);

      dynamic result = sqlType.convertStringValueToProvidedType<String>('2022');
      expect(result, '2022');
      result = sqlType.convertStringValueToProvidedType<int>('2022');
      expect(result, 2022);

      expect(
        () => sqlType.convertStringValueToProvidedType<double>('2022'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<num>('2022'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('2022'),
        throwsException,
      );
    },
  );

  test(
    "testing varchar type",
    () {
      final sqlType = MySQLColumnType.create(mysqlColumnTypeVarChar);

      dynamic result =
          sqlType.convertStringValueToProvidedType<String>('Some text');
      expect(result, 'Some text');

      result =
          sqlType.convertStringValueToProvidedType<String>('Какой-то текст');
      expect(result, 'Какой-то текст');

      expect(
        () => sqlType.convertStringValueToProvidedType<int>('2022'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<double>('2022'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<num>('2022'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('2022'),
        throwsException,
      );
    },
  );

  test(
    "testing string type",
    () {
      final sqlType = MySQLColumnType.create(mysqlColumnTypeString);

      dynamic result =
          sqlType.convertStringValueToProvidedType<String>('Some text');
      expect(result, 'Some text');

      result =
          sqlType.convertStringValueToProvidedType<String>('Какой-то текст');
      expect(result, 'Какой-то текст');

      expect(
        () => sqlType.convertStringValueToProvidedType<int>('2022'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<double>('2022'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<num>('2022'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('2022'),
        throwsException,
      );
    },
  );

  test(
    "testing var string type",
    () {
      final sqlType = MySQLColumnType.create(mysqlColumnTypeVarString);

      dynamic result =
          sqlType.convertStringValueToProvidedType<String>('Some text');
      expect(result, 'Some text');

      result =
          sqlType.convertStringValueToProvidedType<String>('Какой-то текст');
      expect(result, 'Какой-то текст');

      expect(
        () => sqlType.convertStringValueToProvidedType<int>('2022'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<double>('2022'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<num>('2022'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('2022'),
        throwsException,
      );
    },
  );

  test(
    "testing enum type",
    () {
      final sqlType = MySQLColumnType.create(mysqlColumnTypeEnum);

      dynamic result =
          sqlType.convertStringValueToProvidedType<String>('process');
      expect(result, 'process');

      expect(
        () => sqlType.convertStringValueToProvidedType<int>('process'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<double>('process'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<num>('process'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('process'),
        throwsException,
      );
    },
  );

  test(
    "testing set type",
    () {
      final sqlType = MySQLColumnType.create(mysqlColumnTypeSet);

      dynamic result =
          sqlType.convertStringValueToProvidedType<String>('process');
      expect(result, 'process');

      expect(
        () => sqlType.convertStringValueToProvidedType<int>('process'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<double>('process'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<num>('process'),
        throwsException,
      );
      expect(
        () => sqlType.convertStringValueToProvidedType<bool>('process'),
        throwsException,
      );
    },
  );
}
