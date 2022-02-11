import 'dart:async';

import 'package:mysql_client/mysql_client.dart';

class MySQLConnectionPool {
  final String host;
  final int port;
  final String userName;
  final String _password;
  final int maxConnections;
  final String? databaseName;

  final List<MySQLConnection> _activeConnections = [];
  final List<MySQLConnection> _idleConnections = [];

  MySQLConnectionPool({
    required this.host,
    required this.port,
    required this.userName,
    required password,
    required this.maxConnections,
    this.databaseName,
  }) : _password = password;

  int get activeConnectionsQty => _idleConnections.length;
  int get idleConnectionsQty => _idleConnections.length;
  int get allConnectionsQty => activeConnectionsQty + idleConnectionsQty;

  List<MySQLConnection> get _allConnections =>
      _idleConnections + _activeConnections;

  Future<IResultSet> execute(String query,
      [Map<String, dynamic>? params]) async {
    final conn = await _getFreeConnection();
    final result = await conn.execute(query, params);
    _releaseConnection(conn);
    return result;
  }

  Future<void> close() async {
    for (final conn in _allConnections) {
      await conn.close();
    }
    _idleConnections.clear();
    _activeConnections.clear();
  }

  FutureOr<T> withConnection<T>(
      FutureOr<T> Function(MySQLConnection conn) callback) async {
    final conn = await _getFreeConnection();
    final result = await callback(conn);
    _releaseConnection(conn);
    return result;
  }

  Future<T> transactional<T>(
      FutureOr<T> Function(MySQLConnection conn) callback) async {
    return withConnection((conn) {
      return conn.transactional(callback);
    });
  }

  Future<MySQLConnection> _getFreeConnection() async {
    // if there is idle connection, return it
    if (_idleConnections.isNotEmpty) {
      final conn = _idleConnections.first;
      _idleConnections.remove(conn);
      _activeConnections.add(conn);
      return conn;
    }

    if (allConnectionsQty < maxConnections) {
      final conn = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: userName,
        password: _password,
        databaseName: databaseName,
      );
      await conn.connect();
      _activeConnections.add(conn);

      // remove connection from pool, if connection is closed
      conn.onClose(() {
        _idleConnections.remove(conn);
        _activeConnections.remove(conn);
      });

      return conn;
    } else {
      // wait for idle connection
      await Future.doWhile(() => idleConnectionsQty == 0);
      final conn = _idleConnections.first;
      _idleConnections.remove(conn);
      _activeConnections.add(conn);
      return conn;
    }
  }

  void _releaseConnection(MySQLConnection conn) {
    // remove from active
    _activeConnections.remove(conn);
    _idleConnections.add(conn);
  }
}
