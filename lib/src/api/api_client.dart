import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

typedef TokenReader = Future<String?> Function();

/// Thin JSON client. Its one job is to turn every way a request can fail
/// into an [ApiException], so nothing above this layer deals with status
/// codes, sockets or malformed JSON.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required http.Client httpClient,
    this.readToken,
    this.timeout = const Duration(seconds: 10),
    this.maxRetries = 2,
    this.retryDelay = const Duration(milliseconds: 400),
  }) : _http = httpClient;

  /// Must end with a slash, for example `https://api.example.com/v1/`.
  final Uri baseUrl;

  /// Supplies the bearer token for authenticated requests.
  final TokenReader? readToken;

  final Duration timeout;

  /// How many times a failed GET is retried. POST is never retried.
  final int maxRetries;

  /// Base delay between retries. Attempt n waits `retryDelay * n`.
  final Duration retryDelay;

  final http.Client _http;

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) =>
      _send('POST', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    var attempt = 0;
    while (true) {
      try {
        final response = await _perform(
          method,
          path,
          body: body,
          authenticated: authenticated,
        );
        return _decode(response);
      } on ApiException catch (error) {
        if (!_isRetryable(method, error) || attempt >= maxRetries) rethrow;
        attempt++;
        await Future<void>.delayed(retryDelay * attempt);
      }
    }
  }

  Future<http.Response> _perform(
    String method,
    String path, {
    Map<String, dynamic>? body,
    required bool authenticated,
  }) async {
    final request = http.Request(method, baseUrl.resolve(path));
    request.headers['Accept'] = 'application/json';

    if (authenticated) {
      final reader = readToken;
      final token = reader == null ? null : await reader();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    try {
      final streamed = await _http.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const TimeoutApiException();
    } on SocketException {
      throw const NetworkException();
    } on http.ClientException {
      throw const NetworkException();
    }
  }

  /// Only idempotent requests are retried, and only for failures that can
  /// clear up on their own. Retrying a POST could submit the same thing twice.
  bool _isRetryable(String method, ApiException error) {
    if (method != 'GET') return false;
    return switch (error) {
      NetworkException() || TimeoutApiException() => true,
      ServerException(:final statusCode) =>
        statusCode == 502 || statusCode == 503 || statusCode == 504,
      _ => false,
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final status = response.statusCode;
    final json = _tryParse(response.body);

    if (status >= 200 && status < 300) {
      if (json != null) return json;
      if (response.body.trim().isEmpty) return const <String, dynamic>{};
      throw const UnexpectedResponseException();
    }

    final rawMessage = json?['message'];
    final serverMessage = rawMessage is String ? rawMessage : null;

    switch (status) {
      case 400 || 422:
        throw ValidationException(
          serverMessage ?? 'Please check the details and try again.',
          fieldErrors: _fieldErrors(json),
        );
      case 401 || 403:
        throw serverMessage == null
            ? const UnauthorizedException()
            : UnauthorizedException(serverMessage);
      case 429:
        throw RateLimitedException(
          retryAfter: _retryAfter(response.headers['retry-after']),
        );
      default:
        if (status >= 500) throw ServerException(status);
        throw UnexpectedResponseException('Unexpected status $status.');
    }
  }

  Map<String, dynamic>? _tryParse(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Map<String, String> _fieldErrors(Map<String, dynamic>? json) {
    final errors = json?['errors'];
    if (errors is! Map) return const {};
    return {
      for (final entry in errors.entries)
        if (entry.key is String && entry.value != null)
          entry.key as String: entry.value.toString(),
    };
  }

  Duration? _retryAfter(String? header) {
    final seconds = int.tryParse(header ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }
}
