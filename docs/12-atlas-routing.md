# 12 — Atlas: Routing & Navigation

**Atlas** is Titan's routing and navigation system — a zero-boilerplate, high-performance alternative to GoRouter built on Navigator 2.0.

## The Atlas Lexicon

| Concept | Titan Name | Purpose |
|---------|------------|---------|
| Router | **Atlas** | Maps all paths, bears the world |
| Route | **Passage** | A way through to a destination |
| Shell Route | **Sanctum** | Inner chamber — persistent layout |
| Route Guard | **Sentinel** | Protects passage |
| Redirect | **Drift** | Navigation shifts course |
| Parameters | **Runes** | Ancient symbols carrying meaning |
| Transition | **Shift** | Change of form/phase |
| Route State | **Waypoint** | Current position in the journey |

## Quick Start

```dart
import 'package:titan_atlas/titan_atlas.dart';

final atlas = Atlas(
  passages: [
    Passage('/', (_) => const HomeScreen()),
    Passage('/profile/:id', (wp) => ProfileScreen(id: wp.runes['id']!)),
    Passage('/about', (_) => const AboutScreen(), name: 'about'),
  ],
);

void main() => runApp(
  MaterialApp.router(routerConfig: atlas.config),
);
```

## Passages — Route Definitions

A **Passage** maps a URL pattern to a widget builder:

```dart
// Static route
Passage('/home', (_) => const HomeScreen())

// Dynamic route with Runes (path parameters)
Passage('/user/:id', (wp) => UserScreen(id: wp.runes['id']!))

// Wildcard route
Passage('/files/*', (wp) => FileViewer(path: wp.remaining!))

// Named route (for toNamed navigation)
Passage('/settings', (_) => SettingsScreen(), name: 'settings')

// With custom transition
Passage('/modal', (_) => ModalScreen(), shift: Shift.slideUp())

// Nested passages
Passage('/settings', (_) => SettingsScreen(), passages: [
  Passage('/settings/account', (_) => AccountScreen()),
  Passage('/settings/privacy', (_) => PrivacyScreen()),
])
```

## Waypoint — Route State

Every Passage builder receives a **Waypoint** containing the resolved navigation state:

```dart
Passage('/user/:id', (waypoint) {
  final id = waypoint.runes['id']!;     // Path parameters
  final tab = waypoint.query['tab'];     // Query parameters
  final data = waypoint.extra;           // Extra data
  final path = waypoint.path;            // Full matched path
  final pattern = waypoint.pattern;      // Route pattern
  final rest = waypoint.remaining;       // Wildcard remainder
  
  return UserScreen(id: id, tab: tab);
})
```

## Navigation

### Static API

```dart
// Navigate to a path
Atlas.to('/profile/42');

// Navigate with query parameters
Atlas.to('/search?q=dart&page=2');

// Navigate with extra data
Atlas.to('/detail', extra: myObject);

// Navigate by name
Atlas.toNamed('profile', runes: {'id': '42'});

// Replace current route (no stack entry)
Atlas.replace('/home');

// Go back
Atlas.back();

// Go back to a specific route
Atlas.backTo('/home');

// Reset stack to a single route
Atlas.reset('/login');

// Current waypoint
final wp = Atlas.current;

// Can go back?
if (Atlas.canBack) Atlas.back();
```

### Context Extension

```dart
// Same API available via BuildContext
context.atlas.to('/profile/42');
context.atlas.back();
context.atlas.replace('/home');
context.atlas.toNamed('profile', runes: {'id': '42'});

// Get current waypoint
final wp = context.atlas.waypoint;
```

## Sanctum — Shell Routes

A **Sanctum** wraps child Passages in a persistent layout (tab bar, navigation rail, drawer, etc.):

```dart
Atlas(
  passages: [
    Sanctum(
      shell: (child) => Scaffold(
        body: child,
        bottomNavigationBar: const AppNavBar(),
      ),
      passages: [
        Passage('/home', (_) => HomeScreen()),
        Passage('/search', (_) => SearchScreen()),
        Passage('/profile', (_) => ProfileScreen()),
      ],
    ),
    // Routes outside Sanctum have no shell
    Passage('/login', (_) => LoginScreen()),
  ],
)
```

The shell widget stays mounted while child Passages change, preserving state.

## Sentinel — Route Guards

**Sentinels** intercept navigation and can redirect:

```dart
Atlas(
  passages: [...],
  sentinels: [
    // Guard all routes
    Sentinel((path, waypoint) {
      if (!isLoggedIn) return '/login';
      return null; // Allow passage
    }),

    // Guard specific paths only
    Sentinel.only(
      paths: {'/admin', '/billing'},
      guard: (path, _) => isAdmin ? null : '/403',
    ),

    // Guard everything except public paths
    Sentinel.except(
      paths: {'/login', '/register', '/'},
      guard: (path, _) => isLoggedIn ? null : '/login',
    ),

    // Async guard (e.g., check remote permissions)
    Sentinel.async((path, waypoint) async {
      final allowed = await checkPermission(path);
      return allowed ? null : '/no-access';
    }),
  ],
)
```

## Drift — Redirects

**Drift** is a global redirect function applied before Sentinels:

```dart
Atlas(
  passages: [...],
  drift: (path, waypoint) {
    // Redirect old URLs
    if (path == '/old-page') return '/new-page';
    // Redirect based on state
    if (path == '/' && hasCompletedOnboarding) return '/home';
    return null; // No redirect
  },
)
```

## Shift — Page Transitions

**Shifts** control page transition animations:

```dart
// Built-in shifts
Passage('/a', (_) => A(), shift: Shift.fade())
Passage('/b', (_) => B(), shift: Shift.slide())      // Right to left
Passage('/c', (_) => C(), shift: Shift.slideUp())     // Bottom to top
Passage('/d', (_) => D(), shift: Shift.scale())       // Scale + fade
Passage('/e', (_) => E(), shift: Shift.none())        // Instant

// Custom shift
Passage('/f', (_) => F(), shift: Shift.custom(
  duration: Duration(milliseconds: 500),
  builder: (context, anim, secondaryAnim, child) {
    return RotationTransition(turns: anim, child: child);
  },
))

// Default shift for all routes
Atlas(
  defaultShift: Shift.fade(),
  passages: [...],
)
```

## 404 Error Handling

```dart
Atlas(
  passages: [...],
  // Custom 404 page
  onError: (path) => NotFoundScreen(path: path),
)
```

Without `onError`, Atlas shows a default 404 page.

## Runes — Path Parameters

Dynamic path segments prefixed with `:` are extracted as **Runes**:

```dart
// Pattern: /org/:orgId/repo/:repoId
// Path:    /org/ikolvi/repo/titan
// Runes:   {'orgId': 'ikolvi', 'repoId': 'titan'}

Passage('/org/:orgId/repo/:repoId', (wp) {
  final org = wp.runes['orgId']!;
  final repo = wp.runes['repoId']!;
  return RepoScreen(org: org, repo: repo);
})
```

## Performance

Atlas uses a **trie-based route matcher** for O(k) path resolution where k is the number of path segments. This means:

- Route matching time is independent of the total number of routes
- Priority ordering: static > dynamic > wildcard (no ambiguity)
- Zero regex — pure string segment matching
- Minimal allocations during matching

## Integration with Titan State

Atlas works seamlessly with Pillar, Vestige, and Beacon:

```dart
void main() {
  final atlas = Atlas(
    passages: [...],
    sentinels: [
      Sentinel((path, _) {
        // Access Pillars via Titan DI
        final auth = Titan.get<AuthPillar>();
        return auth.isLoggedIn.value ? null : '/login';
      }),
    ],
  );

  runApp(
    Beacon(
      pillars: [AuthPillar.new, AppPillar.new],
      child: MaterialApp.router(routerConfig: atlas.config),
    ),
  );
}
```

## Full Example

```dart
import 'package:flutter/material.dart';
import 'package:titan_atlas/titan_atlas.dart';
import 'package:titan_bastion/titan_bastion.dart';

void main() {
  final atlas = Atlas(
    passages: [
      Sanctum(
        shell: (child) => AppShell(child: child),
        passages: [
          Passage('/', (_) => const HomeScreen(), name: 'home'),
          Passage('/search', (_) => const SearchScreen(), name: 'search'),
        ],
      ),
      Passage('/profile/:id', (wp) => ProfileScreen(id: wp.runes['id']!)),
      Passage('/login', (_) => const LoginScreen()),
    ],
    sentinels: [
      Sentinel.except(
        paths: {'/login', '/'},
        guard: (path, _) => isLoggedIn ? null : '/login',
      ),
    ],
    drift: (path, _) {
      if (path == '/old') return '/';
      return null;
    },
    onError: (path) => NotFoundScreen(path: path),
  );

  runApp(
    Beacon(
      pillars: [AuthPillar.new],
      child: MaterialApp.router(routerConfig: atlas.config),
    ),
  );
}
```
