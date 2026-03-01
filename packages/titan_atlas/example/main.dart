/// Titan Atlas — Declarative routing & navigation for Flutter.
///
/// This example demonstrates:
/// - [Atlas] — Declarative router with Navigator 2.0
/// - [Passage] — Route definitions with path parameters
/// - [Sanctum] — Shell routes for persistent layouts
/// - [Sentinel] — Route guards
/// - [Shift] — Page transitions
library;

import 'package:flutter/material.dart';
import 'package:titan_atlas/titan_atlas.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final atlas = Atlas(
    passages: [
      // Shell route — persistent bottom nav bar
      Sanctum(
        shell: (child) => AppShell(child: child),
        passages: [
          Passage('/', (_) => const HomeScreen(), name: 'home'),
          Passage('/settings', (_) => const SettingsScreen(), name: 'settings'),
        ],
      ),

      // Detail page with path parameter and slide transition
      Passage(
        '/item/:id',
        (waypoint) => ItemScreen(id: waypoint.runes['id'] ?? ''),
        shift: Shift.slideUp(),
        name: 'item-detail',
      ),
    ],

    // Route guard — protect admin when not authenticated
    sentinels: [
      Sentinel.only(
        paths: {'/admin'},
        guard: (path, waypoint) => '/login', // redirect to login
      ),
    ],
  );

  runApp(MaterialApp.router(routerConfig: atlas.config));
}

// ---------------------------------------------------------------------------
// Shell — Persistent layout with bottom navigation
// ---------------------------------------------------------------------------

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final path = Atlas.current.path;
    final index = path == '/settings' ? 1 : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Atlas Example')),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          context.atlas.go(i == 0 ? '/' : '/settings');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screens
// ---------------------------------------------------------------------------

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) => ListTile(
        title: Text('Item $index'),
        onTap: () => context.atlas.to('/item/$index'),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Settings'));
  }
}

class ItemScreen extends StatelessWidget {
  final String id;
  const ItemScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Item $id')),
      body: Center(child: Text('Detail for item $id')),
    );
  }
}
