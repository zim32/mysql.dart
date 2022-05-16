import 'dart:io';

class MySQLServerException extends IOException {
  final String message;

  MySQLServerException(this.message);

  @override
  String toString() {
    return "MySQLServerException: $message";
  }
}

class MySQLClientException implements Exception {
  final String message;

  const MySQLClientException(this.message);

  @override
  String toString() {
    return "MySQLClientException: $message";
  }
}

class MySQLProtocolException extends MySQLClientException {
  const MySQLProtocolException(String message) : super(message);

  @override
  String toString() {
    return "MySQLProtocolException: $message";
  }
}
