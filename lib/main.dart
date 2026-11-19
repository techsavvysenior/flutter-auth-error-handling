import 'package:flutter/material.dart';

import 'app.dart';
import 'src/api/api_client.dart';
import 'src/auth/auth_controller.dart';
import 'src/auth/auth_repository.dart';
import 'src/auth/token_store.dart';
import 'src/demo/demo_backend.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final demo = DemoSettings();
  final tokens = SecureTokenStore();

  // To use a real backend, pass `http.Client()` and your API's base URL here.
  // Nothing else in the app changes.
  final api = ApiClient(
    baseUrl: Uri.parse('https://demo.invalid/v1/'),
    httpClient: buildDemoBackend(() => demo.scenario),
    readToken: tokens.read,
    timeout: const Duration(seconds: 3),
  );

  final auth = AuthController(AuthRepository(api: api, tokens: tokens))
    ..restore();

  runApp(AuthDemoApp(auth: auth, demo: demo));
}
