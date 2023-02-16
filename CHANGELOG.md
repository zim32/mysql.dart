## 0.0.28

- Add support for unix socket on pool connection

## 0.0.27

- Add timeoutMs param to pool constructor

## 0.0.26

- Change default charset to ut8mb4 (fix emojies)
- Add **timeoutMs** option to connect() method
- Increase default timeout from 5 seconds to 10 seconds

## 0.0.25

- Add support for unix socket connection. See example/main_unix_socket.dart

## 0.0.24

- Fix colByName and typedColByName: ignore column name case

## 0.0.23

- Fix caching_sha2_password auth plugin

## 0.0.22

- Check server supports SSL
- Add support for multiple statements

## 0.0.21

- Fix _lastError reset in _forceClose() and used after

## 0.0.20

- Refactor error handling
- Add section about error handling to README.md
- Fix connection pool bugs
- Fix mysql protocol string parsing (ascii instead of utf8)

## 0.0.19

- Expose mysql server error code in MySQLServerException

## 0.0.18

- Remove general Exception class. Add custom exception classes

## 0.0.17

- Fix string encoding in prepared statements

## 0.0.16

- Fix in transaction flag

## 0.0.15

- Fix capability flags parsing

## 0.0.14

- Fix prepared statement select with params (handle two EOF packets if numOfCols and numOfParams are both > 0)

## 0.0.13

- Fix decoding long strings

## 0.0.12

- Add info about typed access to readme and examples

## 0.0.11

- Implement typed access to column data
- Add tests

## 0.0.10

- Add more docs and examples

## 0.0.9

- Use utf8 charset by default
- Encode all data using utf8.encode() and utf8.decode()

## 0.0.8

- Improve error handling
- Add handling of incomplete packets in _spliPackets() method
- Fix parameters substitution
- Add mysql_client tests

## 0.0.7

- Add doc comments and example

## 0.0.6

- Implement iterable result sets

## 0.0.5

- Implement caching_sha2_password auth plugin
- Refactor data packets handling
- Split data packets
- Fix some bugs

## 0.0.4

- Implement SSL connection
- Fix bug with hardcoded host and port

## 0.0.3

- Implement prepared statements
- Add more tests

## 0.0.2

- Fix readme and docs

## 0.0.1

- Initial version.
