# Atlas

**Titan's routing & navigation system** — declarative, zero-boilerplate, high-performance page management for Flutter.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/Ikolvi/titan/blob/main/LICENSE)
[![Dart](https://img.shields.io/badge/Dart-%5E3.10-blue)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-%5E3.38-blue)](https://flutter.dev)

Part of the [Titan](https://github.com/Ikolvi/titan) ecosystem.

---

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

---

## Quick Start

```bash
flutter pub add titan_atlas
```

Or see the latest version on [pub.dev](https://pub.dev/packages/titan_atlas/install).

```dart
import 'package:titan_atlas/titan_atlas.dart';

final atlas = Atlas(
  passages: [
    Passage('/', (_) => const HomeScreen()),
    Passage('/profile/:id', (wp) => ProfileScreen(id: wp.runes['id']!)),
  ],
);

void main() => runApp(
  MaterialApp.router(routerConfig: atlas.config),
);
```

**That's it. No code generation. No boilerplate.**

---

## Features

### Passages — Route Definitions

```dart
// Static
Passage('/home', (_) => HomeScreen())

// Dynamic (Runes)
Passage('/user/:id', (wp) => UserScreen(id: wp.runes['id']!))

// Wildcard
Passage('/files/*', (wp) => FileViewer(path: wp.remaining!))

// Named
Passage('/settings', (_) => SettingsScreen(), name: 'settings')

// With transition
Passage('/modal', (_) => ModalScreen(), shift: Shift.slideUp())
```

### Navigation

```dart
// Static API
Atlas.to('/profile/42');
Atlas.to('/search?q=dart');
Atlas.to('/detail', extra: myData);
Atlas.toNamed('profile', runes: {'id': '42'});
Atlas.replace('/home');
Atlas.back();
Atlas.backTo('/home');
Atlas.reset('/login');

// Context extension
context.atlas.to('/profile/42');
context.atlas.back();
```

### Sanctum — Shell Routes

```dart
Sanctum(
  shell: (child) => Scaffold(
    body: child,
    bottomNavigationBar: const AppNavBar(),
  ),
  passages: [
    Passage('/home', (_) => HomeScreen()),
    Passage('/search', (_) => SearchScreen()),
  ],
)
```

### Sentinel — Route Guards

```dart
// Guard all routes
Sentinel((path, _) => isLoggedIn ? null : '/login')

// Guard specific paths
Sentinel.only(paths: {'/admin'}, guard: (_, __) => '/login')

// Exclude public paths
Sentinel.except(paths: {'/login', '/'}, guard: (_, __) => '/login')

// Async guard
Sentinel.async((path, _) async {
  final ok = await checkPermission(path);
  return ok ? null : '/403';
})
```

### Shift — Transitions

```dart
Shift.fade()      // Fade in/out
Shift.slide()     // Slide from right
Shift.slideUp()   // Slide from bottom
Shift.scale()     // Scale + fade
Shift.none()      // Instant
Shift.custom(builder: ...)  // Your own
```

### Drift — Redirects

```dart
Atlas(
  drift: (path, _) {
    if (path == '/old') return '/new';
    return null;
  },
  passages: [...],
)
```

---

## Performance

Atlas uses a **trie-based route matcher** for O(k) path resolution where k is the number of path segments — matching time is independent of total route count.

---

## Observer — Analytics & Logging

```dart
class AnalyticsObserver extends AtlasObserver {
  @override
  void onNavigate(Waypoint from, Waypoint to) {
    analytics.trackScreen(to.path);
  }
  
  @override
  void onGuardRedirect(String from, String to) {
    analytics.trackRedirect(from, to);
  }
}

Atlas(
  passages: [...],
  observers: [AnalyticsObserver(), AtlasLoggingObserver()],
)
```

### HeraldAtlasObserver — Cross-Domain Route Events

Bridge Atlas navigation into Titan's Herald event bus automatically:

```dart
import 'package:titan/titan.dart';
import 'package:titan_atlas/titan_atlas.dart';

Atlas(
  passages: [...],
  observers: [HeraldAtlasObserver()],
)

// Listen for navigation events anywhere in your app
class AnalyticsPillar extends Pillar {
  @override
  void onInit() {
    listen<AtlasRouteChanged>((event) {
      trackScreen(event.toPath);
    });
    listen<AtlasGuardRedirect>((event) {
      log.warning('Guard redirected from ${event.from} to ${event.to}');
    });
  }
}
```

Emits `AtlasRouteChanged`, `AtlasGuardRedirect`, `AtlasDriftRedirect`, and `AtlasRouteNotFound` events.

## Type-Safe Runes

```dart
Passage('/user/:id', (wp) {
  final id = wp.intRune('id')!;    // int
  final page = wp.intQuery('page'); // int?
  return UserScreen(id: id, page: page);
})
```

## Per-Route Redirects

```dart
Passage('/old-page', (_) => Container(),
  redirect: (wp) => '/new-page',
)
```

## Route Metadata

```dart
Passage('/admin', (wp) => AdminScreen(),
  metadata: {'title': 'Admin Panel', 'icon': 'shield'},
)

// Access in builder or observer
final title = waypoint.metadata?['title'];
```

---

## Works with Titan State

Atlas integrates directly with Titan's DI — no extra wiring needed.

### Global Pillars

Register app-wide Pillars that persist for the entire app lifecycle:

```dart
Atlas(
  pillars: [AuthPillar.new, AppPillar.new],
  passages: [...],
)

// Access anywhere
final auth = Titan.get<AuthPillar>();
```

### Route-Scoped Pillars

Pillars auto-created when a route is entered, auto-disposed when it leaves:

```dart
Passage('/checkout', (wp) => CheckoutScreen(),
  pillars: [CheckoutPillar.new, PaymentPillar.new],
)
```

### Shell-Scoped Pillars

Pillars that live as long as any passage within the Sanctum is active:

```dart
Sanctum(
  pillars: [DashboardPillar.new],
  shell: (child) => DashboardLayout(child: child),
  passages: [
    Passage('/overview', (_) => OverviewScreen()),
    Passage('/analytics', (_) => AnalyticsScreen()),
  ],
)
```

### Zero-Boilerplate Setup

```dart
void main() {
  final atlas = Atlas(
    pillars: [AuthPillar.new],  // Global DI — no Beacon wrapper needed
    passages: [
      Passage('/', (_) => HomeScreen()),
      Passage('/checkout', (_) => CheckoutScreen(),
        pillars: [CheckoutPillar.new],  // Route-scoped
      ),
    ],
  );

  runApp(MaterialApp.router(routerConfig: atlas.config));
}
```

---

## Packages

| Package | Description |
|---------|-------------|
| [`titan`](https://pub.dev/packages/titan) | Core reactive engine |
| [`titan_bastion`](https://pub.dev/packages/titan_bastion) | Flutter widgets (Vestige, Beacon) |
| **`titan_atlas`** | Routing & navigation (this package) |

## Documentation

| Guide | Link |
|-------|------|
| Introduction | [01-introduction.md](https://github.com/Ikolvi/titan/blob/main/docs/01-introduction.md) |
| Getting Started | [02-getting-started.md](https://github.com/Ikolvi/titan/blob/main/docs/02-getting-started.md) |
| Core Concepts | [03-core-concepts.md](https://github.com/Ikolvi/titan/blob/main/docs/03-core-concepts.md) |
| Pillars | [04-stores.md](https://github.com/Ikolvi/titan/blob/main/docs/04-stores.md) |
| Flutter Integration | [05-flutter-integration.md](https://github.com/Ikolvi/titan/blob/main/docs/05-flutter-integration.md) |
| Middleware | [06-middleware.md](https://github.com/Ikolvi/titan/blob/main/docs/06-middleware.md) |
| Testing | [07-testing.md](https://github.com/Ikolvi/titan/blob/main/docs/07-testing.md) |
| Advanced Patterns | [08-advanced-patterns.md](https://github.com/Ikolvi/titan/blob/main/docs/08-advanced-patterns.md) |
| API Reference | [09-api-reference.md](https://github.com/Ikolvi/titan/blob/main/docs/09-api-reference.md) |
| Migration Guide | [10-migration-guide.md](https://github.com/Ikolvi/titan/blob/main/docs/10-migration-guide.md) |
| Architecture | [11-architecture.md](https://github.com/Ikolvi/titan/blob/main/docs/11-architecture.md) |
| Atlas Routing | [12-atlas-routing.md](https://github.com/Ikolvi/titan/blob/main/docs/12-atlas-routing.md) |

## License

MIT — [Ikolvi](https://ikolvi.com)
