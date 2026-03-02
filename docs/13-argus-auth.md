# Argus — Authentication & Authorization

**Package:** `titan_argus` · **Named for:** Argus Panoptes, the hundred-eyed giant who sees all

Titan's authentication and authorization package provides a structured auth base class, pre-built route guards, and reactive route re-evaluation — everything you need to secure an Atlas-routed app.

## The Argus Lexicon

| Standard Term | Titan Name | Class |
|---------------|------------|-------|
| Auth Base Class | **Argus** | `Argus` |
| Auth Guard Factory | **Garrison** | `Garrison` |
| Refresh Bridge | **CoreRefresh** | `CoreRefresh` |
| Guard Result | **GarrisonAuth** | `GarrisonAuth` |

## Installation

```yaml
dependencies:
  titan_argus: ^0.0.1
```

`titan_argus` re-exports `titan_atlas` (which re-exports `titan`), so a single import gives you the full stack.

```dart
import 'package:titan_argus/titan_argus.dart';
```

---

## Argus — Auth Pillar Base Class

`Argus` is an abstract `Pillar` that provides a standard contract for authentication:

```dart
class AuthPillar extends Argus {
  late final username = core<String?>(null);
  late final role = core<String?>('guest');

  @override
  Future<void> signIn([Map<String, dynamic>? credentials]) async {
    await strikeAsync('sign-in', () async {
      final name = credentials?['name'] as String? ?? 'Hero';
      username.value = name;
      role.value = credentials?['role'] as String? ?? 'user';
      isLoggedIn.value = true;
    });
  }

  @override
  void signOut() {
    strike('sign-out', () {
      username.value = null;
      role.value = 'guest';
      super.signOut(); // sets isLoggedIn.value = false
    });
  }
}
```

### Built-in API

| Member | Type | Description |
|--------|------|-------------|
| `isLoggedIn` | `Core<bool>` | Reactive auth state (starts `false`) |
| `signIn([credentials])` | `Future<void>` | Override to implement sign-in logic |
| `signOut()` | `void` | Override to implement sign-out logic (call `super.signOut()`) |
| `authCores` | `List<ReactiveNode>` | Reactive nodes that trigger route re-evaluation (default: `[isLoggedIn]`) |
| `guard(...)` | `GarrisonAuth` | Convenience — creates sentinels + refresh in one call |

### Custom authCores

Override `authCores` when additional signals should trigger route re-evaluation:

```dart
class AdminAuth extends Argus {
  late final role = core<String?>(null);
  late final subscription = core<String?>('free');

  @override
  List<ReactiveNode> get authCores => [isLoggedIn, role, subscription];

  // ...
}
```

Now when `role` or `subscription` changes, Sentinels are re-evaluated automatically.

---

## guard() — One-Call Auth Setup

The `guard()` method on any `Argus` subclass creates the full auth wiring in a single call:

```dart
final auth = Titan.get<AuthPillar>();

final (:sentinels, :refreshListenable) = auth.guard(
  loginPath: '/login',
  homePath: '/',
  publicPaths: {'/login', '/register', '/about'},
  guestPaths: {'/login', '/register'},
);

Atlas(
  passages: [...],
  sentinels: sentinels,
  refreshListenable: refreshListenable,
);
```

This creates:
- An `authGuard` Sentinel redirecting unauthenticated users to `loginPath`
- A `guestOnly` Sentinel redirecting authenticated users away from guest pages
- A `CoreRefresh` bridging `authCores` to Atlas's `refreshListenable`

---

## Garrison — Pre-Built Sentinel Factories

`Garrison` provides static factory methods for common auth patterns:

### authGuard

Redirects unauthenticated users to a login page:

```dart
Garrison.authGuard(
  isAuthenticated: () => auth.isLoggedIn.value,
  loginPath: '/login',
  publicPaths: {'/login', '/about'},  // never redirect these
  preserveRedirect: true,             // append ?redirect= for post-login
)
```

### guestOnly

Redirects authenticated users away from login/register pages:

```dart
Garrison.guestOnly(
  isAuthenticated: () => auth.isLoggedIn.value,
  redirectPath: '/',
  guestPaths: {'/login', '/register'},
  useRedirectQuery: true,  // read ?redirect= from URL
)
```

### roleGuard

Restrict routes to a specific role:

```dart
Garrison.roleGuard(
  currentRole: () => auth.role.value,
  requiredRole: 'admin',
  protectedPaths: {'/admin', '/admin/users'},
  redirectPath: '/unauthorized',
)
```

### rolesGuard

Restrict routes to any of a set of roles:

```dart
Garrison.rolesGuard(
  currentRole: () => auth.role.value,
  allowedRoles: {'admin', 'moderator'},
  protectedPaths: {'/admin'},
  redirectPath: '/unauthorized',
)
```

### onboardingGuard

Ensure users complete onboarding before accessing the app:

```dart
Garrison.onboardingGuard(
  isOnboarded: () => user.hasCompletedOnboarding.value,
  onboardingPath: '/onboarding',
  protectedPaths: {'/home', '/profile', '/settings'},
)
```

### composite / compositeAsync

Combine multiple guard checks into a single Sentinel:

```dart
Garrison.composite(
  guards: [
    (wp) => isAuthenticated ? null : '/login',
    (wp) => hasPermission(wp.path) ? null : '/forbidden',
  ],
)
```

### refreshAuth

Combines `authGuard` + `guestOnly` + `CoreRefresh` into a single factory call:

```dart
final garrisonAuth = Garrison.refreshAuth(
  isAuthenticated: () => auth.isLoggedIn.value,
  cores: [auth.isLoggedIn],
  loginPath: '/login',
  homePath: '/',
  publicPaths: {'/about'},
  guestPaths: {'/login', '/register'},
  preserveRedirect: true,
);

Atlas(
  passages: [...],
  sentinels: garrisonAuth.sentinels,
  refreshListenable: garrisonAuth.refresh,
);
```

---

## CoreRefresh — Reactive Route Re-evaluation

Sentinels only evaluate during navigation. When auth state changes *outside* of navigation (e.g., token expiry), routes need re-evaluation.

`CoreRefresh` bridges Titan's reactive `Core` signals to Flutter's `Listenable` interface:

```dart
Atlas(
  refreshListenable: CoreRefresh([auth.isLoggedIn, auth.role]),
  // ...
);
```

When any monitored signal changes, Atlas re-evaluates all Sentinels. This means:
- **Sign-out** on `/profile` → Sentinel redirects to `/login`
- **Sign-in** on `/login` → Sentinel redirects to `/` (or to `?redirect=` path)

### Any Listenable Works

`refreshListenable` accepts any Flutter `Listenable`, not just `CoreRefresh`:

```dart
// Flutter ValueNotifier
Atlas(refreshListenable: ValueNotifier<bool>(false), ...);

// Custom ChangeNotifier
Atlas(refreshListenable: myChangeNotifier, ...);
```

---

## Post-Login Redirect Flow

When `preserveRedirect` is enabled (default), the complete flow is:

1. User visits `/quest/42` while unauthenticated
2. `authGuard` redirects to `/login?redirect=%2Fquest%2F42`
3. User signs in → `CoreRefresh` triggers Sentinel re-evaluation
4. `guestOnly` reads the `redirect` query parameter → navigates to `/quest/42`

---

## Complete Example

```dart
import 'package:titan_argus/titan_argus.dart';

// 1. Define your auth Pillar
class AuthPillar extends Argus {
  late final username = core<String?>(null);

  @override
  Future<void> signIn([Map<String, dynamic>? credentials]) async {
    await strikeAsync('sign-in', () async {
      username.value = credentials?['name'] as String?;
      isLoggedIn.value = true;
    });
  }

  @override
  void signOut() {
    strike('sign-out', () {
      username.value = null;
      super.signOut();
    });
  }
}

// 2. Wire up routing
void main() {
  final auth = Titan.put(AuthPillar());

  final (:sentinels, :refreshListenable) = auth.guard(
    loginPath: '/login',
    publicPaths: {'/login'},
    guestPaths: {'/login'},
  );

  runApp(MaterialApp.router(
    routerConfig: Atlas(
      passages: [
        Passage('/', (_) => const HomeScreen()),
        Passage('/login', (_) => const LoginScreen()),
        Passage('/profile', (_) => const ProfileScreen()),
      ],
      sentinels: sentinels,
      refreshListenable: refreshListenable,
    ),
  ));
}
```

---

## Testing

```dart
test('sign in updates auth state', () async {
  final auth = AuthPillar();
  expect(auth.isLoggedIn.value, false);

  await auth.signIn({'name': 'Atlas'});
  expect(auth.isLoggedIn.value, true);
  expect(auth.username.value, 'Atlas');

  auth.signOut();
  expect(auth.isLoggedIn.value, false);
  expect(auth.username.value, null);

  auth.dispose();
});
```

Run tests:

```bash
cd packages/titan_argus && flutter test  # 57+ tests
```

---

[← Atlas Routing](12-atlas-routing.md) · [Colossus Monitoring →](14-colossus-monitoring.md)
