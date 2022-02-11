### Native MySQL client written in Dart for Dart

See [example](example/) directory for examples and usage

### Roadmap

* [x] Auth with mysql_native_password
* [x] Basic connection
* [x] Connection pool
* [x] Query placeholders
* [x] Transactions
* [ ] Prepared statements
* [ ] SSL connection

### Usage

#### Create connection pool

```dart
final pool = MySQLConnectionPool(
    host: '127.0.0.1',
    port: 3306,
    userName: 'your_user',
    password: 'your_password',
    maxConnections: 10,
    databaseName: 'your_database_name', // optional,
  );
```

#### Query database

```dart
var result = await pool.execute("SELECT * FROM book WHERE id = :id", {"id": 1});
```

#### Print result
```dart
  for (final row in result.rows) {
    print(row.assoc());
  }
```


### Tests

To run tests execute

```bash
dart test
```