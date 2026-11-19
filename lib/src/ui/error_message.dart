import '../api/api_exception.dart';

/// The one place an [ApiException] becomes text for the user.
///
/// The switch has no default branch on purpose. [ApiException] is sealed, so
/// adding a new failure type will not compile until it has a message here.
String describeError(ApiException error) {
  return switch (error) {
    NetworkException() =>
      "You're offline. Check your connection and try again.",
    TimeoutApiException() =>
      'The server took too long to respond. Please try again.',
    UnauthorizedException(:final message) => message,
    ValidationException(:final message) => message,
    RateLimitedException(:final retryAfter) => retryAfter == null
        ? 'Too many attempts. Wait a moment and try again.'
        : 'Too many attempts. Try again in ${retryAfter.inSeconds} seconds.',
    ServerException() =>
      'Something went wrong on our side. Please try again shortly.',
    UnexpectedResponseException() =>
      'We received a response we could not read. Please try again.',
  };
}

/// Whether offering a "Try again" button makes sense for this failure.
bool canRetry(ApiException error) {
  return switch (error) {
    NetworkException() || TimeoutApiException() || ServerException() => true,
    _ => false,
  };
}
