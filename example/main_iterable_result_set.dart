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

  // make query (notice third parameter, iterable=true)
  var result = await conn.execute("SELECT * FROM book", {}, true);

  // print some result data
  // (numOfRows is not available when using iterable result set)
  print(result.numOfColumns);
  print(result.lastInsertID);
  print(result.affectedRows);

  // get rows, one by one
  result.rowsStream.listen((row) {
    print(row.assoc());
  });

  // close all connections
  await conn.close();
}
