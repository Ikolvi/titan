/// Titan Argus — Authentication & authorization for Titan.
///
/// This example demonstrates:
/// - [Argus] — Abstract auth Pillar base class
/// - [Garrison] — Pre-built Sentinel factories for route guards
/// - [CoreRefresh] — Bridges reactive auth state to Atlas refresh
/// - [guard] — One-call convenience for wiring auth + routing
library;

import 'package:flutter/material.dart';
import 'package:titan_argus/titan_argus.dart';

// ---------------------------------------------------------------------------
// Auth Pillar — Extend Argus for reactive authentication
// ---------------------------------------------------------------------------

class AuthPillar extends Argus {
  late final username = core<String?>(null);
  late final role = core<String?>('user');

  /// Override [authCores] to include additional reactive nodes
  /// that should trigger route re-evaluation when changed.
  @override
  List<ReactiveNode> get authCores => [isLoggedIn, role];

  @override
  Future<void> signIn([Map<String, dynamic>? credentials]) async {
    await strikeAsync(() async {
      username.value = credentials?['name'] as String? ?? 'Hero';
      role.value = credentials?['role'] as String? ?? 'user';
      isLoggedIn.value = true;
    });
  }

  @override
  void signOut() {
    strike(() {
      username.value = null;
      role.value = null;
      super.signOut();
    });
  }
}

// ---------------------------------------------------------------------------
// App — Wire Argus with Atlas routing
// ---------------------------------------------------------------------------

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Register auth Pillar globally
  final auth = AuthPillar();
  Titan.put(auth);

  // guard() returns a GarrisonAuth with sentinels + refresh
  final garrisonAuth = auth.guard(
    loginPath: '/login',
    homePath: '/',
    publicPaths: {'/login', '/register'},
    guestPaths: {'/login'},
  );

  final atlas = Atlas(
    passages: [
      Passage('/login', (_) => const LoginScreen()),
      Passage('/', (_) => const HomeScreen()),
      Passage('/admin', (_) => const AdminScreen()),
    ],
    sentinels: garrisonAuth.sentinels,
    refreshListenable: garrisonAuth.refresh,
  );

  runApp(MaterialApp.router(routerConfig: atlas.config));
}

// ---------------------------------------------------------------------------
// Screens
// ---------------------------------------------------------------------------

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Titan.get<AuthPillar>().signIn({'name': 'Kael'}),
          child: const Text('Sign In'),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Titan.get<AuthPillar>();
    return Scaffold(
      appBar: AppBar(title: Text('Welcome, ${auth.username.value}')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Role: ${auth.role.value}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: auth.signOut,
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: const Center(child: Text('Admin content')),
    );
  }
}
