import 'dart:io';
import 'package:mysql_client/mysql_client.dart';
import 'package:test/test.dart';

void main() {
  final host = '127.0.0.1';
  final port = 3306;
  final user = 'testuser';
  final pass = 'test';
  final db = 'testdb';

  late MySQLConnection conn;

  setUpAll(
    () async {
      stdout.writeln("\n!!!!!!!!!!!!!!!!!!!!!");
      stdout.writeln(
          "Warning this test will execute real queries to database in host: $host, port: $port, dbname: $db. Continue? y/n");
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
        "CREATE DATABASE $db CHARACTER SET utf8 COLLATE utf8_general_ci",
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
      await conn.close();
    },
  );

  test(
    "testing insert",
    () async {
      final result = await conn.execute(
        "INSERT INTO book (author_id, title, price, created_at) VALUES (:author, :title, :price, :created)",
        {
          "author": null,
          "title": "Новая книга",
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
      expect(row.colAt(2), "Новая книга");
      expect(row.colAt(3), "100");
      expect(row.colAt(4), "2020-01-01 01:00:15");
      expect(row.colAt(5), null);
      expect(row.typedColAt<int>(0), 1);
      expect(row.typedColAt<int>(3), 100);
      expect(row.typedColAt<double>(3), 100.00);

      expect(row.colByName('id'), "1");
      expect(row.colByName('author_id'), null);
      expect(row.colByName('title'), "Новая книга");
      expect(row.colByName('price'), "100");
      expect(row.typedColByName<int>('price'), 100);
      expect(row.typedColByName<double>('price'), 100.00);
      expect(row.colByName('created_at'), "2020-01-01 01:00:15");
      expect(row.colByName('some_time'), null);

      expect(row.assoc(), {
        "id": "1",
        "author_id": null,
        "title": "Новая книга",
        "price": "100",
        "created_at": "2020-01-01 01:00:15",
        "some_time": null,
      });

      expect(row.typedAssoc(), {
        "id": 1,
        "author_id": null,
        "title": "Новая книга",
        "price": 100,
        "created_at": "2020-01-01 01:00:15",
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
        expect(e, isA<Exception>());
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
        expect(e, isA<Exception>());
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
        expect(e, isA<Exception>());
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
        expect(e, isA<Exception>());
      }

      // check rows
      result = await conn.execute('SELECT COUNT(id) FROM book');
      expect(result.rows.first.colAt(0), '3');
    },
  );

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
    "stress test: insert 5000 rows",
    () async {
      await conn.execute('TRUNCATE TABLE book');

      final stmt = await conn.prepare(
        'INSERT INTO book (title, price, created_at) VALUES (?, ?, ?)',
      );

      print("Inserting 5000 rows...");

      for (int x = 0; x < 5000; x++) {
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

      expect(receivedRows, 5000);
    },
    timeout: Timeout(Duration(seconds: 60)),
  );
}
