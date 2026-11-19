import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'src/auth/auth_controller.dart';
import 'src/demo/demo_backend.dart';
import 'src/ui/home_screen.dart';
import 'src/ui/login_screen.dart';

class AuthDemoApp extends StatelessWidget {
  const AuthDemoApp({super.key, required this.auth, required this.demo});

  final AuthController auth;
  final DemoSettings demo;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: demo),
      ],
      child: MaterialApp(
        title: 'Auth and error handling',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const _Root(),
      ),
    );
  }
}

/// Chooses the screen from the session state. There is no manual navigation,
/// so the UI cannot drift out of step with whether the user is signed in.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthController, AuthStatus>((a) => a.status);
    return switch (status) {
      AuthStatus.checking => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthStatus.signedIn => const HomeScreen(),
      AuthStatus.signedOut || AuthStatus.submitting => const LoginScreen(),
    };
  }
}
