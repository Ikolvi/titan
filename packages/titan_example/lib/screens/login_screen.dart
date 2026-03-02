import 'package:flutter/material.dart';
import 'package:titan_argus/titan_argus.dart';
import 'package:titan_bastion/titan_bastion.dart';

import '../pillars/auth_pillar.dart';

// ---------------------------------------------------------------------------
// Login Screen — demonstrates CoreRefresh reactive routing + Spark hooks
// ---------------------------------------------------------------------------

/// A login screen for the Questboard app using Spark hooks.
///
/// Uses [useTextController] to auto-manage the hero name input controller.
/// When the user signs in via [AuthPillar.signIn], the `CoreRefresh`
/// bridge notifies Atlas, which re-evaluates the guestOnly Sentinel
/// and automatically redirects — either to the `redirect` query param
/// (preserveRedirect) or to `/` as the default home.
class LoginScreen extends Spark {
  /// The current waypoint, used to read the `redirect` query param.
  final Waypoint waypoint;

  const LoginScreen({super.key, required this.waypoint});

  @override
  Widget ignite(BuildContext context) {
    final controller = useTextController(text: 'Kael');
    final theme = Theme.of(context);
    final redirectTarget = waypoint.query['redirect'];

    void signIn() {
      final name = controller.text.trim();
      if (name.isEmpty) return;
      final auth = Titan.get<AuthPillar>();
      auth.signInAs(name);
    }

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
                  redirectTarget != null
                      ? 'Sign in to continue to $redirectTarget'
                      : 'Sign in to begin your quest',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),

                // Hero name field
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Hero Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => signIn(),
                ),
                const SizedBox(height: 24),

                // Sign in button
                FilledButton.icon(
                  onPressed: signIn,
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
                              'Argus + CoreRefresh Demo',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'After sign-in, Atlas automatically redirects '
                          '${redirectTarget != null ? 'to $redirectTarget (preserveRedirect)' : 'to the quest board'}'
                          ' — no manual navigation needed. '
                          'AuthPillar extends Argus, whose guard() wires '
                          'Garrison sentinels + CoreRefresh together.',
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
}
