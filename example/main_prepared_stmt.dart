import 'package:mysql_client/mysql_client.dart';

Future<void> main(List<String> arguments) async {
  print("Connecting to mysql server...");

  // create connection
  final conn = await MySQLConnection.createConnection(
    host: "127.0.0.1",
    port: 3306,
    userName: "your_user",
    password: "your_password",
    databaseName: "your_database_name", // optional
  );

  await conn.connect();

  print("Connected");

  // insert data
  var stmt = await conn.prepare(
    "INSERT INTO book (author_id, title, price, created_at) VALUES (?, ?, ?, ?)",
  );
  await stmt.execute([null, 'Some book 1', 120, '2022-01-01']);
  await stmt.execute([null, 'Some book 2', 10, '2022-01-01']);
  await stmt.deallocate();

  // select data
  stmt = await conn.prepare("SELECT * FROM book");
  var result = await stmt.execute([]);
  await stmt.deallocate();

  for (final row in result.rows) {
    print(row.assoc());
  }

  // close all connections
  await conn.close();
}
