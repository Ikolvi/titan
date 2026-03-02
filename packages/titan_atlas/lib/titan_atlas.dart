/// Atlas — Titan's routing & navigation system.
///
/// Declarative, URL-based, zero-boilerplate page management.
///
/// ## The Atlas Lexicon
///
/// | Concept | Titan Name | Purpose |
/// |---------|------------|---------|
/// | Router | **Atlas** | Maps all paths, bears the world |
/// | Route | **Passage** | A way through to a destination |
/// | Shell Route | **Sanctum** | Inner chamber — nested layout |
/// | Route Guard | **Sentinel** | Protects passage |
/// | Redirect | **Drift** | Navigation shifts course |
/// | Parameters | **Runes** | Ancient symbols carrying meaning |
/// | Transition | **Shift** | Change of form/phase |
/// | Route State | **Waypoint** | Current position in the journey |
///
/// ## Quick Start
///
/// ```dart
/// import 'package:titan_atlas/titan_atlas.dart';
///
/// final atlas = Atlas(
///   passages: [
///     Passage('/', (_) => HomeScreen()),
///     Passage('/profile/:id', (wp) => ProfileScreen(id: wp.runes['id']!)),
///     Sanctum(
///       shell: (child) => AppShell(child: child),
///       passages: [
///         Passage('/feed', (_) => FeedScreen()),
///         Passage('/explore', (_) => ExploreScreen()),
///       ],
///     ),
///   ],
///   sentinels: [
///     Sentinel((path, _) => isLoggedIn ? null : '/login'),
///   ],
/// );
///
/// void main() => runApp(
///   MaterialApp.router(routerConfig: atlas.config),
/// );
///
/// // Navigate
/// Atlas.to('/profile/42');
/// Atlas.back();
/// ```
library;

// Core types
export 'src/core/atlas_observer.dart';
export 'src/core/passage.dart';
export 'src/core/sentinel.dart';
export 'src/core/shift.dart';
export 'src/core/waypoint.dart';
export 'src/core/route_trie.dart';
export 'src/core/cartograph.dart';

// Navigation
export 'src/navigation/atlas.dart';
export 'src/navigation/herald_atlas_observer.dart';

// Widgets & extensions
export 'src/widgets/atlas_context.dart';

// Re-export titan for convenience
export 'package:titan/titan.dart';
