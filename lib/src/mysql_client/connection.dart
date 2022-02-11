import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:buffer/buffer.dart';
import 'package:mysql_client/mysql_protocol.dart';
import 'package:mysql_client/mysql_protocol_extension.dart';
import 'package:tuple/tuple.dart';

enum _MySQLConnectionState {
  fresh,
  waitInitialHandshake,
  initialHandshakeResponseSend,
  connectionEstablished,
  waitingCommandResponse,
  quitCommandSend,
}

class MySQLConnection {
  final Socket _socket;
  bool _connected = false;
  StreamSubscription<Uint8List>? _socketSubscription;
  _MySQLConnectionState _state = _MySQLConnectionState.fresh;
  final String _username;
  final String _password;
  final String? _databaseName;
  void Function(Uint8List data)? _responseCallback;
  final List<void Function()> _onCloseCallbacks = [];
  bool _inTransaction = false;

  MySQLConnection._({
    required Socket socket,
    required String username,
    required String password,
    String? databaseName,
  })  : _socket = socket,
        _username = username,
        _password = password,
        _databaseName = databaseName;

  static Future<MySQLConnection> createConnection({
    required String host,
    required int port,
    required String userName,
    required String password,
    String? databaseName,
  }) async {
    final socket = await Socket.connect("0.0.0.0", 3306);

    final client = MySQLConnection._(
      socket: socket,
      username: userName,
      password: password,
      databaseName: databaseName,
    );

    return client;
  }

  bool get connected {
    return _connected;
  }

  void onClose(void Function() callback) {
    _onCloseCallbacks.add(callback);
  }

  Future<void> connect({int timeoutMs = 5000}) async {
    if (_state != _MySQLConnectionState.fresh) {
      throw Exception("Can not connect: status is not fresh");
    }

    _state = _MySQLConnectionState.waitInitialHandshake;

    _socketSubscription = _socket.listen((data) {
      _processSocketData(data);
    });

    _socketSubscription!.onDone(() {
      _handleSocketClose();
    });

    await Future.doWhile(() async {
      if (_state == _MySQLConnectionState.connectionEstablished) {
        return false;
      }
      await Future.delayed(Duration(milliseconds: 100));
      return true;
    }).timeout(Duration(
      milliseconds: timeoutMs,
    ));
  }

  void _handleSocketClose() {
    _connected = false;
    _socket.destroy();

    for (var element in _onCloseCallbacks) {
      element();
    }
    _onCloseCallbacks.clear();
  }

  void _processSocketData(Uint8List data) {
    if (_state == _MySQLConnectionState.waitInitialHandshake) {
      _processInitialHandshake(data);
      return;
    }

    if (_state == _MySQLConnectionState.initialHandshakeResponseSend) {
      final packet = MySQLPacket.decodeGenericPacket(data);

      if (packet.isErrorPacket()) {
        final errorPayload = packet.payload as MySQLPacketError;
        throw Exception("MySQL error: ${errorPayload.errorMessage}");
      }

      if (packet.isOkPacket()) {
        _state = _MySQLConnectionState.connectionEstablished;
        _connected = true;
      }

      return;
    }

    if (_state == _MySQLConnectionState.waitingCommandResponse) {
      _processCommandResponse(data);
    }
  }

  void _processInitialHandshake(Uint8List data) {
    final packet = MySQLPacket.decodeInitialHandshake(data);

    final payload = packet.payload;

    if (payload is! MySQLPacketInitialHandshake) {
      throw Exception("Expected MySQLPacketInitialHandshake packet");
    }

    final authPluginName = payload.authPluginName;

    switch (authPluginName) {
      case 'mysql_native_password':
        final responsePayload =
            MySQLPacketHandshakeResponse41.createWithNativePassword(
          username: _username,
          password: _password,
          initialHandshakePayload: payload,
        );

        responsePayload.database = _databaseName;

        final responsePacket = MySQLPacket(
          payload: responsePayload,
          sequenceID: 1,
          payloadLength: 0,
        );

        _state = _MySQLConnectionState.initialHandshakeResponseSend;
        _socket.add(responsePacket.encode());
        break;
      default:
        throw Exception("Unsupported auth plugin name: $authPluginName");
    }
  }

  void _processCommandResponse(Uint8List data) {
    if (_responseCallback != null) {
      _responseCallback!(data);
    }
  }

  Future<IResultSet> execute(String query,
      [Map<String, dynamic>? params]) async {
    if (!_connected) {
      throw Exception("Can not execute query: connecion closed");
    }

    // wait for ready state
    if (_state != _MySQLConnectionState.connectionEstablished) {
      await _waitForState(_MySQLConnectionState.connectionEstablished)
          .timeout(Duration(seconds: 10));
    }

    _state = _MySQLConnectionState.waitingCommandResponse;

    if (params != null && params.isNotEmpty) {
      query = _substitureParams(query, params);
    }

    final payload = MySQLPacketCommQuery(query: query);

    final packet = MySQLPacket(
      sequenceID: 0,
      payload: payload,
      payloadLength: 0,
    );

    final completer = Completer<IResultSet>();

    _responseCallback = (data) {
      final packet = MySQLPacket.decodeCommQueryResponsePacket(data);
      final payload = packet.payload;
      _state = _MySQLConnectionState.connectionEstablished;

      if (payload is MySQLPacketError) {
        completer.completeError("MySQL error: " + payload.errorMessage);
        return;
      } else if (payload is MySQLPacketOK) {
        completer.complete(EmptyResultSet(okPacket: payload));
        return;
      } else if (payload is MySQLPacketResultSet) {
        completer.complete(ResultSet._(resultSetPacket: payload));
        return;
      } else {
        completer.completeError(
          "Unexpected payload received in response to COMM_QUERY request",
        );
      }
    };

    _socket.add(packet.encode());

    return completer.future;
  }

  Future<T> transactional<T>(
      FutureOr<T> Function(MySQLConnection conn) callback) async {
    // prevent double transaction
    if (_inTransaction) {
      throw Exception("Already in transaction");
    }
    _inTransaction = true;

    await execute("START TRANSACTION");

    try {
      final result = await callback(this);
      await execute("COMMIT");
      return result;
    } catch (e) {
      await execute("ROLLBACK");
      _inTransaction = false;
      rethrow;
    }
  }

  String _substitureParams(String query, Map<String, dynamic> params) {
    for (final param in params.entries) {
      String value;

      if (param.value is String) {
        value = "'" + _escapeString(param.value) + "'";
      } else if (param.value is num) {
        value = param.value.toString();
      } else if (param.value is bool) {
        value = param.value ? "TRUE" : "FALSE";
      } else {
        value = "'" + _escapeString(param.value.toString()) + "'";
      }

      query = query.replaceAll(":" + param.key, value);
    }

    return query;
  }

  Future<PreparedStmt> prepare(String query) async {
    if (!_connected) {
      throw Exception("Can not prepare stmt: connecion closed");
    }

    // wait for ready state
    if (_state != _MySQLConnectionState.connectionEstablished) {
      await _waitForState(_MySQLConnectionState.connectionEstablished)
          .timeout(Duration(seconds: 10));
    }

    _state = _MySQLConnectionState.waitingCommandResponse;

    final payload = MySQLPacketCommStmtPrepare(query: query);

    final packet = MySQLPacket(
      sequenceID: 0,
      payload: payload,
      payloadLength: 0,
    );

    final completer = Completer<PreparedStmt>();

    _responseCallback = (data) {
      final packet = MySQLPacket.decodeCommPrepareStmtResponsePacket(data);
      final payload = packet.payload;
      _state = _MySQLConnectionState.connectionEstablished;

      if (payload is MySQLPacketError) {
        completer.completeError("MySQL error: " + payload.errorMessage);
        return;
      } else if (payload is MySQLPacketStmtPrepareOK) {
        completer.complete(PreparedStmt._(
          preparedPacket: payload,
          connection: this,
        ));
        return;
      } else {
        completer.completeError(
          "Unexpected payload received in response to COM_STMT_PREPARE request",
        );
      }
    };

    _socket.add(packet.encode());

    return completer.future;
  }

  Future<IResultSet> _executePreparedStmt(
    PreparedStmt stmt,
    List<dynamic> params,
  ) async {
    if (!_connected) {
      throw Exception("Can not execute prepared stmt: connecion closed");
    }

    // wait for ready state
    if (_state != _MySQLConnectionState.connectionEstablished) {
      await _waitForState(_MySQLConnectionState.connectionEstablished)
          .timeout(Duration(seconds: 10));
    }

    _state = _MySQLConnectionState.waitingCommandResponse;

    // prepare params
    List<Tuple2<int, Uint8List>> binaryParams = []; // (type, value)
    for (final param in params) {
      // convert all to string
      final String value = param.toString();
      final byteWriter = ByteDataWriter(endian: Endian.little);
      byteWriter.writeVariableEncInt(value.length);
      byteWriter.write(value.codeUnits);
      binaryParams.add(Tuple2(mysqlColumnTypeVarString, byteWriter.toBytes()));
    }

    final payload = MySQLPacketCommStmtExecute(
      stmtID: stmt._preparedPacket.stmtID,
      params: binaryParams,
    );

    final packet = MySQLPacket(
      sequenceID: 0,
      payload: payload,
      payloadLength: 0,
    );

    final completer = Completer<IResultSet>();

    _responseCallback = (data) {
      final packet = MySQLPacket.decodeCommPrepareStmtExecResponsePacket(data);
      final payload = packet.payload;
      _state = _MySQLConnectionState.connectionEstablished;

      if (payload is MySQLPacketError) {
        completer.completeError("MySQL error: " + payload.errorMessage);
        return;
      } else if (payload is MySQLPacketBinaryResultSet) {
        completer.complete(PreparedStmtResultSet._(resultSetPacket: payload));
        return;
      } else {
        completer.completeError(
          "Unexpected payload received in response to COM_STMT_EXEC request",
        );
      }
    };

    _socket.add(packet.encode());

    return completer.future;
  }

  String _escapeString(String value) {
    value = value.replaceAll(r"\", r'\\');
    value = value.replaceAll(r"'", r"''");
    return value;
  }

  Future<void> close() async {
    final packet = MySQLPacket(
      sequenceID: 0,
      payload: MySQLPacketCommQuit(),
      payloadLength: 0,
    );

    _socket.add(packet.encode());
    _state = _MySQLConnectionState.quitCommandSend;

    if (_socketSubscription != null) {
      await _socketSubscription!.cancel();
    }

    _connected = false;
    await _socket.flush();
    await Future.delayed(Duration(milliseconds: 10));
    await _socket.close();
    _socket.destroy();

    for (var element in _onCloseCallbacks) {
      element();
    }
    _onCloseCallbacks.clear();
  }

  Future<void> _waitForState(_MySQLConnectionState state) async {
    if (_state == state) {
      return;
    }

    await Future.doWhile(() async {
      if (_state == state) {
        return false;
      }

      await Future.delayed(Duration(microseconds: 100));
      return true;
    });
  }
}

abstract class IResultSet {
  int get numOfColumns;
  int get numOfRows;
  BigInt get affectedRows;
  BigInt get lastInsertID;
  Iterable<ResultSetRow> get rows;
  Iterable<ResultSetColumn> get cols;
}

class ResultSet implements IResultSet {
  final MySQLPacketResultSet _resultSetPacket;

  ResultSet._({
    required MySQLPacketResultSet resultSetPacket,
  }) : _resultSetPacket = resultSetPacket;

  @override
  int get numOfColumns => _resultSetPacket.columns.length;

  @override
  int get numOfRows => _resultSetPacket.rows.length;

  @override
  BigInt get affectedRows => BigInt.zero;

  @override
  BigInt get lastInsertID => BigInt.zero;

  @override
  Iterable<ResultSetRow> get rows sync* {
    for (final _row in _resultSetPacket.rows) {
      yield ResultSetRow._(
        colDefs: _resultSetPacket.columns,
        values: _row.values,
      );
    }
  }

  @override
  Iterable<ResultSetColumn> get cols {
    return _resultSetPacket.columns.map(
      (e) => ResultSetColumn(
        name: e.name,
        type: e.type,
      ),
    );
  }
}

class PreparedStmtResultSet implements IResultSet {
  final MySQLPacketBinaryResultSet _resultSetPacket;

  PreparedStmtResultSet._({
    required MySQLPacketBinaryResultSet resultSetPacket,
  }) : _resultSetPacket = resultSetPacket;

  @override
  int get numOfColumns => _resultSetPacket.columns.length;

  @override
  int get numOfRows => _resultSetPacket.rows.length;

  @override
  BigInt get affectedRows => BigInt.zero;

  @override
  BigInt get lastInsertID => BigInt.zero;

  @override
  Iterable<ResultSetRow> get rows sync* {
    for (final _row in _resultSetPacket.rows) {
      yield ResultSetRow._(
        colDefs: _resultSetPacket.columns,
        values: _row.values,
      );
    }
  }

  @override
  Iterable<ResultSetColumn> get cols {
    return _resultSetPacket.columns.map(
      (e) => ResultSetColumn(
        name: e.name,
        type: e.type,
      ),
    );
  }
}

class EmptyResultSet implements IResultSet {
  final MySQLPacketOK _okPacket;

  EmptyResultSet({required MySQLPacketOK okPacket}) : _okPacket = okPacket;

  @override
  int get numOfColumns => 0;

  @override
  int get numOfRows => 0;

  @override
  BigInt get affectedRows => _okPacket.affectedRows;

  @override
  BigInt get lastInsertID => _okPacket.lastInsertID;

  @override
  Iterable<ResultSetRow> get rows => List<ResultSetRow>.empty();

  @override
  Iterable<ResultSetColumn> get cols => List<ResultSetColumn>.empty();
}

class ResultSetRow {
  final List<MySQLColumnDefinitionPacket> _colDefs;
  final List<String?> _values;

  ResultSetRow._({
    required List<MySQLColumnDefinitionPacket> colDefs,
    required List<String?> values,
  })  : _colDefs = colDefs,
        _values = values;

  int get numOfColumns => _colDefs.length;

  String colAt(int colIndex) {
    if (colIndex >= _values.length) {
      throw Exception("Column index is out of range");
    }

    final value = _values[colIndex]!;

    return value;
  }

  String colByName(String columnName) {
    final colIndex =
        _colDefs.indexWhere((element) => element.name == columnName);

    if (colIndex == -1) {
      throw Exception("There is no column with name: $columnName");
    }

    if (colIndex >= _values.length) {
      throw Exception("Column index is out of range");
    }

    final value = _values[colIndex]!;

    return value;
  }

  Map<String, String?> assoc() {
    final result = <String, String?>{};

    int colIndex = 0;

    for (final colDef in _colDefs) {
      result[colDef.name] = _values[colIndex];
      colIndex++;
    }

    return result;
  }
}

class ResultSetColumn {
  String name;
  int type;

  ResultSetColumn({
    required this.name,
    required this.type,
  });
}

class PreparedStmt {
  MySQLPacketStmtPrepareOK _preparedPacket;
  MySQLConnection _connection;

  PreparedStmt._({
    required MySQLPacketStmtPrepareOK preparedPacket,
    required MySQLConnection connection,
  })  : _preparedPacket = preparedPacket,
        _connection = connection;

  int get numOfParams => _preparedPacket.numOfParams;

  Future<IResultSet> execute(List<dynamic> params) async {
    if (numOfParams != params.length) {
      throw Exception(
        "Can not execute prepared stmt: number of passed params != number of prepared params",
      );
    }

    return _connection._executePreparedStmt(this, params);
  }
}
