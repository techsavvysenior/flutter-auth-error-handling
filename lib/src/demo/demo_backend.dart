import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The server behaviours the demo can simulate.
enum DemoScenario {
  success('Success'),
  wrongPassword('Wrong password'),
  validation('Validation error'),
  offline('Offline'),
  timeout('Timeout'),
  serverError('Server error'),
  rateLimited('Rate limited'),
  sessionExpired('Session expired');

  const DemoScenario(this.label);

  final String label;
}

class DemoSettings extends ChangeNotifier {
  DemoScenario _scenario = DemoScenario.success;

  DemoScenario get scenario => _scenario;

  set scenario(DemoScenario value) {
    if (value == _scenario) return;
    _scenario = value;
    notifyListeners();
  }
}

const demoEmail = 'demo@example.com';
const demoPassword = 'password123';
const _demoToken = 'demo-token';

/// An in-app stand-in for a real API, so the project runs with no server.
///
/// It is an [http.Client], which means the real [ApiClient] code path runs
/// unchanged: same requests, same status codes, same parsing. Point
/// `ApiClient` at a real `http.Client()` and base URL to use a live backend.
http.Client buildDemoBackend(
  DemoScenario Function() scenario, {
  Duration latency = const Duration(milliseconds: 600),
}) {
  return MockClient((request) async {
    final current = scenario();
    if (latency > Duration.zero) await Future<void>.delayed(latency);

    switch (current) {
      case DemoScenario.offline:
        throw const SocketException('Demo: no connection');
      case DemoScenario.timeout:
        // Longer than the client timeout, so the client gives up first.
        await Future<void>.delayed(const Duration(seconds: 30));
        return _json(200, const {});
      case DemoScenario.serverError:
        return _json(503, const {'message': 'Service unavailable.'});
      case DemoScenario.rateLimited:
        return _json(
          429,
          const {'message': 'Too many requests.'},
          headers: const {'retry-after': '30'},
        );
      default:
        break;
    }

    final path = request.url.path;
    if (request.method == 'POST' && path.endsWith('/auth/login')) {
      return _login(request, current);
    }
    if (request.method == 'GET' && path.endsWith('/me')) {
      return _profile(request, current);
    }
    return _json(404, const {'message': 'Not found.'});
  });
}

http.Response _login(http.Request request, DemoScenario scenario) {
  if (scenario == DemoScenario.validation) {
    return _json(422, const {
      'message': 'Please fix the highlighted field.',
      'errors': {'email': 'This email address is not registered.'},
    });
  }

  final body = jsonDecode(request.body);
  final matches = body is Map &&
      body['email'] == demoEmail &&
      body['password'] == demoPassword;

  if (scenario == DemoScenario.wrongPassword || !matches) {
    return _json(401, const {'message': 'Email or password is incorrect.'});
  }
  return _json(200, const {'token': _demoToken});
}

http.Response _profile(http.Request request, DemoScenario scenario) {
  final authorized = request.headers['authorization'] == 'Bearer $_demoToken';
  if (scenario == DemoScenario.sessionExpired || !authorized) {
    return _json(401, const {
      'message': 'Your session has expired. Please sign in again.',
    });
  }
  return _json(200, const {
    'id': 'u_1',
    'name': 'Demo User',
    'email': demoEmail,
  });
}

http.Response _json(
  int status,
  Map<String, Object?> body, {
  Map<String, String> headers = const {},
}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json', ...headers},
  );
}
