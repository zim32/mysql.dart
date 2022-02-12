import 'package:mysql_client/mysql_client.dart';

Future<void> main(List<String> arguments) async {
  print("Connecting to mysql server...");

  // create connections pool
  final conn = await MySQLConnection.createConnection(
    host: "127.0.0.1",
    port: 3306,
    userName: "zim32",
    password: "sikkens",
    databaseName: "zim32_tutorial_symfony_54",
  );

  await conn.connect();

  print("Connected");

  // insert data
  var stmt = await conn.prepare(
    "INSERT INTO book (author_id, title, price, created_at) VALUES (?, ?, ?, ?)",
  );
  await stmt.execute([null, 'Some book', 120, '2022-01-01']);

  // select data
  stmt = await conn.prepare("SELECT * FROM book");
  var result = await stmt.execute([]);

  for (final row in result.rows) {
    print(row.assoc());
  }

  // close all connections
  await conn.close();
}
