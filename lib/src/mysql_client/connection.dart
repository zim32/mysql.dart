import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:mysql_client/mysql_protocol.dart';
import 'package:mysql_client/exception.dart';

enum _MySQLConnectionState {
  fresh,
  waitInitialHandshake,
  initialHandshakeResponseSend,
  connectionEstablished,
  waitingCommandResponse,
  quitCommandSend,
  closed
}

/// Main class to interact with MySQL database
///
/// Use [MySQLConnection.createConnection] to create connection
class MySQLConnection {
  Socket _socket;
  bool _connected = false;
  StreamSubscription<Uint8List>? _socketSubscription;
  _MySQLConnectionState _state = _MySQLConnectionState.fresh;
  final String _username;
  final String _password;
  final String _collation;
  final String? _databaseName;
  Future<void> Function(Uint8List data)? _responseCallback;
  final List<void Function()> _onCloseCallbacks = [];
  bool _inTransaction = false;
  final bool _secure;
  final List<int> _incompleteBufferData = [];
  Object? _lastError;
  int _serverCapabilities = 0;
  String? _activeAuthPluginName;
  int _timeoutMs = 10000;

  MySQLConnection._({
    required Socket socket,
    required String username,
    required String password,
    required String collation,
    bool secure = true,
    String? databaseName,
  })  : _socket = socket,
        _username = username,
        _password = password,
        _databaseName = databaseName,
        _secure = secure,
        _collation = collation;

  /// Creates connection with provided options.
  ///
  /// Keep in mind, **this is async** function. So you need to await result.
  /// Don't forget to call [MySQLConnection.connect] to actually connect to database, or you will get errors.
  /// See examples directory for code samples.
  ///
  /// [host] host to connect to. Can be String or InternetAddress.
  /// [userName] database user name.
  /// [password] user password.
  /// [secure] If true - TLS will be used, if false - ordinary TCL connection.
  /// [databaseName] Optional database name to connect to.
  /// [collation] Optional collaction to use.
  ///
  /// By default after connection is established, this library executes query to switch connection charset and collation:
  ///
  /// ```
  /// SET @@collation_connection=$_collation, @@character_set_client=utf8mb4, @@character_set_connection=utf8mb4, @@character_set_results=utf8mb4
  /// ```
  static Future<MySQLConnection> createConnection({
    required dynamic host,
    required int port,
    required String userName,
    required String password,
    bool secure = true,
    String? databaseName,
    String collation = 'utf8mb4_general_ci',
  }) async {
    final Socket socket = await Socket.connect(host, port);

    if (socket.address.type != InternetAddressType.unix) {
      // no support for extensions on sockets
      socket.setOption(SocketOption.tcpNoDelay, true);
    }

    final client = MySQLConnection._(
      socket: socket,
      username: userName,
      password: password,
      databaseName: databaseName,
      secure: secure,
      collation: collation,
    );

    return client;
  }

  /// Returns true if this connection can be used to interact with database
  bool get connected {
    return _connected;
  }

  /// Registers callack to be executed when this connection is closed
  void onClose(void Function() callback) {
    _onCloseCallbacks.add(callback);
  }

  /// Initiate connection to database. To close connection, invoke [MySQLConnection.close] method.
  ///
  /// Default [timeoutMs] is 10000 milliseconds
  Future<void> connect({int timeoutMs = 10000}) async {
    if (_state != _MySQLConnectionState.fresh) {
      throw MySQLClientException("Can not connect: status is not fresh");
    }

    _timeoutMs = timeoutMs;

    _state = _MySQLConnectionState.waitInitialHandshake;

    _socketSubscription = _socket.listen((data) {
      for (final chunk in _splitPackets(data)) {
        _processSocketData(chunk)
            .onError((error, stackTrace) => _lastError = error);
      }
    });

    _socketSubscription!.onDone(() {
      _handleSocketClose();
    });

    // wait for connection established
    await Future.doWhile(() async {
      if (_lastError != null) {
        final err = _lastError;
        _forceClose();
        throw err!;
      }

      if (_state == _MySQLConnectionState.connectionEstablished) {
        return false;
      }

      await Future.delayed(Duration(milliseconds: 100));

      return true;
    }).timeout(Duration(
      milliseconds: timeoutMs,
    ));

    // set connection charset
    await execute(
      'SET @@collation_connection=$_collation, @@character_set_client=utf8mb4, @@character_set_connection=utf8mb4, @@character_set_results=utf8mb4',
    );
  }

  void _handleSocketClose() {
    _connected = false;
    _socket.destroy();

    for (var element in _onCloseCallbacks) {
      element();
    }
    _onCloseCallbacks.clear();
  }

  Future<void> _processSocketData(Uint8List data) async {
    if (_state == _MySQLConnectionState.closed) {
      // don't process any data if state is closed
      return;
    }

    if (_state == _MySQLConnectionState.waitInitialHandshake) {
      await _processInitialHandshake(data);
      return;
    }

    if (_state == _MySQLConnectionState.initialHandshakeResponseSend) {
      // check for auth switch request
      try {
        final authSwitchPacket =
            MySQLPacket.decodeAuthSwitchRequestPacket(data);

        final payload =
            authSwitchPacket.payload as MySQLPacketAuthSwitchRequest;

        _activeAuthPluginName = payload.authPluginName;

        switch (payload.authPluginName) {
          case 'mysql_native_password':
            final responsePayload =
                MySQLPacketAuthSwitchResponse.createWithNativePassword(
              password: _password,
              challenge: payload.authPluginData.sublist(0, 20),
            );
            final responsePacket = MySQLPacket(
              sequenceID: authSwitchPacket.sequenceID + 1,
              payload: responsePayload,
              payloadLength: 0,
            );

            _socket.add(responsePacket.encode());
            return;
          default:
            throw MySQLClientException(
                "Unsupported auth plugin name: ${payload.authPluginName}");
        }
      } catch (e) {
        // not auth switch request packet, continue packet processing
      }

      MySQLPacket packet;

      try {
        packet = MySQLPacket.decodeGenericPacket(data);
      } catch (e) {
        rethrow;
      }

      if (packet.payload is MySQLPacketExtraAuthData) {
        assert(_activeAuthPluginName != null);

        if (_activeAuthPluginName != 'caching_sha2_password') {
          throw MySQLClientException(
              "Unexpected auth plugin name $_activeAuthPluginName, while receiving MySQLPacketExtraAuthData packet");
        }

        if (_secure == false) {
          throw MySQLClientException(
              "Auth plugin caching_sha2_password is supported only with secure connections. Pass secure: true or use another auth method");
        }

        final payload = packet.payload as MySQLPacketExtraAuthData;
        final status = payload.pluginData.codeUnitAt(0);

        if (status == 3) {
          // server has password cache. just ignore
          return;
        } else if (status == 4) {
          // send password to the server
          final authExtraDataResponse = MySQLPacket(
            sequenceID: packet.sequenceID + 1,
            payload: MySQLPacketExtraAuthDataResponse(
              data: Uint8List.fromList(utf8.encode(_password)),
            ),
            payloadLength: 0,
          );

          _socket.add(authExtraDataResponse.encode());
          return;
        } else {
          throw MySQLClientException("Unsupported extra auth data: $data");
        }
      }

      if (packet.isErrorPacket()) {
        final errorPayload = packet.payload as MySQLPacketError;
        throw MySQLServerException(
            errorPayload.errorMessage, errorPayload.errorCode);
      }

      if (packet.isOkPacket()) {
        _state = _MySQLConnectionState.connectionEstablished;
        _connected = true;
      }

      return;
    }

    if (_state == _MySQLConnectionState.waitingCommandResponse) {
      _processCommandResponse(data);
      return;
    }

    throw MySQLClientException(
      "Skipping socket data, because of connection bad state\nState: ${_state.name}\nData: $data",
    );
  }

  Iterable<Uint8List> _splitPackets(Uint8List data) sync* {
    if (_incompleteBufferData.isNotEmpty) {
      final tmp = Uint8List.fromList(_incompleteBufferData + data.toList());
      data = tmp;
      _incompleteBufferData.clear();
    }

    Uint8List view = data;

    while (true) {
      // if packet size is less then 4 bytes, we can not even detect payload length and total packet size
      // so just append data to incomplete buffer
      if (view.length < 4) {
        _incompleteBufferData.addAll(view);
        break;
      }

      final packetLength = MySQLPacket.getPacketLength(view);

      if (view.lengthInBytes < packetLength) {
        // incomplete packet
        _incompleteBufferData.addAll(view);
        break;
      }

      final chunk = Uint8List.sublistView(view, 0, packetLength);

      yield chunk;

      view = Uint8List.sublistView(view, packetLength);

      if (view.isEmpty) {
        break;
      }
    }
  }

  Future<void> _processInitialHandshake(Uint8List data) async {
    // First packet can be error packet
    if (MySQLPacket.detectPacketType(data) == MySQLGenericPacketType.error) {
      final packet = MySQLPacket.decodeGenericPacket(data);
      final payload = packet.payload as MySQLPacketError;
      throw MySQLServerException(payload.errorMessage, payload.errorCode);
    }

    final packet = MySQLPacket.decodeInitialHandshake(data);
    final payload = packet.payload;

    if (payload is! MySQLPacketInitialHandshake) {
      throw MySQLClientException("Expected MySQLPacketInitialHandshake packet");
    }

    _serverCapabilities = payload.capabilityFlags;

    if (_secure && (_serverCapabilities & mysqlCapFlagClientSsl == 0)) {
      throw MySQLClientException(
        "Server does not support SSL connection. Pass secure: false to createConnection or enable SSL support",
      );
    }

    if (_secure) {
      // it secure = true, initiate ssl connection
      Future<void> initiateSSL() async {
        final responsePayload = MySQLPacketSSLRequest.createDefault(
          initialHandshakePayload: payload,
          connectWithDB: _databaseName != null,
        );

        final responsePacket = MySQLPacket(
          sequenceID: 1,
          payload: responsePayload,
          payloadLength: 0,
        );

        _socket.add(responsePacket.encode());

        _socketSubscription?.pause();

        final secureSocket = await SecureSocket.secure(
          _socket,
          onBadCertificate: (certificate) => true,
        );

        // switch socket
        _socket = secureSocket;

        _socketSubscription = _socket.listen((data) {
          for (final chunk in _splitPackets(data)) {
            _processSocketData(chunk)
                .onError((error, stackTrace) => _lastError = error);
          }
        });

        _socketSubscription!.onDone(() {
          _handleSocketClose();
        });
      }

      await initiateSSL();
    }

    final authPluginName = payload.authPluginName;
    _activeAuthPluginName = authPluginName;

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
          sequenceID: _secure ? 2 : 1,
          payloadLength: 0,
        );

        _state = _MySQLConnectionState.initialHandshakeResponseSend;
        _socket.add(responsePacket.encode());
        break;
      case 'caching_sha2_password':
        final responsePayload =
            MySQLPacketHandshakeResponse41.createWithCachingSha2Password(
          username: _username,
          password: _password,
          initialHandshakePayload: payload,
        );

        responsePayload.database = _databaseName;

        final responsePacket = MySQLPacket(
          payload: responsePayload,
          sequenceID: _secure ? 2 : 1,
          payloadLength: 0,
        );

        _state = _MySQLConnectionState.initialHandshakeResponseSend;
        _socket.add(responsePacket.encode());
        break;
      default:
        throw MySQLClientException(
            "Unsupported auth plugin name: $authPluginName");
    }
  }

  void _processCommandResponse(Uint8List data) {
    assert(_responseCallback != null);
    _responseCallback!(data);
  }

  /// Executes given [query]
  ///
  /// [execute] can be used to make any query type (SELECT, INSERT, UPDATE)
  /// You can pass named parameters using [params]
  /// Pass [iterable] true if you want to receive rows one by one in Stream fashion
  Future<IResultSet> execute(
    String query, [
    Map<String, dynamic>? params,
    bool iterable = false,
  ]) async {
    if (!_connected) {
      throw MySQLClientException("Can not execute query: connection closed");
    }

    // wait for ready state
    if (_state != _MySQLConnectionState.connectionEstablished) {
      await _waitForState(_MySQLConnectionState.connectionEstablished)
          .timeout(Duration(milliseconds: _timeoutMs));
    }

    _state = _MySQLConnectionState.waitingCommandResponse;

    if (params != null && params.isNotEmpty) {
      try {
        query = _substitureParams(query, params);
      } catch (e) {
        _state = _MySQLConnectionState.connectionEstablished;
        rethrow;
      }
    }

    final payload = MySQLPacketCommQuery(query: query);

    final packet = MySQLPacket(
      sequenceID: 0,
      payload: payload,
      payloadLength: 0,
    );

    final completer = Completer<IResultSet>();

    /**
     * 0 - initial
     * 1 - columnCount decoded
     * 2 - columnDefs parsed
     * 3 - eofParsed
     * 4 - rowsParsed
     */
    int state = 0;
    int colsCount = 0;
    List<MySQLColumnDefinitionPacket> colDefs = [];
    List<MySQLResultSetRowPacket> resultSetRows = [];

    // support for iterable result set
    IterableResultSet? iterableResultSet;
    StreamSink<ResultSetRow>? sink;

    // used as a pointer to handle multiple result sets
    IResultSet? currentResultSet;
    IResultSet? firstResultSet;

    _responseCallback = (data) async {
      try {
        MySQLPacket? packet;

        switch (state) {
          case 0:
            // if packet is OK packet, there is no data
            if (MySQLPacket.detectPacketType(data) ==
                MySQLGenericPacketType.ok) {
              final okPacket = MySQLPacket.decodeGenericPacket(data);
              _state = _MySQLConnectionState.connectionEstablished;
              completer.complete(
                EmptyResultSet(okPacket: okPacket.payload as MySQLPacketOK),
              );

              return;
            }

            packet = MySQLPacket.decodeColumnCountPacket(data);
            break;
          case 1:
            packet = MySQLPacket.decodeColumnDefPacket(data);
            break;
          case 2:
            packet = MySQLPacket.decodeGenericPacket(data);
            if (packet.isEOFPacket()) {
              state = 3;
            }
            break;
          case 3:
            if (iterable) {
              if (iterableResultSet == null) {
                iterableResultSet = IterableResultSet._(
                  columns: colDefs,
                );

                sink = iterableResultSet!._sink;
                completer.complete(iterableResultSet);
              }

              // check eof
              if (MySQLPacket.detectPacketType(data) ==
                  MySQLGenericPacketType.eof) {
                state = 4;

                _state = _MySQLConnectionState.connectionEstablished;
                await sink!.close();
                return;
              }

              packet = MySQLPacket.decodeResultSetRowPacket(data, colsCount);
              final values = (packet.payload as MySQLResultSetRowPacket).values;
              sink!.add(ResultSetRow._(colDefs: colDefs, values: values));
              packet = null;
              break;
            } else {
              // check eof
              if (MySQLPacket.detectPacketType(data) ==
                  MySQLGenericPacketType.eof) {
                final resultSetPacket = MySQLPacketResultSet(
                  columnCount: BigInt.from(colsCount),
                  columns: colDefs,
                  rows: resultSetRows,
                );

                final resultSet = ResultSet._(resultSetPacket: resultSetPacket);

                if (currentResultSet != null) {
                  currentResultSet!.next = resultSet;
                } else {
                  firstResultSet = resultSet;
                }
                currentResultSet = resultSet;

                final eofPacket = MySQLPacket.decodeGenericPacket(data);
                final eofPayload = eofPacket.payload as MySQLPacketEOF;

                if (eofPayload.statusFlags & mysqlServerFlagMoreResultsExists !=
                    0) {
                  state = 0;
                  colsCount = 0;
                  colDefs = [];
                  resultSetRows = [];
                  return;
                } else {
                  // there is no more results, just return
                  state = 4;
                  _state = _MySQLConnectionState.connectionEstablished;
                  completer.complete(firstResultSet);
                  return;
                }
              }

              packet = MySQLPacket.decodeResultSetRowPacket(data, colsCount);
              break;
            }
        }

        if (packet != null) {
          final payload = packet.payload;

          if (payload is MySQLPacketError) {
            completer.completeError(
              MySQLServerException(payload.errorMessage, payload.errorCode),
            );
            _state = _MySQLConnectionState.connectionEstablished;
            return;
          } else if (payload is MySQLPacketOK || payload is MySQLPacketEOF) {
            // do nothing
          } else if (payload is MySQLPacketColumnCount) {
            state = 1;
            colsCount = payload.columnCount.toInt();
            return;
          } else if (payload is MySQLColumnDefinitionPacket) {
            colDefs.add(payload);
            if (colDefs.length == colsCount) {
              state = 2;
            }
          } else if (payload is MySQLResultSetRowPacket) {
            assert(iterable == false);
            resultSetRows.add(payload);
          } else {
            completer.completeError(
              MySQLClientException(
                "Unexpected payload received in response to COMM_QUERY request",
              ),
              StackTrace.current,
            );
            _forceClose();
            return;
          }
        }
      } catch (e) {
        completer.completeError(e, StackTrace.current);
        _forceClose();
      }
    };

    _socket.add(packet.encode());

    return completer.future;
  }

  /// Execute [callback] inside database transaction
  ///
  /// If MySQLClientException is thrown inside [callback] function, transaction is rolled back
  Future<T> transactional<T>(
      FutureOr<T> Function(MySQLConnection conn) callback) async {
    // prevent double transaction
    if (_inTransaction) {
      throw MySQLClientException("Already in transaction");
    }
    _inTransaction = true;

    await execute("START TRANSACTION");

    try {
      final result = await callback(this);
      await execute("COMMIT");
      _inTransaction = false;
      return result;
    } catch (e) {
      await execute("ROLLBACK");
      _inTransaction = false;
      rethrow;
    }
  }

  String _substitureParams(String query, Map<String, dynamic> params) {
    // convert params to string
    Map<String, String> convertedParams = {};

    for (final param in params.entries) {
      String value;

      if (param.value == null) {
        value = "NULL";
      } else if (param.value is String) {
        value = "'" + _escapeString(param.value) + "'";
      } else if (param.value is num) {
        value = param.value.toString();
      } else if (param.value is bool) {
        value = param.value ? "TRUE" : "FALSE";
      } else {
        value = "'" + _escapeString(param.value.toString()) + "'";
      }

      convertedParams[param.key] = value;
    }

    // find all :placeholders, which can be substituted
    final pattern = RegExp(r":(\w+)");

    final matches = pattern.allMatches(query).where((match) {
      final subString = query.substring(0, match.start);

      int count = "'".allMatches(subString).length;
      if (count > 0 && count.isOdd) {
        return false;
      }

      count = '"'.allMatches(subString).length;
      if (count > 0 && count.isOdd) {
        return false;
      }

      return true;
    }).toList();

    int lengthShift = 0;

    for (final match in matches) {
      final paramName = match.group(1);

      // check param exists
      if (false == convertedParams.containsKey(paramName)) {
        throw MySQLClientException(
            "There is no parameter with name: $paramName");
      }

      final newQuery = query.replaceFirst(
        match.group(0)!,
        convertedParams[paramName]!,
        match.start + lengthShift,
      );

      lengthShift += newQuery.length - query.length;
      query = newQuery;
    }

    return query;
  }

  /// Prepares given [query]
  ///
  /// Returns [PreparedStmt] which can be used to execute prepared statement multiple times with different parameters
  /// See [PreparedStmt.execute]
  /// You shoud call [PreparedStmt.deallocate] when you don't need prepared statement anymore to prevent memory leaks
  ///
  /// Pass [iterable] true if you want to iterable result set. See [execute] for details
  Future<PreparedStmt> prepare(String query, [bool iterable = false]) async {
    if (!_connected) {
      throw MySQLClientException("Can not prepare stmt: connection closed");
    }

    // wait for ready state
    if (_state != _MySQLConnectionState.connectionEstablished) {
      await _waitForState(_MySQLConnectionState.connectionEstablished)
          .timeout(Duration(milliseconds: _timeoutMs));
    }

    _state = _MySQLConnectionState.waitingCommandResponse;

    final payload = MySQLPacketCommStmtPrepare(query: query);

    final packet = MySQLPacket(
      sequenceID: 0,
      payload: payload,
      payloadLength: 0,
    );

    final completer = Completer<PreparedStmt>();

    /**
     * 0 - initial
     * 1 - first packet decoded
     * 2 - eof decoded
     */
    int state = 0;
    int numOfEofPacketsParsed = 0;
    MySQLPacketStmtPrepareOK? preparedPacket;

    _responseCallback = (data) async {
      try {
        MySQLPacket? packet;

        switch (state) {
          case 0:
            packet = MySQLPacket.decodeCommPrepareStmtResponsePacket(data);
            state = 1;
            break;
          default:
            packet = null;

            if (MySQLPacket.detectPacketType(data) ==
                MySQLGenericPacketType.eof) {
              numOfEofPacketsParsed++;

              var done = false;

              assert(preparedPacket != null);

              if (preparedPacket!.numOfCols > 0 &&
                  preparedPacket!.numOfParams > 0) {
                // there should be two EOF packets in this case
                if (numOfEofPacketsParsed == 2) {
                  done = true;
                }
              } else {
                // there should be only one EOF packet otherwise
                done = true;
              }

              if (done) {
                state = 2;

                completer.complete(PreparedStmt._(
                  preparedPacket: preparedPacket!,
                  connection: this,
                  iterable: iterable,
                ));

                _state = _MySQLConnectionState.connectionEstablished;

                return;
              }
            }

            break;
        }

        if (packet != null) {
          final payload = packet.payload;

          if (payload is MySQLPacketStmtPrepareOK) {
            preparedPacket = payload;
          } else if (payload is MySQLPacketError) {
            completer.completeError(
              MySQLServerException(payload.errorMessage, payload.errorCode),
            );
            _state = _MySQLConnectionState.connectionEstablished;
            return;
          } else {
            completer.completeError(
              MySQLClientException(
                "Unexpected payload received in response to COMM_STMT_PREPARE request",
              ),
              StackTrace.current,
            );
            _forceClose();
            return;
          }
        }
      } catch (e) {
        completer.completeError(e, StackTrace.current);
        _forceClose();
      }
    };

    _socket.add(packet.encode());

    return completer.future;
  }

  Future<IResultSet> _executePreparedStmt(
    PreparedStmt stmt,
    List<dynamic> params,
    bool iterable,
  ) async {
    if (!_connected) {
      throw MySQLClientException(
          "Can not execute prepared stmt: connection closed");
    }

    // wait for ready state
    if (_state != _MySQLConnectionState.connectionEstablished) {
      await _waitForState(_MySQLConnectionState.connectionEstablished)
          .timeout(Duration(milliseconds: _timeoutMs));
    }

    _state = _MySQLConnectionState.waitingCommandResponse;

    final payload = MySQLPacketCommStmtExecute(
      stmtID: stmt._preparedPacket.stmtID,
      params: params,
    );

    final packet = MySQLPacket(
      sequenceID: 0,
      payload: payload,
      payloadLength: 0,
    );

    final completer = Completer<IResultSet>();

    /**
     * 0 - initial
     * 1 - columnCount decoded
     * 2 - columnDefs parsed
     * 3 - eofParsed
     * 4 - rowsParsed
     */
    int state = 0;
    int colsCount = 0;
    List<MySQLColumnDefinitionPacket> colDefs = [];
    List<MySQLBinaryResultSetRowPacket> resultSetRows = [];

    // support for iterable result set
    IterablePreparedStmtResultSet? iterableResultSet;
    StreamSink<ResultSetRow>? sink;

    _responseCallback = (data) async {
      try {
        MySQLPacket? packet;

        switch (state) {
          case 0:
            // if packet is OK packet, there is no data
            if (MySQLPacket.detectPacketType(data) ==
                MySQLGenericPacketType.ok) {
              final okPacket = MySQLPacket.decodeGenericPacket(data);
              _state = _MySQLConnectionState.connectionEstablished;

              completer.complete(
                EmptyResultSet(okPacket: okPacket.payload as MySQLPacketOK),
              );

              return;
            }

            packet = MySQLPacket.decodeColumnCountPacket(data);
            break;
          case 1:
            packet = MySQLPacket.decodeColumnDefPacket(data);
            break;
          case 2:
            packet = MySQLPacket.decodeGenericPacket(data);
            if (packet.isEOFPacket()) {
              state = 3;
            } else if (packet.isErrorPacket()) {
              final errorPayload = packet.payload as MySQLPacketError;
              completer.completeError(
                MySQLServerException(
                    errorPayload.errorMessage, errorPayload.errorCode),
              );
              _state = _MySQLConnectionState.connectionEstablished;
              return;
            } else {
              completer.completeError(
                MySQLClientException("Unexcpected packet type"),
                StackTrace.current,
              );
              _forceClose();
              return;
            }
            break;
          case 3:
            if (iterable) {
              if (iterableResultSet == null) {
                iterableResultSet = IterablePreparedStmtResultSet._(
                  columns: colDefs,
                );

                sink = iterableResultSet!._sink;
                completer.complete(iterableResultSet);
              }

              // check eof
              if (MySQLPacket.detectPacketType(data) ==
                  MySQLGenericPacketType.eof) {
                state = 4;

                _state = _MySQLConnectionState.connectionEstablished;
                await sink!.close();
                return;
              }

              packet =
                  MySQLPacket.decodeBinaryResultSetRowPacket(data, colDefs);
              final values =
                  (packet.payload as MySQLBinaryResultSetRowPacket).values;
              sink!.add(ResultSetRow._(colDefs: colDefs, values: values));
              packet = null;
              break;
            } else {
              // check eof
              if (MySQLPacket.detectPacketType(data) ==
                  MySQLGenericPacketType.eof) {
                state = 4;

                final resultSetPacket = MySQLPacketBinaryResultSet(
                  columnCount: BigInt.from(colsCount),
                  columns: colDefs,
                  rows: resultSetRows,
                );

                _state = _MySQLConnectionState.connectionEstablished;

                completer.complete(
                  PreparedStmtResultSet._(resultSetPacket: resultSetPacket),
                );

                return;
              }

              packet =
                  MySQLPacket.decodeBinaryResultSetRowPacket(data, colDefs);

              break;
            }
        }

        if (packet != null) {
          final payload = packet.payload;

          if (payload is MySQLPacketError) {
            completer.completeError(
              MySQLServerException(payload.errorMessage, payload.errorCode),
            );
            _state = _MySQLConnectionState.connectionEstablished;
            return;
          } else if (payload is MySQLPacketOK || payload is MySQLPacketEOF) {
            // do nothing
          } else if (payload is MySQLPacketColumnCount) {
            state = 1;
            colsCount = payload.columnCount.toInt();
            return;
          } else if (payload is MySQLColumnDefinitionPacket) {
            colDefs.add(payload);
            if (colDefs.length == colsCount) {
              state = 2;
            }
          } else if (payload is MySQLBinaryResultSetRowPacket) {
            resultSetRows.add(payload);
          } else {
            completer.completeError(
              MySQLClientException(
                "Unexpected payload received in response to COMM_QUERY request",
              ),
              StackTrace.current,
            );
            _forceClose();
            return;
          }
        }
      } catch (e) {
        completer.completeError(e, StackTrace.current);
        _forceClose();
      }
    };

    _socket.add(packet.encode());

    return completer.future;
  }

  Future<void> _deallocatePreparedStmt(PreparedStmt stmt) async {
    if (!_connected) {
      throw MySQLClientException("Can not execute query: connection closed");
    }

    // wait for ready state
    if (_state != _MySQLConnectionState.connectionEstablished) {
      await _waitForState(_MySQLConnectionState.connectionEstablished)
          .timeout(Duration(milliseconds: _timeoutMs));
    }

    final payload = MySQLPacketCommStmtClose(
      stmtID: stmt._preparedPacket.stmtID,
    );

    final packet = MySQLPacket(
      sequenceID: 0,
      payload: payload,
      payloadLength: 0,
    );

    _socket.add(packet.encode());
  }

  String _escapeString(String value) {
    value = value.replaceAll(r"\", r'\\');
    value = value.replaceAll(r"'", r"''");
    return value;
  }

  /// Close this connection gracefully
  ///
  /// This is an error to use this connection after connection has been closed
  Future<void> close() async {
    final packet = MySQLPacket(
      sequenceID: 0,
      payload: MySQLPacketCommQuit(),
      payloadLength: 0,
    );

    if (_state != _MySQLConnectionState.connectionEstablished) {
      throw MySQLClientException(
        "Can not close connection. Connection state is not in connectionEstablished state",
      );
    }

    _socket.add(packet.encode());
    _state = _MySQLConnectionState.quitCommandSend;

    await _closeSocketAndCallHandlers();
  }

  Future<void> _closeSocketAndCallHandlers() async {
    if (_socketSubscription != null) {
      await _socketSubscription!.cancel();
    }

    await _socket.flush();
    await Future.delayed(Duration(milliseconds: 10));
    await _socket.close();
    _socket.destroy();

    _incompleteBufferData.clear();

    _connected = false;
    _state = _MySQLConnectionState.closed;

    for (var element in _onCloseCallbacks) {
      element();
    }

    _onCloseCallbacks.clear();
    _responseCallback = null;
    _inTransaction = false;
    _incompleteBufferData.clear();
    _lastError = null;
  }

  void _forceClose() {
    if (_socketSubscription != null) {
      _socketSubscription!.cancel();
    }

    _socket.destroy();
    _incompleteBufferData.clear();

    _connected = false;
    _state = _MySQLConnectionState.closed;

    for (var element in _onCloseCallbacks) {
      element();
    }

    _onCloseCallbacks.clear();
    _responseCallback = null;
    _inTransaction = false;
    _incompleteBufferData.clear();
    _lastError = null;
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

/// Base class to represent result of calling [MySQLConnection.execute] and [PreparedStmt.execute]
abstract class IResultSet
    with IterableMixin<IResultSet>
    implements Iterator<IResultSet>, Iterable<IResultSet> {
  /// Number of colums in this result if any
  int get numOfColumns;

  /// Number of rows in this result if any (unavailable for iterable results)
  int get numOfRows;

  /// Number of affected rows
  BigInt get affectedRows;

  /// Last insert ID
  BigInt get lastInsertID;

  /// Next result set, if any.
  /// Prepared statements and iterable result sets does not supprot this
  IResultSet? next;

  IResultSet? _current;

  @override
  Iterator<IResultSet> get iterator => this;

  @override
  IResultSet get current {
    if (_current != null) {
      return _current!;
    } else {
      throw RangeError("Trying to access past the end value");
    }
  }

  @override
  bool moveNext() {
    if (_current == null) {
      _current = this;
      return true;
    } else {
      if (_current!.next != null) {
        _current = _current!.next;
        return true;
      } else {
        return false;
      }
    }
  }

  /// Provides access to data rows (unavailable for iterable results)
  Iterable<ResultSetRow> get rows;

  /// Use [cols] to get info about returned columns
  Iterable<ResultSetColumn> get cols;

  /// Provides Stream like access to data rows. Use [rowsStream] to get rows from iterable results
  Stream<ResultSetRow> get rowsStream => Stream.fromIterable(rows);
}

/// Represents result of [MySQLConnection.execute] method
class ResultSet extends IResultSet {
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
        length: e.columnLength,
      ),
    );
  }
}

/// Represents result of [MySQLConnection.execute] method when passing iterable = true
class IterableResultSet with IterableMixin<IResultSet> implements IResultSet {
  final List<MySQLColumnDefinitionPacket> _columns;
  late StreamController<ResultSetRow> _controller;

  IterableResultSet._({
    required List<MySQLColumnDefinitionPacket> columns,
  }) : _columns = columns {
    _controller = StreamController();
  }

  @override
  IResultSet? get next => throw UnimplementedError();

  @override
  set next(val) => throw UnimplementedError();

  @override
  Iterator<IResultSet> get iterator => throw UnimplementedError();

  @override
  IResultSet? _current;

  @override
  IResultSet get current => throw UnimplementedError();

  @override
  bool moveNext() => throw UnimplementedError();

  StreamSink<ResultSetRow> get _sink => _controller.sink;

  @override
  Stream<ResultSetRow> get rowsStream => _controller.stream;

  @override
  int get numOfColumns => _columns.length;

  @override
  int get numOfRows => throw MySQLClientException(
        "numOfRows is not implemented for IterableResultSet",
      );

  @override
  BigInt get affectedRows => BigInt.zero;

  @override
  BigInt get lastInsertID => BigInt.zero;

  @override
  Iterable<ResultSetColumn> get cols {
    return _columns.map(
      (e) => ResultSetColumn(
        name: e.name,
        type: e.type,
        length: e.columnLength,
      ),
    );
  }

  @override
  Iterable<ResultSetRow> get rows => throw MySQLClientException(
        "Use rowsStream to get rows from IterableResultSet",
      );
}

/// Represents result of [PreparedStmt.execute] method
class PreparedStmtResultSet extends IResultSet {
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
        length: e.columnLength,
      ),
    );
  }
}

/// Represents result of [PreparedStmt.execute] method when using iterable = true
class IterablePreparedStmtResultSet extends IResultSet {
  final List<MySQLColumnDefinitionPacket> _columns;
  late StreamController<ResultSetRow> _controller;

  IterablePreparedStmtResultSet._({
    required List<MySQLColumnDefinitionPacket> columns,
  }) : _columns = columns {
    _controller = StreamController();
  }

  StreamSink<ResultSetRow> get _sink => _controller.sink;

  @override
  int get numOfColumns => _columns.length;

  @override
  int get numOfRows => throw MySQLClientException(
        "numOfRows is not implemented for IterableResultSet",
      );

  @override
  BigInt get affectedRows => BigInt.zero;

  @override
  BigInt get lastInsertID => BigInt.zero;

  @override
  Iterable<ResultSetRow> get rows => throw MySQLClientException(
        "Use rowsStream to get rows from IterablePreparedStmtResultSet",
      );

  @override
  Stream<ResultSetRow> get rowsStream => _controller.stream;

  @override
  Iterable<ResultSetColumn> get cols {
    return _columns.map(
      (e) => ResultSetColumn(
        name: e.name,
        type: e.type,
        length: e.columnLength,
      ),
    );
  }
}

/// Represents empty result set
class EmptyResultSet extends IResultSet {
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

/// Represents result set row data
class ResultSetRow {
  final List<MySQLColumnDefinitionPacket> _colDefs;
  final List<String?> _values;

  ResultSetRow._({
    required List<MySQLColumnDefinitionPacket> colDefs,
    required List<String?> values,
  })  : _colDefs = colDefs,
        _values = values;

  /// Get number of columns for this row
  int get numOfColumns => _colDefs.length;

  /// Get column data by column index (starting form 0)
  String? colAt(int colIndex) {
    if (colIndex >= _values.length) {
      throw MySQLClientException("Column index is out of range");
    }

    final value = _values[colIndex];

    return value;
  }

  /// Same as [colAt] but performs conversion of string data, into provided type [T], if possible
  ///
  /// Conversion is "typesafe", meaning that actual MySQL column type will be checked,
  /// to decide is it possible to make such a conversion
  ///
  /// Throws [MySQLClientException] if conversion is not possible
  T? typedColAt<T>(int colIndex) {
    final value = colAt(colIndex);
    final colDef = _colDefs[colIndex];

    return colDef.type
        .convertStringValueToProvidedType<T>(value, colDef.columnLength);
  }

  /// Get column data by column name
  String? colByName(String columnName) {
    final colIndex = _colDefs.indexWhere(
      (element) => element.name.toLowerCase() == columnName.toLowerCase(),
    );

    if (colIndex == -1) {
      throw MySQLClientException("There is no column with name: $columnName");
    }

    if (colIndex >= _values.length) {
      throw MySQLClientException("Column index is out of range");
    }

    final value = _values[colIndex];

    return value;
  }

  /// Same as [colByName] but performs conversion of string data, into provided type [T], if possible
  ///
  /// Conversion is "typesafe", meaning that actual MySQL column type will be checked,
  /// to decide is it possible to make such a conversion
  ///
  /// Throws [MySQLClientException] if conversion is not possible
  T? typedColByName<T>(String columnName) {
    final value = colByName(columnName);

    final colIndex = _colDefs.indexWhere(
      (element) => element.name.toLowerCase() == columnName.toLowerCase(),
    );

    final colDef = _colDefs[colIndex];

    return colDef.type
        .convertStringValueToProvidedType<T>(value, colDef.columnLength);
  }

  /// Get data for all columns
  Map<String, String?> assoc() {
    final result = <String, String?>{};

    int colIndex = 0;

    for (final colDef in _colDefs) {
      result[colDef.name] = _values[colIndex];
      colIndex++;
    }

    return result;
  }

  /// Same as [assoc] but detects best dart type for columns, and converts string data into appropriate types
  Map<String, dynamic> typedAssoc() {
    final result = <String, dynamic>{};

    int colIndex = 0;

    for (final colDef in _colDefs) {
      final value = _values[colIndex];

      if (value == null) {
        result[colDef.name] = null;
        colIndex++;
        continue;
      }

      final dartType = colDef.type.getBestMatchDartType(colDef.columnLength);

      dynamic decodedValue;

      switch (dartType) {
        case int:
          decodedValue = int.parse(value);
          break;
        case double:
          decodedValue = double.parse(value);
          break;
        case num:
          decodedValue = num.parse(value);
          break;
        case bool:
          decodedValue = int.parse(value) > 0;
          break;
        case String:
          decodedValue = value;
          break;
        default:
          decodedValue = value;
          break;
      }

      result[colDef.name] = decodedValue;

      colIndex++;
    }

    return result;
  }
}

/// Represents column definition
class ResultSetColumn {
  String name;
  MySQLColumnType type;
  int length;

  ResultSetColumn({
    required this.name,
    required this.type,
    required this.length,
  });
}

/// Prepared statement class
class PreparedStmt {
  final MySQLPacketStmtPrepareOK _preparedPacket;
  final MySQLConnection _connection;
  final bool _iterable;

  PreparedStmt._({
    required MySQLPacketStmtPrepareOK preparedPacket,
    required MySQLConnection connection,
    required bool iterable,
  })  : _preparedPacket = preparedPacket,
        _connection = connection,
        _iterable = iterable;

  int get numOfParams => _preparedPacket.numOfParams;

  /// Executes this prepared statement with given [params]
  Future<IResultSet> execute(List<dynamic> params) async {
    if (numOfParams != params.length) {
      throw MySQLClientException(
        "Can not execute prepared stmt: number of passed params != number of prepared params",
      );
    }

    return _connection._executePreparedStmt(this, params, _iterable);
  }

  /// Deallocates this prepared statement
  ///
  /// Use this method to prevent memory leaks for long running connections
  /// All prepared statements are automatically deallocated by database when connection is closed
  Future<void> deallocate() {
    return _connection._deallocatePreparedStmt(this);
  }
}
