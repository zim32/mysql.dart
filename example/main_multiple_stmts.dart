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

  final resultSets = await conn.execute(
    "SELECT 1 as val_1_1; SELECT 2 as val_2_1, 3 as val_2_2",
  );

  assert(resultSets.next != null);

  for (final result in resultSets) {
    // for every result set
    for (final row in result.rows) {
      // for every row in result set
      print(row.assoc());
    }
  }

  // close all connections
  await conn.close();
}
