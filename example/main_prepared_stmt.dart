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

  final stmt = await conn.prepare("SELECT * FROM book");
  print("prepared");
  final result = await stmt.execute([]);
  print("executed");

  for (final row in result.rows) {
    print(row.assoc());
  }

  // close all connections
  // await conn.close();
}
