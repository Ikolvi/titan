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
| Refresh Bridge | **CoreRefresh** | Reactive route re-evaluation |
| Observer | **AtlasObserver** | Watches all navigation events |
| Deep Link Mapper | **Cartograph** | Maps external URLs to internal routes |

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

// With metadata (accessible via waypoint.metadata)
Passage('/admin', (_) => AdminScreen(),
  name: 'admin',
  metadata: {'title': 'Admin Panel', 'icon': Icons.settings},
)

// With per-route redirect
Passage('/old-dashboard', (_) => DashboardScreen(),
  redirect: (wp) => '/dashboard',  // Always redirect
)

// Conditional per-route redirect
Passage('/premium', (wp) => PremiumScreen(),
  redirect: (wp) => isPremiumUser ? null : '/upgrade',
)

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
  final meta = waypoint.metadata;        // Route metadata
  final name = waypoint.name;            // Route name
  
  return UserScreen(id: id, tab: tab);
})
```

### Type-Safe Rune Accessors

Waypoint provides type-safe accessors for Runes and query parameters, eliminating manual parsing:

```dart
Passage('/product/:id', (wp) {
  // Parse Runes to specific types
  final id = wp.intRune('id');           // int?
  final price = wp.doubleRune('price');  // double?
  final active = wp.boolRune('active');  // bool?

  // Parse query parameters to specific types
  final page = wp.intQuery('page');      // int?
  final rating = wp.doubleQuery('min');  // double?
  final asc = wp.boolQuery('asc');       // bool?

  return ProductScreen(id: id ?? 0, page: page ?? 1);
})
```

`boolRune` and `boolQuery` recognize `'true'` and `'1'` as `true`, everything else as `false`.
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

Async Sentinels are fully resolved during navigation — Atlas automatically detects whether any Sentinels are async and uses the appropriate resolution path.

## CoreRefresh — Reactive Route Re-evaluation

> **Note:** `CoreRefresh`, `Garrison`, and `Argus` now live in the `titan_argus` package. Import via `import 'package:titan_argus/titan_argus.dart';`. See [Argus Auth](13-argus-auth.md) for full documentation.

Sentinels only evaluate during navigation (`Atlas.to()`, `.replace()`, etc.). When auth state changes outside of navigation — like a token expiring or the user signing in — Sentinels aren't automatically re-evaluated.

**CoreRefresh** bridges this gap by converting Titan's reactive `Core` signals into a Flutter `Listenable` that Atlas observes:

```dart
class AuthPillar extends Pillar {
  late final isLoggedIn = core(false);
}

final auth = Titan.get<AuthPillar>();

final atlas = Atlas(
  passages: [
    Passage('/', (_) => HomeScreen()),
    Passage('/login', (_) => LoginScreen()),
    Passage('/profile', (_) => ProfileScreen()),
  ],
  sentinels: [
    // Redirect unauthenticated users to /login
    Garrison.authGuard(
      isAuthenticated: () => auth.isLoggedIn.value,
      loginPath: '/login',
      publicPaths: {'/login'},
    ),
    // Redirect authenticated users away from /login
    Garrison.guestOnly(
      isAuthenticated: () => auth.isLoggedIn.value,
      redirectPath: '/',
      guestPaths: {'/login'},
    ),
  ],
  // Re-evaluate Sentinels when auth state changes
  refreshListenable: CoreRefresh([auth.isLoggedIn]),
);
```

Now when `auth.isLoggedIn.value` changes:
- **Sign-out** on `/profile` → Sentinel redirects to `/login`
- **Sign-in** on `/login` → Sentinel redirects to `/`

### Multiple Signals

Monitor multiple reactive values — re-evaluation triggers when *any* changes:

```dart
CoreRefresh([auth.isLoggedIn, auth.role, subscription.tier])
```

### Any Listenable Works

`refreshListenable` accepts any Flutter `Listenable`, not just `CoreRefresh`:

```dart
// Flutter ValueNotifier
final authNotifier = ValueNotifier<bool>(false);
Atlas(refreshListenable: authNotifier, ...);

// Custom ChangeNotifier
class AppState extends ChangeNotifier { ... }
Atlas(refreshListenable: appState, ...);
```

### Garrison.refreshAuth — One-Call Setup

`Garrison.refreshAuth` combines `authGuard`, `guestOnly`, and `CoreRefresh` into a single factory:

```dart
final garrisonAuth = Garrison.refreshAuth(
  isAuthenticated: () => auth.isLoggedIn.value,
  cores: [auth.isLoggedIn],
  loginPath: '/login',
  homePath: '/',
  publicPaths: {'/about'},
  guestPaths: {'/login', '/register'},
);

Atlas(
  passages: [...],
  sentinels: garrisonAuth.sentinels,
  refreshListenable: garrisonAuth.refresh,
);
```

This replaces the manual wiring of separate `Garrison.authGuard()`, `Garrison.guestOnly()`, and `CoreRefresh()` calls.

### Post-Login Redirect

When `preserveRedirect` is enabled (default), users are automatically returned to their originally requested page after signing in:

1. User visits `/quest/42` while unauthenticated
2. `authGuard` redirects to `/login?redirect=%2Fquest%2F42`
3. User signs in → `CoreRefresh` triggers re-evaluation
4. `guestOnly` reads the `redirect` query parameter and navigates to `/quest/42`

```dart
final garrisonAuth = Garrison.refreshAuth(
  isAuthenticated: () => auth.isLoggedIn.value,
  cores: [auth.isLoggedIn],
  loginPath: '/login',
  homePath: '/',
  guestPaths: {'/login'},
  preserveRedirect: true, // default
);
```

The `guestOnly` Sentinel checks for a `redirect` query parameter by default (`useRedirectQuery: true`). When the user signs in on a login page with `?redirect=<path>`, they're sent to the decoded redirect path instead of the default `homePath`.

To disable this behavior:

```dart
Garrison.guestOnly(
  isAuthenticated: () => auth.isLoggedIn.value,
  guestPaths: {'/login'},
  redirectPath: '/',
  useRedirectQuery: false, // always redirect to redirectPath
);
```

### How It Works

1. When the `Listenable` notifies, Atlas re-resolves the current path through **Drift → Sentinels → per-route redirect**
2. If the resolved path differs from the current path → `Atlas.reset()` to the new destination
3. If the path is unchanged → no-op (no unnecessary navigation)
4. Re-entrant calls are guarded — rapid state changes don't cause stack overflow
5. Both sync and async Sentinels are handled automatically

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

## AtlasObserver — Navigation Lifecycle

**AtlasObserver** monitors all navigation events — ideal for analytics, logging, and debugging:

```dart
Atlas(
  passages: [...],
  observers: [AtlasLoggingObserver()],  // Built-in console logger
)
```

### Custom Observer

```dart
class AnalyticsObserver extends AtlasObserver {
  @override
  void onNavigate(String path, Waypoint waypoint) {
    analytics.trackPageView(path);
  }

  @override
  void onGuardRedirect(String from, String to) {
    analytics.trackEvent('guard_redirect', {'from': from, 'to': to});
  }

  @override
  void onNotFound(String path) {
    analytics.trackEvent('404', {'path': path});
  }
}
```

### Observer Hooks

| Hook | When Fired |
|------|-----------|
| `onNavigate(path, waypoint)` | After successful navigation |
| `onReplace(path)` | After route replacement |
| `onPop()` | After going back |
| `onReset(path)` | After stack reset |
| `onGuardRedirect(from, to)` | When a Sentinel redirects |
| `onDriftRedirect(from, to)` | When a Drift redirects |
| `onNotFound(path)` | When no route matches |

### Multiple Observers

```dart
Atlas(
  passages: [...],
  observers: [
    AtlasLoggingObserver(),  // Debug logging
    AnalyticsObserver(),     // Analytics tracking
    PerformanceObserver(),   // Performance monitoring
  ],
)
```

## Per-Route Redirects

Beyond global Drift and Sentinels, individual Passages can define their own redirect logic:

```dart
Atlas(
  passages: [
    // Always redirect
    Passage('/old', (_) => Container(), redirect: (wp) => '/new'),

    // Conditional redirect
    Passage('/premium', (_) => PremiumScreen(),
      redirect: (wp) => hasPremium ? null : '/upgrade',
    ),

    // Redirect based on Runes
    Passage('/user/:id', (wp) => UserScreen(id: wp.runes['id']!),
      redirect: (wp) => wp.runes['id'] == '0' ? '/users' : null,
    ),
  ],
)
```

Redirect evaluation order: **Drift** → **Sentinel** → **Per-route redirect**.

## Route Metadata

Passages can carry arbitrary metadata accessible via Waypoint:

```dart
Atlas(
  passages: [
    Passage('/', (_) => HomeScreen(),
      name: 'home',
      metadata: {'title': 'Home', 'showAppBar': true},
    ),
    Passage('/settings', (_) => SettingsScreen(),
      name: 'settings',
      metadata: {'title': 'Settings', 'requiresAuth': true},
    ),
  ],
)

// Access in builder
Passage('/page', (wp) {
  final title = wp.metadata?['title'] as String?;
  return Scaffold(
    appBar: AppBar(title: Text(title ?? 'Untitled')),
    body: PageContent(),
  );
})
```

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

### Type-Safe Rune Accessors

Parse Runes and query parameters directly to the type you need:

```dart
Passage('/item/:id', (wp) {
  // Path parameters
  final id = wp.intRune('id');           // int?
  final weight = wp.doubleRune('wt');    // double?
  final flag = wp.boolRune('active');    // bool?

  // Query parameters (/item/5?page=2&asc=true)
  final page = wp.intQuery('page');      // int?
  final min = wp.doubleQuery('min');     // double?
  final asc = wp.boolQuery('asc');       // bool?

  return ItemScreen(id: id ?? 0);
})
```

## Performance

Atlas uses a **trie-based route matcher** for O(k) path resolution where k is the number of path segments. This means:

- Route matching time is independent of the total number of routes
- Priority ordering: static > dynamic > wildcard (no ambiguity)
- Zero regex — pure string segment matching
- Minimal allocations during matching

## Integration with Titan State

Atlas integrates directly with Titan's DI — Pillars can be registered at three scopes with zero boilerplate.

### Global Pillars

Registered when Atlas is created, accessible everywhere, persist for the app's lifetime:

```dart
Atlas(
  pillars: [AuthPillar.new, AppPillar.new],
  passages: [...],
)

// Access anywhere — in builders, Sentinels, observers
final auth = Titan.get<AuthPillar>();
```

### Route-Scoped Pillars

Auto-created when the route is pushed, auto-disposed when it leaves the stack:

```dart
Passage('/checkout', (wp) {
  final checkout = Titan.get<CheckoutPillar>();
  return CheckoutScreen(total: checkout.total.value);
}, pillars: [CheckoutPillar.new, PaymentPillar.new])
```

Navigate to `/checkout` → `CheckoutPillar` and `PaymentPillar` are created.
Navigate away → both are disposed and removed from Titan.

### Shell-Scoped Pillars

Attached to a Sanctum — live as long as any passage within the shell is on the stack:

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

### Combined — Zero Boilerplate

```dart
void main() {
  final atlas = Atlas(
    pillars: [AuthPillar.new],           // Global — entire app
    passages: [
      Sanctum(
        pillars: [DashboardPillar.new],  // Shell-scoped
        shell: (child) => AppShell(child: child),
        passages: [
          Passage('/', (_) => HomeScreen()),
          Passage('/search', (_) => SearchScreen()),
        ],
      ),
      Passage('/checkout', (wp) => CheckoutScreen(),
        pillars: [CheckoutPillar.new],   // Route-scoped
      ),
    ],
    sentinels: [
      Sentinel((path, _) {
        final auth = Titan.get<AuthPillar>();
        return auth.isLoggedIn.value ? null : '/login';
      }),
    ],
  );

  // No Beacon wrapper needed — Atlas handles all DI
  runApp(MaterialApp.router(routerConfig: atlas.config));
}
```

This replaces:
```dart
// OLD — manual Beacon wrapping
runApp(
  Beacon(
    pillars: [AuthPillar.new, AppPillar.new],
    child: MaterialApp.router(routerConfig: atlas.config),
  ),
);
```

## Cartograph — Deep Link Mapping

**Cartograph** is a static utility for deep link parsing, URL building, and named route mapping. Named for the ancient map-makers, it maps between external URLs and internal Atlas routes.

### Named Routes

Register routes by name for type-safe URL building:

```dart
Cartograph.name('user-profile', '/users/:id');
Cartograph.name('settings', '/settings');

// Or batch register
Cartograph.nameAll({
  'home': '/',
  'profile': '/users/:id',
  'settings': '/settings',
});
```

### URL Building

Build URLs from named routes with parameter substitution:

```dart
final url = Cartograph.build('profile',
  runes: {'id': '42'},
  query: {'tab': 'posts'},
);
// → '/users/42?tab=posts'
```

Or build from a template directly:

```dart
final url = Cartograph.buildFromTemplate(
  '/users/:id',
  runes: {'id': '42'},
);
// → '/users/42'
```

### Deep Link Parsing

Parse incoming URIs against registered patterns:

```dart
final match = Cartograph.parse(Uri.parse('/users/42?tab=posts'));
// match.path == '/users/:id'
// match.runes == {'id': '42'}
// match.query == {'tab': 'posts'}
```

### Deep Link Handling

Register handlers for incoming deep links:

```dart
Cartograph.link('/users/:id', (match) {
  Atlas.go('/users/${match.runes['id']}');
});

// Handle incoming link
final handled = Cartograph.handleDeepLink(
  Uri.parse('myapp://users/42'),
); // true if handler found and invoked
```

### API Reference

| Method | Return | Description |
|--------|--------|-------------|
| `name(routeName, path)` | `void` | Register a named route |
| `nameAll(Map)` | `void` | Register multiple named routes |
| `pathFor(routeName)` | `String?` | Look up path template by name |
| `hasName(routeName)` | `bool` | Check if name is registered |
| `routeNames` | `Set<String>` | All registered names |
| `build(name, {runes, query})` | `String` | Build URL from named route |
| `buildFromTemplate(template, {runes, query})` | `String` | Build URL from template |
| `link(template, [handler])` | `void` | Register deep link pattern |
| `parse(Uri)` | `CartographMatch?` | Match URI against registered patterns |
| `handleDeepLink(Uri)` | `bool` | Parse + invoke handler |
| `reset()` | `void` | Clear all registrations |

---

## Full Example

```dart
import 'package:flutter/material.dart';
import 'package:titan_atlas/titan_atlas.dart';

void main() {
  final atlas = Atlas(
    pillars: [AuthPillar.new],
    passages: [
      Sanctum(
        shell: (child) => AppShell(child: child),
        passages: [
          Passage('/', (_) => const HomeScreen(),
            name: 'home',
            metadata: {'title': 'Home'},
          ),
          Passage('/search', (_) => const SearchScreen(),
            name: 'search',
            metadata: {'title': 'Search'},
          ),
        ],
      ),
      Passage('/profile/:id', (wp) {
        final id = wp.intRune('id') ?? 0;
        return ProfileScreen(id: id);
      }),
      Passage('/checkout', (wp) => CheckoutScreen(),
        pillars: [CheckoutPillar.new],
      ),
      Passage('/login', (_) => const LoginScreen()),
      Passage('/old-page', (_) => Container(),
        redirect: (wp) => '/new-page',
      ),
    ],
    sentinels: [
      Sentinel.except(
        paths: {'/login', '/'},
        guard: (path, _) {
          final auth = Titan.get<AuthPillar>();
          return auth.isLoggedIn.value ? null : '/login';
        },
      ),
    ],
    drift: (path, _) {
      if (path == '/old') return '/';
      return null;
    },
    observers: [AtlasLoggingObserver()],
    onError: (path) => NotFoundScreen(path: path),
  );

  runApp(MaterialApp.router(routerConfig: atlas.config));
}
```
