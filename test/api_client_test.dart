import 'dart:io';

import 'package:flutter_auth_error_handling/src/api/api_client.dart';
import 'package:flutter_auth_error_handling/src/api/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _base = Uri.parse('https://api.test/v1/');

ApiClient _client(
  MockClientHandler handler, {
  Future<String?> Function()? readToken,
  Duration timeout = const Duration(seconds: 2),
  int maxRetries = 2,
}) {
  return ApiClient(
    baseUrl: _base,
    httpClient: MockClient(handler),
    readToken: readToken,
    timeout: timeout,
    maxRetries: maxRetries,
    retryDelay: Duration.zero,
  );
}

void main() {
  group('successful requests', () {
    test('returns the decoded JSON body', () async {
      final client = _client((_) async => http.Response('{"id":"u_1"}', 200));

      expect(await client.get('me'), {'id': 'u_1'});
    });

    test('treats an empty 2xx body as an empty object', () async {
      final client = _client((_) async => http.Response('', 204));

      expect(await client.get('me'), isEmpty);
    });

    test('sends the bearer token and resolves the path', () async {
      late http.Request seen;
      final client = _client(
        (request) async {
          seen = request;
          return http.Response('{}', 200);
        },
        readToken: () async => 'abc',
      );

      await client.get('me');

      expect(seen.url.toString(), 'https://api.test/v1/me');
      expect(seen.headers['authorization'], 'Bearer abc');
    });

    test('leaves the token off unauthenticated requests', () async {
      late http.Request seen;
      final client = _client(
        (request) async {
          seen = request;
          return http.Response('{}', 200);
        },
        readToken: () async => 'abc',
      );

      await client.post('auth/login', body: {'a': 1}, authenticated: false);

      expect(seen.headers.containsKey('authorization'), isFalse);
      expect(seen.body, '{"a":1}');
    });
  });

  group('error mapping', () {
    test('401 becomes UnauthorizedException with the server message',
        () async {
      final client = _client(
          (_) async => http.Response('{"message":"Wrong password."}', 401));

      await expectLater(
        client.get('me'),
        throwsA(isA<UnauthorizedException>()
            .having((e) => e.message, 'message', 'Wrong password.')),
      );
    });

    test('422 becomes ValidationException with field errors', () async {
      final client = _client((_) async => http.Response(
          '{"message":"Invalid.","errors":{"email":"Taken."}}', 422));

      await expectLater(
        client.post('auth/login', body: const {}),
        throwsA(isA<ValidationException>()
            .having((e) => e.message, 'message', 'Invalid.')
            .having((e) => e.fieldErrors, 'fieldErrors', {'email': 'Taken.'})),
      );
    });

    test('429 becomes RateLimitedException and reads Retry-After', () async {
      final client = _client((_) async =>
          http.Response('{}', 429, headers: {'retry-after': '30'}));

      await expectLater(
        client.post('auth/login', body: const {}),
        throwsA(isA<RateLimitedException>().having(
            (e) => e.retryAfter, 'retryAfter', const Duration(seconds: 30))),
      );
    });

    test('5xx becomes ServerException', () async {
      final client = _client((_) async => http.Response('oops', 500));

      await expectLater(
        client.post('auth/login', body: const {}),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('a dropped connection becomes NetworkException', () async {
      final client = _client(
        (_) async => throw const SocketException('offline'),
        maxRetries: 0,
      );

      await expectLater(client.get('me'), throwsA(isA<NetworkException>()));
    });

    test('a slow server becomes TimeoutApiException', () async {
      final client = _client(
        (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('{}', 200);
        },
        timeout: const Duration(milliseconds: 20),
        maxRetries: 0,
      );

      await expectLater(client.get('me'), throwsA(isA<TimeoutApiException>()));
    });

    test('a 2xx body that is not a JSON object is rejected', () async {
      final client = _client((_) async => http.Response('<html>', 200));

      await expectLater(
          client.get('me'), throwsA(isA<UnexpectedResponseException>()));
    });
  });

  group('retries', () {
    test('a GET is retried after a 503 and then succeeds', () async {
      var calls = 0;
      final client = _client((_) async {
        calls++;
        return calls < 3
            ? http.Response('{}', 503)
            : http.Response('{"ok":true}', 200);
      });

      expect(await client.get('me'), {'ok': true});
      expect(calls, 3);
    });

    test('a GET stops after maxRetries and reports the last failure',
        () async {
      var calls = 0;
      final client = _client((_) async {
        calls++;
        return http.Response('{}', 503);
      });

      await expectLater(client.get('me'), throwsA(isA<ServerException>()));
      expect(calls, 3); // First try plus two retries.
    });

    test('a POST is never retried', () async {
      var calls = 0;
      final client = _client((_) async {
        calls++;
        return http.Response('{}', 503);
      });

      await expectLater(client.post('auth/login', body: const {}),
          throwsA(isA<ServerException>()));
      expect(calls, 1);
    });

    test('a 401 is not retried', () async {
      var calls = 0;
      final client = _client((_) async {
        calls++;
        return http.Response('{}', 401);
      });

      await expectLater(
          client.get('me'), throwsA(isA<UnauthorizedException>()));
      expect(calls, 1);
    });
  });
}
