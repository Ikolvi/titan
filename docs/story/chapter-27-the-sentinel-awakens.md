# Chapter XXVII: The Sentinel Awakens

*The Chronicles of Titan — A Developer's Odyssey*

---

> *"The Sentinels stood at every gate, their eyes sharp, their judgment swift. But they only looked when someone knocked. Between knocks, the gates stood unwatched — and in that silence, intruders could slip through."*

---

## The Gap in the Wall

Kael had built Questboard's authentication layer with confidence. Sentinels guarded every protected route. An `AuthPillar` tracked the user's login state. The Garrison provided pre-built guards. Everything worked — until it didn't.

The bug report was simple: *"After signing in on /login, nothing happens. I have to manually navigate to / to see the quest board."*

Kael traced the problem. The `AuthPillar`'s `isLoggedIn` Core was updating correctly. The Sentinel was configured correctly. But no one was *telling* Atlas to re-check.

```dart
// The Sentinel only runs during navigation
Sentinel.except(
  paths: {'/login', '/register'},
  guard: (path, _) {
    final auth = Titan.get<AuthPillar>();
    return auth.isLoggedIn.value ? null : '/login';
  },
)
```

The problem was fundamental: **Sentinels only evaluate during navigation** — when `Atlas.to()`, `.replace()`, or `.reset()` is called. They don't automatically re-evaluate when the underlying state changes. After sign-in, `isLoggedIn` flipped to `true`, but nothing triggered a route change.

Kael had been manually calling `Atlas.reset('/')` after every sign-in. But that coupled the auth logic to the navigation logic. What about token expiry? Background session invalidation? Role changes?

*"The Sentinels need to wake up on their own,"* Kael realized. *"They need to watch the state they guard."*

---

## The Bridge Between Worlds

The challenge was architectural. Titan's reactive engine used `ReactiveNode` — with `addListener` and `removeListener`. Atlas expected a Flutter `Listenable`. Same pattern, different type hierarchies. A `Core<bool>` couldn't be passed directly as a `Listenable`.

Kael needed a bridge.

**CoreRefresh** was the answer: a `ChangeNotifier` that subscribes to one or more Titan `Core` values and fires when any of them change.

```dart
import 'package:titan_atlas/titan_atlas.dart';

class AuthPillar extends Pillar {
  late final isLoggedIn = core(false);
  late final role = core<String?>(null);
}
```

```dart
final auth = Titan.get<AuthPillar>();

final atlas = Atlas(
  passages: [
    Passage('/', (_) => const QuestBoardScreen()),
    Passage('/login', (_) => const LoginScreen()),
    Passage('/admin', (_) => const AdminScreen()),
    Passage('/heroes', (_) => const HeroesScreen()),
  ],
  sentinels: [
    // Guard: unauthenticated → /login
    Garrison.authGuard(
      isAuthenticated: () => auth.isLoggedIn.value,
      loginPath: '/login',
      publicPaths: {'/login', '/register'},
    ),
    // Guard: authenticated → away from /login
    Garrison.guestOnly(
      isAuthenticated: () => auth.isLoggedIn.value,
      redirectPath: '/',
      guestPaths: {'/login', '/register'},
    ),
  ],
  // The key line — reactive re-evaluation
  refreshListenable: CoreRefresh([auth.isLoggedIn]),
);
```

One parameter. One bridge. The Sentinels were awake.

---

## How the Refresh Works

When `auth.isLoggedIn.value` changes, `CoreRefresh` notifies Atlas. Atlas then:

1. Gets the current path from the delegate
2. Re-resolves it through the full pipeline: **Drift → Sentinels → per-route redirect**
3. If the resolved path differs from the current path → `Atlas.reset()` to the new destination
4. If the path is unchanged → no-op (no unnecessary navigation)

```
┌──────────────┐     notify     ┌─────────┐     re-resolve     ┌────────────┐
│  Core change │ ──────────────▶│  Atlas   │ ─────────────────▶│   Drift    │
│  (sign-in)   │                │ _onRefresh│                   │  Sentinels │
└──────────────┘                └─────────┘                    │  Redirect  │
                                     │                         └────────────┘
                                     │  if path differs              │
                                     ▼                               │
                                ┌─────────┐     resolved path   ◀────┘
                                │  reset() │
                                │  to new  │
                                │  path    │
                                └─────────┘
```

The sign-out scenario played out perfectly:

```dart
// User is on /heroes, token expires
auth.isLoggedIn.value = false;

// CoreRefresh notifies → Atlas re-resolves /heroes
// Sentinel: isLoggedIn is false, /heroes is not public → redirect to /login
// Atlas.reset('/login') — stack cleared, user sees login screen
```

And the sign-in scenario:

```dart
// User is on /login, submits credentials
auth.isLoggedIn.value = true;

// CoreRefresh notifies → Atlas re-resolves /login
// Garrison.guestOnly: isLoggedIn is true, /login is a guest path → redirect to /
// Atlas.reset('/') — user arrives at the quest board
```

---

## Multiple Signals

The admin panel required role-based access. Kael added the role Core to the refresh bridge:

```dart
refreshListenable: CoreRefresh([auth.isLoggedIn, auth.role]),
```

Now route re-evaluation triggered when *either* signal changed. A user promoted to admin while viewing `/heroes` could be redirected to `/admin`. A demoted admin on `/admin` would be sent back to `/`.

```dart
sentinels: [
  Garrison.authGuard(
    isAuthenticated: () => auth.isLoggedIn.value,
    loginPath: '/login',
    publicPaths: {'/login'},
  ),
  Sentinel.only(
    paths: {'/admin'},
    guard: (path, _) {
      final auth = Titan.get<AuthPillar>();
      return auth.role.value == 'admin' ? null : '/';
    },
  ),
],
refreshListenable: CoreRefresh([auth.isLoggedIn, auth.role]),
```

---

## Any Listenable Works

Kael discovered that `refreshListenable` wasn't limited to `CoreRefresh`. It accepted any Flutter `Listenable`:

```dart
// A simple ValueNotifier works too
final authNotifier = ValueNotifier<bool>(false);

Atlas(
  passages: [...],
  sentinels: [...],
  refreshListenable: authNotifier,
);
```

This made Atlas interoperable with any state management solution — not just Titan. A team migrating from Provider could use their existing `ChangeNotifier` directly.

---

## Safety Mechanisms

### Re-Entrant Guard

Rapid state changes — like a burst of Core updates during initialization — could trigger multiple refresh calls. Atlas guards against this:

```dart
void _onRefresh() {
  if (_isRefreshing) return; // Skip if already processing
  _isRefreshing = true;
  // ... resolve and apply ...
  _isRefreshing = false;
}
```

### Async Sentinel Support

When the router detects async Sentinels (e.g., checking permissions from a server), the refresh handler automatically uses the async resolution path:

```dart
sentinels: [
  Sentinel.async((path, waypoint) async {
    final allowed = await checkPermission(path);
    return allowed ? null : '/forbidden';
  }),
],
refreshListenable: CoreRefresh([auth.isLoggedIn]),
```

### Cleanup on Replacement

When a new `Atlas` instance replaces the current one, the old instance's refresh listener is automatically cleaned up — no leaks, no orphaned subscriptions:

```dart
// In Atlas constructor:
if (_instance != null) {
  _instance!._removeRefreshListener();
}
```

### Pillar Disposal on No-Op

When the refresh re-resolves the current path and finds no redirect needed, any route-scoped Pillars that were unnecessarily created during resolution are immediately disposed:

```dart
void _applyRefreshResult(String originalPath, _NavigationResult result) {
  if (resolvedPath != originalPath) {
    _delegate._reset(resolvedPath);
  } else {
    // Clean up Pillars created during unnecessary re-resolve
    result.disposePillars();
  }
}
```

---

## The Drift Connection

CoreRefresh also re-evaluates **Drift** — the global redirect function. Kael used this for maintenance mode:

```dart
class AppPillar extends Pillar {
  late final isMaintenanceMode = core(false);
}

final app = Titan.get<AppPillar>();

Atlas(
  passages: [...],
  drift: (path, waypoint) {
    if (app.isMaintenanceMode.value && path != '/maintenance') {
      return '/maintenance';
    }
    return null;
  },
  refreshListenable: CoreRefresh([
    auth.isLoggedIn,
    app.isMaintenanceMode,
  ]),
);
```

When the server pushed a maintenance flag, every user — regardless of their current page — was redirected to `/maintenance`. When maintenance ended, they were redirected back.

---

## Testing the Awakened Sentinel

```dart
testWidgets('redirects to /login when auth expires', (tester) async {
  final auth = AuthPillar();
  Titan.put(auth);
  auth.isLoggedIn.value = true;

  final refresh = CoreRefresh([auth.isLoggedIn]);

  Atlas(
    passages: [
      Passage('/', (_) => const Text('Home')),
      Passage('/login', (_) => const Text('Login')),
    ],
    sentinels: [
      Sentinel.except(
        paths: {'/login'},
        guard: (path, _) =>
            auth.isLoggedIn.value ? null : '/login',
      ),
    ],
    refreshListenable: refresh,
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: Atlas.config),
  );

  expect(find.text('Home'), findsOneWidget);

  // Auth expires
  auth.isLoggedIn.value = false;
  await tester.pumpAndSettle();

  // Sentinel auto-redirected
  expect(find.text('Login'), findsOneWidget);
});
```

The test captured the entire flow: authenticated user → state change → automatic re-evaluation → redirect. No manual `Atlas.reset()` calls. No coupled auth logic. Just reactive routing.

---

## What Kael Learned

1. **Sentinels are passive by default** — they only evaluate during navigation, not when the state they depend on changes
2. **CoreRefresh bridges the gap** — converts Titan's `ReactiveNode` signals to Flutter's `Listenable` interface
3. **One parameter enables reactive routing** — `refreshListenable: CoreRefresh([...])` makes Sentinels re-evaluate automatically
4. **Multiple signals combine naturally** — pass any number of Cores to monitor auth, roles, feature flags, or maintenance mode
5. **Any Listenable works** — `ValueNotifier`, `ChangeNotifier`, or custom implementations all plug in
6. **Re-entrant guards prevent cascades** — rapid state changes don't cause stack overflow or duplicate navigation
7. **Drift re-evaluates too** — global redirects benefit from the same reactive trigger
8. **Cleanup is automatic** — Atlas replaces clean up old listeners; no-op refreshes dispose unnecessary Pillars
9. **Async Sentinels are handled** — the refresh path automatically uses async resolution when needed
10. **The Sentinel awakens when it matters** — not on a timer, not on a poll, but precisely when the state it guards changes

---

*The Sentinels no longer stood with closed eyes between knocks. They watched the very signals they were sworn to guard. When those signals changed, they acted — instantly, decisively, without waiting for someone to approach the gate.*

*Kael leaned back and watched the auth flow work for the first time without a single manual navigation call. Sign in → quest board. Token expires → login screen. Role changes → appropriate redirect. All automatic. All reactive.*

*"The walls are truly alive now," he murmured.*

*But as the Sentinels stirred and the routes shifted of their own accord, Kael noticed something in the Colossus dashboard. The performance metrics were telling a story of their own — navigation patterns, guard evaluations, redirect chains. The data was there. It just needed someone to listen...*

---

| | |
|---|---|
| **Previous** | [Chapter XXVI: The Colossus Turns Inward](chapter-26-the-colossus-turns-inward.md) |
| **Next** | [Chapter XXVIII: The Argus Guards](chapter-28-the-argus-guards.md) |
