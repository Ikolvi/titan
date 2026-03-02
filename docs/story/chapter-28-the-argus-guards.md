# Chapter XXVIII: The Argus Guards

*The Chronicles of Titan — A Developer's Odyssey*

---

> *"Before the Argus rose, every builder fashioned their own locks, their own keys, their own wards. Some forgot to bar the back door. Others built doors that only opened from inside. The Argus brought order — a single watchful guardian whose hundred eyes never closed."*

---

## The Problem with Ad-Hoc Guards

Kael stared at the growing tangle in `AuthPillar`. It had started as a simple Pillar with an `isLoggedIn` Core and a `signIn` Strike. Clean and focused. But every new feature had added weight:

- Role-based access needed `role` and `permissions` Cores
- The login screen needed redirect preservation
- Guest-only guards needed their own Sentinel
- `CoreRefresh` needed to track multiple auth signals
- The `Garrison.refreshAuth()` call was repeated in every app that used auth

Worse, the auth logic was scattered across three packages. `CoreRefresh` lived in `titan_atlas` — a routing package. `Garrison` lived there too. The `AuthPillar` itself extended plain `Pillar`. Nothing was *wrong*, but nothing was *right* either.

*"Authentication isn't navigation,"* Kael muttered. *"And it isn't just state management. It's its own domain."*

---

## The Watchful Guardian

The solution was `titan_argus` — a dedicated authentication and authorization package that sat between `titan` (the reactive engine) and `titan_atlas` (the router). Named after Argus Panoptes, the hundred-eyed giant of Greek mythology, it provided a single base class that unified every auth concern:

```dart
import 'package:titan_argus/titan_argus.dart';

class AuthPillar extends Argus {
  late final username = core<String?>(null);

  late final greeting = derived(
    () => username.value != null ? 'Welcome, ${username.value}!' : 'Welcome!',
  );

  @override
  Future<void> signIn([Map<String, dynamic>? credentials]) async {
    await strikeAsync('sign-in', () async {
      final name = credentials?['name'] as String? ?? 'Hero';
      username.value = name;
      isLoggedIn.value = true;
    });
  }

  @override
  void signOut() {
    strike('sign-out', () {
      username.value = null;
      super.signOut(); // sets isLoggedIn.value = false
    });
  }
}
```

No boilerplate. The `Argus` base class provided `isLoggedIn` automatically. Kael just added domain-specific state and overrode `signIn`.

---

## What Argus Provides

### The isLoggedIn Core

Every `Argus` subclass starts with a reactive `isLoggedIn` Core defaulting to `false`:

```dart
abstract class Argus extends Pillar {
  late final isLoggedIn = core(false);
}
```

No need to declare it. No need to remember the name. It's always there, always consistent across every auth Pillar in every app.

### The signIn / signOut Contract

`Argus` defines the auth lifecycle as an explicit contract:

```dart
// Abstract — you must implement this
Future<void> signIn([Map<String, dynamic>? credentials]);

// Default implementation — override to add cleanup
void signOut() {
  isLoggedIn.value = false;
}
```

The `signIn` method accepts an optional credentials map, making it flexible enough for username/password, OAuth tokens, biometric results, or any auth mechanism.

### The authCores Getter

For advanced scenarios — role changes, permission updates, feature flag toggles — `Argus` exposes `authCores`:

```dart
@override
List<ReactiveNode> get authCores => [isLoggedIn, role, permissions];
```

By default, `authCores` returns `[isLoggedIn]`. Override it to include additional signals that should trigger route re-evaluation via `CoreRefresh`.

### The guard() Convenience

The killer feature: a single method call that wires up the entire auth routing pipeline:

```dart
final auth = Titan.get<AuthPillar>();

final (:sentinels, :refreshListenable) = auth.guard(
  loginPath: '/login',
  publicPaths: {'/login', '/register', '/about'},
  guestPaths: {'/login', '/register'},
);

Atlas(
  passages: [...],
  sentinels: sentinels,
  refreshListenable: refreshListenable,
);
```

One call. It creates:
- A `Garrison.authGuard` Sentinel for login redirect
- A `Garrison.guestOnly` Sentinel for login-page bounce
- A `CoreRefresh` bridge tracking all `authCores`

Before `guard()`, this setup required 15+ lines of manual wiring. Now it was three.

---

## The Architecture

```
┌──────────────────┐
│      titan       │  Reactive engine (Pillar, Core, Derived)
└────────┬─────────┘
         │
┌────────┴─────────┐
│   titan_argus    │  Auth base class (Argus), guards (Garrison),
│                  │  reactive bridge (CoreRefresh)
└────────┬─────────┘
         │
┌────────┴─────────┐
│   titan_atlas    │  Routing (Atlas, Passage, Sentinel, Sanctum)
└──────────────────┘
```

`titan_argus` depends on both `titan` (for `Pillar` and reactive types) and `titan_atlas` (for `Sentinel`, `Garrison`, and `CoreRefresh`). It re-exports `titan_atlas` for convenience — any file importing `titan_argus` gets the full routing and auth API.

---

## Wiring It in Questboard

Kael refactored the example app. The `AuthPillar` now extended `Argus`:

```dart
class AuthPillar extends Argus {
  late final username = core<String?>(null);
  late final greeting = derived(
    () => username.value != null ? 'Welcome, ${username.value}!' : 'Welcome!',
  );

  @override
  Future<void> signIn([Map<String, dynamic>? credentials]) async {
    await strikeAsync('sign-in', () async {
      final name = credentials?['name'] as String? ?? 'Hero';
      username.value = name;
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

  /// Convenience for the demo — no credentials needed.
  Future<void> signInAs(String name) =>
      signIn({'name': name});
}
```

And in `main.dart`, the routing setup collapsed to:

```dart
final auth = Titan.get<AuthPillar>();

final (:sentinels, :refreshListenable) = auth.guard(
  loginPath: '/login',
  publicPaths: {'/login', '/register', '/about'},
  guestPaths: {'/login', '/register'},
);

Atlas(
  passages: [
    Passage('/login', (_) => const LoginScreen()),
    Sanctum(
      path: '/',
      builder: (waypoint, child) => MainShell(child: child),
      children: [
        Passage('/', (_) => const QuestListScreen()),
        Passage('/hero', (_) => const HeroProfileScreen()),
        // ...
      ],
    ),
  ],
  sentinels: sentinels,
  refreshListenable: refreshListenable,
);
```

Sign in → auto-redirect to quest board. Sign out → auto-redirect to login. Role change → auto-redirect to appropriate page. All reactive. All automatic.

---

## Testing with Argus

Testing auth flows became declarative:

```dart
test('signIn sets isLoggedIn to true', () async {
  final auth = AuthPillar();
  expect(auth.isLoggedIn.value, isFalse);

  await auth.signIn({'name': 'Kael'});
  expect(auth.isLoggedIn.value, isTrue);
});

test('signOut resets auth state', () async {
  final auth = AuthPillar();
  await auth.signIn({'name': 'Kael'});

  auth.signOut();
  expect(auth.isLoggedIn.value, isFalse);
});

test('guard() wires sentinels and refresh', () {
  final auth = AuthPillar();
  final result = auth.guard(loginPath: '/login');
  expect(result.sentinels, hasLength(2));
  expect(result.refreshListenable, isA<CoreRefresh>());
});
```

The `guard()` return type used Dart's record syntax — `({List<Sentinel> sentinels, Listenable refreshListenable})` — making destructuring clean and type-safe.

---

## What Kael Learned

1. **Auth deserves its own package** — it's not routing, it's not state management, it's the bridge between them
2. **Argus provides the isLoggedIn contract** — consistent across every app, no manual declaration needed
3. **signIn/signOut are abstract lifecycle methods** — enforce a clean auth API on every implementation
4. **authCores enables multi-signal refresh** — override to track roles, permissions, feature flags alongside login state
5. **guard() eliminates auth routing boilerplate** — one call replaces 15+ lines of Garrison + CoreRefresh wiring
6. **titan_argus re-exports titan_atlas** — one import gives you routing + auth, no import juggling
7. **Testing is simpler** — the Argus contract makes auth Pillars predictable and testable

---

*The hundred-eyed guardian stood at every gate. It knew who was authenticated and who was not. It knew which roles opened which doors. And when the state of the world changed — a sign-in, a sign-out, a role revocation — every Sentinel in every passage stirred awake.*

*Kael looked at the refactored codebase. Three packages, each with a clear purpose. `titan` for reactivity. `titan_atlas` for routing. `titan_argus` for auth. Clean boundaries. Clear contracts.*

*"The Argus sees all," he said. "And what it sees, it guards."*

---

| | |
|---|---|
| **Previous** | [Chapter XXVII: The Sentinel Awakens](chapter-27-the-sentinel-awakens.md) |
| **Next** | *The next chapter awaits...* |
