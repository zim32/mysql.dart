import 'dart:io';
import 'package:mysql_client/exception.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:test/test.dart';

void testMysqlClient(dynamic host, int port, String user, String pass, String db) {

  late MySQLConnection conn;

  setUpAll(
    () async {
      stdout.writeln("\n!!!!!!!!!!!!!!!!!!!!!");
      stdout.writeln(
          "Warning this test will execute real queries to database at: $host, port: $port, dbname: $db. Continue? y/n");
      stdout.writeln("!!!!!!!!!!!!!!!!!!!!!");

      final response = stdin.readLineSync();

      if (response != 'y') {
        exit(0);
      }

      conn = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: user,
        password: pass,
        secure: true,
      );

      expect(conn.connected, false);
      await conn.connect();
      expect(conn.connected, true);

      await conn.execute("DROP DATABASE IF EXISTS $db");
      await conn.execute(
        "CREATE DATABASE $db CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci",
      );
      await conn.execute("USE $db");
      await conn.execute("""
create table book
(
    id int auto_increment primary key,
    author_id  int           null,
    title      varchar(255)  not null,
    price      int default 0 not null,
    created_at datetime      not null,
    some_time  time          null
)
""");
    },
  );

  tearDownAll(
    () async {
      int counter = 0;

      conn.onClose(() => counter++);
      conn.onClose(() => counter++);

      await conn.close();
      expect(conn.connected, false);
      expect(counter, 2);
    },
  );

  test(
    "testing bad connection",
    () async {
      try {
        final localConn = await MySQLConnection.createConnection(
          host: host,
          port: port,
          userName: 'fake',
          password: 'fake',
          secure: true,
        );

        await localConn.connect();

        fail("Not thrown");
      } catch (e) {
        expect(e, isA<MySQLServerException>());
      }
    },
  );

  test(
    "testing insert",
    () async {
      final result = await conn.execute(
        "INSERT INTO book (author_id, title, price, created_at) VALUES (:author, :title, :price, :created)",
        {
          "author": null,
          "title": "Новая книга 😁",
          "price": 100,
          "created": "2020-01-01 01:00:15",
        },
      );

      expect(result.affectedRows.toInt(), 1);
      expect(result.lastInsertID.toInt(), 1);
    },
  );

  test(
    "testing select",
    () async {
      final result = await conn.execute(
        "SELECT * FROM book WHERE id = :id",
        {
          "id": 1,
        },
      );

      expect(result.affectedRows.toInt(), 0);
      expect(result.lastInsertID.toInt(), 0);
      expect(result.numOfColumns, 6);
      expect(result.numOfRows, 1);

      // get first row
      final row = await result.rowsStream.first;

      expect(row.colAt(0), "1");
      expect(row.colAt(1), null);
      expect(row.colAt(2), "Новая книга 😁");
      expect(row.colAt(3), "100");
      expect(row.colAt(4), "2020-01-01 01:00:15");
      expect(row.colAt(5), null);
      expect(row.typedColAt<int>(0), 1);
      expect(row.typedColAt<int>(3), 100);
      expect(row.typedColAt<double>(3), 100.00);

      expect(row.colByName('id'), "1");
      expect(row.colByName('author_id'), null);
      expect(row.colByName('title'), "Новая книга 😁");
      expect(row.colByName('Title'), "Новая книга 😁");
      expect(row.colByName('PrIce'), "100");
      expect(row.typedColByName<int>('price'), 100);
      expect(row.typedColByName<double>('price'), 100.00);
      expect(row.typedColByName<int>('Price'), 100);
      expect(row.typedColByName<double>('pRice'), 100.00);
      expect(row.colByName('created_at'), "2020-01-01 01:00:15");
      expect(row.colByName('some_time'), null);
      expect(row.colByName('Some_Time'), null);

      expect(row.assoc(), {
        "id": "1",
        "author_id": null,
        "title": "Новая книга 😁",
        "price": "100",
        "created_at": "2020-01-01 01:00:15",
        "some_time": null,
      });

      expect(row.typedAssoc(), {
        "id": 1,
        "author_id": null,
        "title": "Новая книга 😁",
        "price": 100,
        "created_at": DateTime.parse("2020-01-01 01:00:15"),
        "some_time": null,
      });
    },
  );

  test(
    "testing error is thrown if syntax error",
    () async {
      try {
        await conn.execute(
          "SELECT * FROM book WHERES ASD id = :id",
          {
            "id": 1,
          },
        );

        fail("Exception is not thrown");
      } catch (e) {
        expect(e, isA<MySQLServerException>());
      }
    },
  );

  test(
    "testing error is thrown if null passed for not-null column",
    () async {
      try {
        await conn.execute(
          "INSERT INTO book (author_id, title, price, created_at, some_time) VALUES (:author, :title, :price, :created, :time)",
          {
            "author": null,
            "title": null,
            "price": 100,
            "created": "2020-01-01 01:00:15",
            "time": "01:15:25"
          },
        );
        fail("Exception is not thrown");
      } catch (e) {
        expect(e, isA<MySQLServerException>());
      }
    },
  );

  test(
    "testing error is thrown if syntax error in prepared stmt",
    () async {
      try {
        await conn.prepare(
          "INSERT INTO book (author_id, title) VA_LUESD (?, ?)",
        );
        fail("Exception is not thrown");
      } catch (e) {
        expect(e, isA<MySQLServerException>());
      }
    },
  );

  test(
    "testing delete",
    () async {
      final result = await conn.execute(
        "DELETE FROM book WHERE id = :id",
        {
          "id": 1,
        },
      );

      expect(result.affectedRows.toInt(), 1);
      expect(result.lastInsertID.toInt(), 0);
      expect(result.numOfColumns, 0);
      expect(result.numOfRows, 0);
    },
  );

  test(
    "testing transaction",
    () async {
      await conn.transactional((conn) async {
        final result = await conn.execute(
          "INSERT INTO book (author_id, title, price, created_at, some_time) VALUES (:author, :title, :price, :created, :time)",
          {
            "author": null,
            "title": "New book",
            "price": 100,
            "created": "2020-01-01 01:00:15",
            "time": "01:15:25"
          },
        );

        expect(result.affectedRows.toInt(), 1);
        expect(result.lastInsertID.toInt(), 2);
      });
    },
  );

  test(
    "testing select after transaction",
    () async {
      final result = await conn.execute(
        "SELECT * FROM book WHERE id = :id",
        {
          "id": 2,
        },
      );

      expect(result.affectedRows.toInt(), 0);
      expect(result.lastInsertID.toInt(), 0);
      expect(result.numOfColumns, 6);
      expect(result.numOfRows, 1);

      // get first row
      final row = await result.rowsStream.first;

      expect(row.colAt(0), "2");
      expect(row.colAt(1), null);
      expect(row.colAt(2), "New book");
      expect(row.colAt(3), "100");
      expect(row.colAt(4), "2020-01-01 01:00:15");
      expect(row.colAt(5), "01:15:25");
      expect(row.typedColAt<int>(0), 2);
      expect(row.typedColAt<int>(3), 100);
      expect(row.typedColAt<num>(3), 100);
      expect(row.typedColAt<double>(3), 100.00);

      expect(row.colByName('id'), "2");
      expect(row.colByName('author_id'), null);
      expect(row.colByName('title'), "New book");
      expect(row.colByName('price'), "100");
      expect(row.colByName('created_at'), "2020-01-01 01:00:15");
      expect(row.colByName('some_time'), "01:15:25");
    },
  );

  test("testing double transaction", () async {
    try {
      await conn.transactional<void>((conn) async {
        await conn.execute("SELECT * FROM book");
      });
      await conn.transactional<void>((conn) async {
        await conn.execute("SELECT * FROM book");
      });
    } catch (e) {
      fail("Exception is thrown");
    }
  });

  test("testing error is thrown if prevent double transaction", () async {
    try {
      await Future.wait([
        conn.transactional<void>((conn) async {
          await conn.execute("SELECT * FROM book");
        }),
        conn.transactional<void>((conn) async {
          await conn.execute("SELECT * FROM book");
        }),
      ]);
      fail("Exception is not thrown");
    } catch (e) {
      expect(e, isA<MySQLClientException>());
      expect(e.toString(), "MySQLClientException: Already in transaction");
    }
  });

  test(
    "testing missing param",
    () async {
      try {
        await conn.execute(
          "SELECT * FROM book WHERE id = :id",
          {"foo": "bar"},
        );

        fail("Exception is not thrown");
      } catch (e) {
        expect(e, isA<MySQLClientException>());
      }
    },
  );

  test(
    "testing prepared statement",
    () async {
      final stmt = await conn.prepare(
        'INSERT INTO book (title, price, created_at) VALUES (?, ?, ?)',
      );

      expect(stmt.numOfParams, 3);

      var result =
          await stmt.execute(['Some title 1', 200, '2022-04-02 00:00:00']);

      expect(result.affectedRows.toInt(), 1);
      expect(result.lastInsertID.toInt(), 3);

      result = await stmt.execute(['Some title 2', 200, '2022-04-02 00:00:00']);

      expect(result.affectedRows.toInt(), 1);
      expect(result.lastInsertID.toInt(), 4);

      await stmt.deallocate();

      // check throws error
      try {
        result = await stmt.execute(
          ['Some title 2', 200, '2022-04-02 00:00:00'],
        );
        fail("Not thrown");
      } catch (e) {
        expect(e, isA<MySQLServerException>());
      }

      // check rows
      result = await conn.execute('SELECT COUNT(id) FROM book');
      expect(result.rows.first.colAt(0), '3');
    },
  );

  test("testing string encoding in prepared statements", () async {
    var stmt = await conn.prepare(
      "INSERT INTO book (author_id, title, price, created_at) VALUES (?, ?, ?, ?)",
    );

    var result = await stmt.execute([null, '中文标题', 120, '2022-01-01']);
    await stmt.deallocate();

    expect(result.affectedRows.toInt(), 1);
  });

  test("testing prepared stmt select", () async {
    final stmt = await conn.prepare(
      'SELECT * FROM book WHERE title = ?',
    );

    final result = await stmt.execute(['Some title 2']);

    expect(result.numOfRows, 1);
    expect(result.affectedRows.toInt(), 0);
  });

  test(
    "testing empty result set",
    () async {
      final result = await conn.execute("SELECT * FROM book WHERE id = 99999");
      expect(result.numOfRows, 0);
    },
  );

  test(
    "testing empty result for prepared statement",
    () async {
      final stmt = await conn.prepare("SELECT * FROM book WHERE id = 99999");
      final result = await stmt.execute([]);
      expect(result.numOfRows, 0);
      await stmt.deallocate();
    },
  );

  test(
    "testing multiple statements",
    () async {
      final resultSets = await conn.execute(
        "SELECT 1 as val_1_1; SELECT 2 as val_2_1, 3 as val_2_2",
      );

      expect(resultSets.next, isNotNull);

      final resultSetsList = resultSets.toList();
      expect(resultSetsList.length, 2);

      expect(resultSetsList[0].rows.first.colByName("val_1_1"), "1");
      expect(resultSetsList[1].rows.first.colByName("val_2_1"), "2");
      expect(resultSetsList[1].rows.first.colByName("val_2_2"), "3");
    },
  );

  test(
    "testing column types mapping",
    () async {
      String tableName = 'column_types_test_123';
      await conn.execute("DROP TABLE IF EXISTS $tableName",);

      await conn.execute("""
        CREATE TABLE $tableName (
          col_pk INT AUTO_INCREMENT PRIMARY KEY,
          
          col_bit BIT DEFAULT 1,
          col_tinyint TINYINT DEFAULT 1,
          col_bool BOOL DEFAULT 1,
          col_smallint SMALLINT DEFAULT 1,
          col_mediumint MEDIUMINT DEFAULT 1,
          col_int INT DEFAULT 1,
          col_integer INTEGER DEFAULT 1,
          col_bigint BIGINT DEFAULT 1,
          col_decimal DECIMAL DEFAULT 1.1,
          col_dec DEC DEFAULT 1.1,
          col_numeric NUMERIC DEFAULT 1.1,
          col_fixed FIXED DEFAULT 1.1,
          col_float FLOAT DEFAULT 1.1,
          col_double DOUBLE DEFAULT 1.1,
          
          col_date DATE DEFAULT '2000-01-01',
          col_time TIME DEFAULT '12:00:00',
          col_datetime DATETIME DEFAULT '2000-01-01 12:00:00',
          col_timestamp TIMESTAMP DEFAULT '2000-01-01 12:00:00',
          col_year YEAR DEFAULT '2000',

          col_char CHAR(255) DEFAULT 'test_string',
          col_varchar VARCHAR(255) DEFAULT 'test_string',
          col_binary BINARY(255) DEFAULT 'test_string',
          col_varbinary VARBINARY(255) DEFAULT 'test_string',
          col_tinyblob TINYBLOB,
          col_blob BLOB, 
          col_mediumblob MEDIUMBLOB, 
          col_longblob LONGBLOB,
          col_tinytext TINYTEXT, 
          col_text TEXT, 
          col_mediumtext MEDIUMTEXT, 
          col_longtext LONGTEXT,
          col_enum ENUM('test1', 'test2', 'test3') DEFAULT 'test1',
          col_set SET('test1', 'test2', 'test3') DEFAULT 'test1'
          /*
          TODO: support for spatial types?
          col_geometry GEOMETRY,
          col_point POINT DEFAULT (Point(0.1,0.1)),
          col_linestring LINESTRING,
          col_polygon POLYGON,
          col_multipoint MULTIPOINT,
          col_multilinestring MULTILINESTRING,
          col_multipolygon MULTIPOLYGON,
          col_geometrycollection GEOMETRYCOLLECTION
          */
        )
      """);

      //insert and set values for columns with no defaults
      await conn.execute("""
        INSERT INTO $tableName SET 
        col_tinyblob = 'test_string', 
        col_blob = 'test_string', 
        col_mediumblob = 'test_string', 
        col_longblob = 'test_string', 
        col_tinytext = 'test_string', 
        col_text = 'test_string', 
        col_mediumtext = 'test_string', 
        col_longtext = 'test_string';
        """
      );
      var response = await conn.execute("SELECT * FROM $tableName");
      for (var row in response.rows) {
        var typedAssoc = row.typedAssoc();

        expect(typedAssoc['col_pk'].runtimeType, int);
        expect(typedAssoc['col_bit'].runtimeType, String);
        expect(typedAssoc['col_tinyint'].runtimeType, int);
        expect(typedAssoc['col_bool'].runtimeType, bool);
        expect(typedAssoc['col_smallint'].runtimeType, int);
        expect(typedAssoc['col_mediumint'].runtimeType, int);
        expect(typedAssoc['col_int'].runtimeType, int);
        expect(typedAssoc['col_integer'].runtimeType, int);
        expect(typedAssoc['col_bigint'].runtimeType, int);
        expect(typedAssoc['col_decimal'].runtimeType, String);
        expect(typedAssoc['col_dec'].runtimeType, String);
        expect(typedAssoc['col_numeric'].runtimeType, String);
        expect(typedAssoc['col_fixed'].runtimeType, String);
        expect(typedAssoc['col_float'].runtimeType, double);
        expect(typedAssoc['col_double'].runtimeType, double);

        expect(typedAssoc['col_date'].runtimeType, DateTime);
        expect(typedAssoc['col_time'].runtimeType, String);
        expect(typedAssoc['col_datetime'].runtimeType, DateTime);
        expect(typedAssoc['col_timestamp'].runtimeType, DateTime);
        expect(typedAssoc['col_year'].runtimeType, int);

        expect(typedAssoc['col_char'].runtimeType, String);
        expect(typedAssoc['col_varchar'].runtimeType, String);
        expect(typedAssoc['col_binary'].runtimeType, String);
        expect(typedAssoc['col_varbinary'].runtimeType, String);
        expect(typedAssoc['col_tinyblob'].runtimeType, String);
        expect(typedAssoc['col_blob'].runtimeType, String);
        expect(typedAssoc['col_mediumblob'].runtimeType, String);
        expect(typedAssoc['col_longblob'].runtimeType, String);
        expect(typedAssoc['col_tinytext'].runtimeType, String);
        expect(typedAssoc['col_text'].runtimeType, String);
        expect(typedAssoc['col_mediumtext'].runtimeType, String);
        expect(typedAssoc['col_longtext'].runtimeType, String);
        expect(typedAssoc['col_enum'].runtimeType, String);
        expect(typedAssoc['col_set'].runtimeType, String);
      }

      var groupedResponse = await conn.execute("""
      SELECT 
      col_pk, 
      SUM(col_int) as sum_int, 
      MAX(col_int) as max_int, 
      SUM(col_double) as sum_double 
      FROM $tableName GROUP BY col_pk
      """);
      for (var row in groupedResponse.rows) {
        var typedAssoc = row.typedAssoc();
        expect(typedAssoc['col_pk'].runtimeType, int);
        expect(typedAssoc['sum_int'].runtimeType, String);
        expect(typedAssoc['max_int'].runtimeType, int);
        expect(typedAssoc['sum_double'].runtimeType, double);
      }
    },
  );

  int stressTestRows = 1000;
  test(
    "stress test: insert $stressTestRows rows",
    () async {
      await conn.execute('TRUNCATE TABLE book');

      final stmt = await conn.prepare(
        'INSERT INTO book (title, price, created_at) VALUES (?, ?, ?)',
      );

      print("Inserting $stressTestRows rows...");

      for (int x = 0; x < stressTestRows; x++) {
        await stmt.execute(
          ['Some title $x', x, '2022-04-02 00:00:00'],
        );
      }

      await stmt.deallocate();

      // check rows
      var result = await conn.execute('SELECT * FROM book', {}, true);

      int receivedRows = 0;

      await for (final _ in result.rowsStream) {
        receivedRows++;
      }

      expect(receivedRows, stressTestRows);
    },
    timeout: Timeout(Duration(seconds: 60)),
  );
}
