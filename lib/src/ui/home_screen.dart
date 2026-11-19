import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final error = auth.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            key: const Key('sign-out'),
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: auth.signOut,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (error != null) ...[
                  ErrorBanner(error: error, onRetry: auth.reloadProfile),
                  const SizedBox(height: 16),
                ],
                if (user != null) ...[
                  Text(
                    'Signed in as ${user.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(user.email),
                ],
                const SizedBox(height: 24),
                OutlinedButton(
                  key: const Key('reload'),
                  onPressed: auth.isReloading ? null : auth.reloadProfile,
                  child: auth.isReloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reload profile'),
                ),
                const SizedBox(height: 32),
                const ScenarioPicker(),
                const SizedBox(height: 12),
                Text(
                  'Pick a response above, then reload. "Session expired" '
                  'signs you out and explains why on the login screen.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
