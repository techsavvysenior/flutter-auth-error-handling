/// Every failure the API layer can report.
///
/// The class is sealed, so a `switch` over an [ApiException] must handle each
/// case. Adding a new failure type becomes a compile error anywhere the UI
/// forgot to handle it.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The request never reached the server (no connection, DNS failure).
final class NetworkException extends ApiException {
  const NetworkException([super.message = 'No internet connection.']);
}

/// The server did not answer within the client timeout.
final class TimeoutApiException extends ApiException {
  const TimeoutApiException([super.message = 'The request timed out.']);
}

/// 401 or 403. Wrong credentials, or a token that is no longer valid.
final class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'You need to sign in again.']);
}

/// 400 or 422. The server rejected the input, optionally per field.
final class ValidationException extends ApiException {
  const ValidationException(super.message, {this.fieldErrors = const {}});

  /// Field name to message, for example `{'email': 'Already registered.'}`.
  final Map<String, String> fieldErrors;
}

/// 429. Too many requests.
final class RateLimitedException extends ApiException {
  const RateLimitedException({this.retryAfter})
      : super('Too many requests.');

  /// Taken from the `Retry-After` header when the server sends one.
  final Duration? retryAfter;
}

/// Any 5xx response.
final class ServerException extends ApiException {
  const ServerException(this.statusCode) : super('Server error.');

  final int statusCode;
}

/// A response the client could not make sense of (bad JSON, missing fields,
/// an unexpected status code).
final class UnexpectedResponseException extends ApiException {
  const UnexpectedResponseException(
      [super.message = 'Unexpected response from the server.']);
}
