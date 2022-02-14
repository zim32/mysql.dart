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

  // update some rows
  var res = await conn.execute(
    "UPDATE book SET price = :price",
    {"price": 200},
  );

  print(res.affectedRows);

  // make query
  var result = await conn.execute("SELECT * FROM book");

  // print some result data
  print(result.numOfColumns);
  print(result.numOfRows);
  print(result.lastInsertID);
  print(result.affectedRows);

  // print query result
  for (final row in result.rows) {
    // print(row.colAt(0));
    // print(row.colByName("title"));

    // print all rows as Map<String, String>
    print(row.assoc());
  }

  // close all connections
  await conn.close();
}
