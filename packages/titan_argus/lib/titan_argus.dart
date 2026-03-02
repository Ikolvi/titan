/// Argus — Titan's authentication & authorization framework.
///
/// Provides reactive auth state management, pre-built route guards,
/// and seamless integration with Atlas routing.
///
/// ## The Argus Lexicon
///
/// | Concept | Titan Name | Purpose |
/// |---------|------------|---------|
/// | Auth Manager | **Argus** | Watches over identity & access |
/// | Auth Guard Factory | **Garrison** | Pre-built Sentinel patterns |
/// | Reactive Bridge | **CoreRefresh** | Signals → Listenable bridge |
///
/// ## Quick Start
///
/// ```dart
/// import 'package:titan_argus/titan_argus.dart';
///
/// class AuthPillar extends Argus {
///   late final username = core<String?>(null);
///
///   @override
///   void signIn([Map<String, dynamic>? credentials]) {
///     strike(() {
///       username.value = credentials?['name'] as String?;
///       isLoggedIn.value = true;
///     });
///   }
///
///   @override
///   void signOut() {
///     strike(() {
///       isLoggedIn.value = false;
///       username.value = null;
///     });
///   }
/// }
///
/// // One-call reactive auth routing
/// final auth = Titan.get<AuthPillar>();
/// final garrisonAuth = auth.guard(
///   loginPath: '/login',
///   homePath: '/',
///   guestPaths: {'/login', '/register'},
/// );
///
/// Atlas(
///   passages: [...],
///   sentinels: garrisonAuth.sentinels,
///   refreshListenable: garrisonAuth.refresh,
/// );
/// ```
library;

// Auth base class
export 'src/argus.dart';

// Guard factories
export 'src/garrison.dart';

// Reactive bridge
export 'src/core_refresh.dart';

// Re-export titan_atlas for convenience (Atlas, Sentinel, Passage, etc.)
export 'package:titan_atlas/titan_atlas.dart';
