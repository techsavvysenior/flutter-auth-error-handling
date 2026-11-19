import 'package:flutter_auth_error_handling/src/api/api_client.dart';
import 'package:flutter_auth_error_handling/src/api/api_exception.dart';
import 'package:flutter_auth_error_handling/src/auth/auth_controller.dart';
import 'package:flutter_auth_error_handling/src/auth/auth_repository.dart';
import 'package:flutter_auth_error_handling/src/auth/token_store.dart';
import 'package:flutter_auth_error_handling/src/demo/demo_backend.dart';
import 'package:flutter_test/flutter_test.dart';

class _Harness {
  _Harness({String? storedToken}) : tokens = InMemoryTokenStore(storedToken) {
    final api = ApiClient(
      baseUrl: Uri.parse('https://demo.invalid/v1/'),
      httpClient: buildDemoBackend(() => scenario, latency: Duration.zero),
      readToken: tokens.read,
      maxRetries: 0,
    );
    controller = AuthController(AuthRepository(api: api, tokens: tokens));
  }

  final InMemoryTokenStore tokens;
  DemoScenario scenario = DemoScenario.success;
  late final AuthController controller;
}

void main() {
  test('signing in stores the token and loads the user', () async {
    final h = _Harness();

    await h.controller.signIn(email: demoEmail, password: demoPassword);

    expect(h.controller.status, AuthStatus.signedIn);
    expect(h.controller.user?.name, 'Demo User');
    expect(h.controller.error, isNull);
    expect(await h.tokens.read(), isNotNull);
  });

  test('the email is trimmed before it is sent', () async {
    final h = _Harness();

    await h.controller.signIn(email: '  $demoEmail ', password: demoPassword);

    expect(h.controller.status, AuthStatus.signedIn);
  });

  test('wrong credentials leave the user signed out with a reason', () async {
    final h = _Harness();

    await h.controller.signIn(email: demoEmail, password: 'not-the-password');

    expect(h.controller.status, AuthStatus.signedOut);
    expect(h.controller.error, isA<UnauthorizedException>());
    expect(await h.tokens.read(), isNull);
  });

  test('being offline is reported and nothing is stored', () async {
    final h = _Harness()..scenario = DemoScenario.offline;

    await h.controller.signIn(email: demoEmail, password: demoPassword);

    expect(h.controller.status, AuthStatus.signedOut);
    expect(h.controller.error, isA<NetworkException>());
    expect(await h.tokens.read(), isNull);
  });

  test('a saved token restores the session at launch', () async {
    final h = _Harness(storedToken: 'demo-token');

    await h.controller.restore();

    expect(h.controller.status, AuthStatus.signedIn);
    expect(h.controller.user?.email, demoEmail);
  });

  test('a rejected saved token is cleared at launch', () async {
    final h = _Harness(storedToken: 'stale-token');

    await h.controller.restore();

    expect(h.controller.status, AuthStatus.signedOut);
    expect(await h.tokens.read(), isNull);
  });

  test('no saved token means signed out, with no error', () async {
    final h = _Harness();

    await h.controller.restore();

    expect(h.controller.status, AuthStatus.signedOut);
    expect(h.controller.error, isNull);
  });

  test('an expired session on reload signs the user out', () async {
    final h = _Harness();
    await h.controller.signIn(email: demoEmail, password: demoPassword);

    h.scenario = DemoScenario.sessionExpired;
    await h.controller.reloadProfile();

    expect(h.controller.status, AuthStatus.signedOut);
    expect(h.controller.user, isNull);
    expect(h.controller.error, isA<UnauthorizedException>());
    expect(await h.tokens.read(), isNull);
  });

  test('a server error on reload keeps the user signed in', () async {
    final h = _Harness();
    await h.controller.signIn(email: demoEmail, password: demoPassword);

    h.scenario = DemoScenario.serverError;
    await h.controller.reloadProfile();

    expect(h.controller.status, AuthStatus.signedIn);
    expect(h.controller.user, isNotNull);
    expect(h.controller.error, isA<ServerException>());
  });

  test('signing out clears the token', () async {
    final h = _Harness();
    await h.controller.signIn(email: demoEmail, password: demoPassword);

    await h.controller.signOut();

    expect(h.controller.status, AuthStatus.signedOut);
    expect(await h.tokens.read(), isNull);
  });
}
