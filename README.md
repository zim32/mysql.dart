### Native MySQL client written in Dart for Dart

See [example](example/) directory for examples and usage

### Roadmap

* [x] Auth with mysql_native_password
* [x] Basic connection
* [x] Connection pool
* [x] Query placeholders
* [x] Transactions
* [x] Prepared statements (real, not emulated)
* [ ] SSL connection
* [ ] Send data in binary form when using prepared stmts (do not convert all into strings)
* [ ] Multiple resul sets

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

### Prepared statements

This library supports real prepared statements (using binary protocol).

#### Prepare statement

```dart
var stmt = await conn.prepare(
  "INSERT INTO book (author_id, title, price, created_at) VALUES (?, ?, ?, ?)",
);
```

#### Execute with params

```dart
await stmt.execute([null, 'Some book 1', 120, '2022-01-01']);
await stmt.execute([null, 'Some book 2', 10, '2022-01-01']);
```

#### Deallocate prepared statement

```dart
await stmt.deallocate();
```

### Tests

To run tests execute

```bash
dart test
```