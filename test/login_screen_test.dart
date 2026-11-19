import 'package:flutter_auth_error_handling/app.dart';
import 'package:flutter_auth_error_handling/src/api/api_client.dart';
import 'package:flutter_auth_error_handling/src/auth/auth_controller.dart';
import 'package:flutter_auth_error_handling/src/auth/auth_repository.dart';
import 'package:flutter_auth_error_handling/src/auth/token_store.dart';
import 'package:flutter_auth_error_handling/src/demo/demo_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<DemoSettings> _pumpApp(WidgetTester tester) async {
  final demo = DemoSettings();
  final tokens = InMemoryTokenStore();
  final api = ApiClient(
    baseUrl: Uri.parse('https://demo.invalid/v1/'),
    httpClient: buildDemoBackend(() => demo.scenario, latency: Duration.zero),
    readToken: tokens.read,
    maxRetries: 0,
  );
  final auth = AuthController(AuthRepository(api: api, tokens: tokens))
    ..restore();

  await tester.pumpWidget(AuthDemoApp(auth: auth, demo: demo));
  await tester.pumpAndSettle();
  return demo;
}

Future<void> _signIn(
  WidgetTester tester, {
  String email = demoEmail,
  String password = demoPassword,
}) async {
  await tester.enterText(find.byKey(const Key('email')), email);
  await tester.enterText(find.byKey(const Key('password')), password);
  await tester.tap(find.byKey(const Key('submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty fields are caught before any request is made',
      (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(find.byKey(const Key('error-banner')), findsNothing);
  });

  testWidgets('a malformed email is rejected', (tester) async {
    await _pumpApp(tester);

    await _signIn(tester, email: 'not-an-email');

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('valid credentials open the profile screen', (tester) async {
    await _pumpApp(tester);

    await _signIn(tester);

    expect(find.text('Signed in as Demo User'), findsOneWidget);
  });

  testWidgets('wrong credentials show the reason and stay on the form',
      (tester) async {
    await _pumpApp(tester);

    await _signIn(tester, password: 'wrong-password');

    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(find.byKey(const Key('submit')), findsOneWidget);
  });

  testWidgets('being offline offers a retry', (tester) async {
    final demo = await _pumpApp(tester);
    demo.scenario = DemoScenario.offline;
    await tester.pump();

    await _signIn(tester);

    expect(find.textContaining("You're offline"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('retrying after the connection returns signs the user in',
      (tester) async {
    final demo = await _pumpApp(tester);
    demo.scenario = DemoScenario.offline;
    await tester.pump();
    await _signIn(tester);

    demo.scenario = DemoScenario.success;
    await tester.pump();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Signed in as Demo User'), findsOneWidget);
  });

  testWidgets('a server-side field error is shown on that field',
      (tester) async {
    final demo = await _pumpApp(tester);
    demo.scenario = DemoScenario.validation;
    await tester.pump();

    await _signIn(tester);

    expect(find.text('This email address is not registered.'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('an expired session returns to login with an explanation',
      (tester) async {
    final demo = await _pumpApp(tester);
    await _signIn(tester);

    demo.scenario = DemoScenario.sessionExpired;
    await tester.pump();
    await tester.tap(find.byKey(const Key('reload')));
    await tester.pumpAndSettle();

    expect(
      find.text('Your session has expired. Please sign in again.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('submit')), findsOneWidget);
  });
}
