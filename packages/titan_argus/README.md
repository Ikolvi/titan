# titan_argus

**Authentication & authorization for Titan** — the watchful guardian.

[![pub package](https://img.shields.io/pub/v/titan_argus.svg)](https://pub.dev/packages/titan_argus)

Part of the [Titan](https://github.com/Ikolvi/titan) framework.

## Features

- **Argus** — abstract auth Pillar base class with `isLoggedIn` Core, `signIn`/`signOut` lifecycle
- **Garrison** — pre-built Sentinel factories: `authGuard`, `guestOnly`, `roleGuard`, `rolesGuard`, `onboardingGuard`, `composite`
- **CoreRefresh** — bridges Titan `ReactiveNode` signals to Flutter `Listenable` for Atlas `refreshListenable`
- **guard()** — one-call convenience that wires Garrison sentinels + CoreRefresh together

## Installation

```yaml
dependencies:
  titan_argus: ^1.0.0
```

## Quick Start

### 1. Create an Auth Pillar

```dart
import 'package:titan_argus/titan_argus.dart';

class AuthPillar extends Argus {
  late final username = core<String?>(null);

  @override
  Future<void> signIn([Map<String, dynamic>? credentials]) async {
    await strikeAsync('sign-in', () async {
      username.value = credentials?['name'] as String? ?? 'Hero';
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
```

### 2. Wire with Atlas

```dart
final auth = Titan.get<AuthPillar>();
final (:sentinels, :refreshListenable) = auth.guard(
  loginPath: '/login',
  publicPaths: {'/login', '/register'},
  guestPaths: {'/login'},
);

Atlas(
  passages: [
    Passage('/login', (_) => const LoginScreen()),
    Passage('/', (_) => const HomeScreen()),
  ],
  sentinels: sentinels,
  refreshListenable: refreshListenable,
);
```

### 3. Role-Based Access

```dart
class AdminAuth extends Argus {
  late final role = core<String?>(null);

  @override
  List<ReactiveNode> get authCores => [isLoggedIn, role];

  @override
  Future<void> signIn([Map<String, dynamic>? credentials]) async {
    // ...
  }
}
```

## Garrison Factories

| Factory | Purpose |
|---------|---------|
| `authGuard` | Redirect unauthenticated users to login |
| `guestOnly` | Redirect authenticated users away from login |
| `roleGuard` | Require a specific role for access |
| `rolesGuard` | Require any of a set of roles |
| `onboardingGuard` | Redirect incomplete onboarding |
| `composite` | Combine multiple sync guards |
| `compositeAsync` | Combine multiple async guards |
| `refreshAuth` | Full auth stack: sentinels + CoreRefresh |

## Dependencies

- `titan` — reactive engine
- `titan_atlas` — routing (re-exported for convenience)

## License

MIT — see [LICENSE](LICENSE)
