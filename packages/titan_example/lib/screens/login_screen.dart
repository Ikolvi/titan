import 'package:flutter/material.dart';
import 'package:titan_bastion/titan_bastion.dart';

import '../pillars/auth_pillar.dart';

// ---------------------------------------------------------------------------
// Login Screen — demonstrates CoreRefresh reactive routing
// ---------------------------------------------------------------------------

/// A simple login screen for the Questboard app.
///
/// When the user signs in via [AuthPillar.signIn], the `CoreRefresh`
/// bridge notifies Atlas, which re-evaluates the guestOnly Sentinel
/// and automatically redirects to `/` — no manual navigation needed.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = TextEditingController(text: 'Kael');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hero icon
                Icon(
                  Icons.shield_outlined,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Questboard',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to begin your quest',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),

                // Hero name field
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Hero Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signIn(),
                ),
                const SizedBox(height: 24),

                // Sign in button
                FilledButton.icon(
                  onPressed: _signIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Enter the Questboard'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 16),

                // Info card about CoreRefresh
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'CoreRefresh Demo',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'After sign-in, Atlas automatically redirects '
                          'to the quest board — no manual navigation needed. '
                          'CoreRefresh bridges the AuthPillar\'s isLoggedIn '
                          'Core to Atlas\'s refreshListenable.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _signIn() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    // Just update the auth state — CoreRefresh handles the navigation
    final auth = Titan.get<AuthPillar>();
    auth.signIn(name);
  }
}
