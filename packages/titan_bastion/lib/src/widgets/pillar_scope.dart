import 'package:flutter/widgets.dart';
import 'package:titan/titan.dart';

import 'beacon.dart';

/// **PillarScope** — Override multiple Pillar instances for a subtree.
///
/// Unlike [Beacon] (which creates and owns Pillars), `PillarScope`
/// takes pre-existing Pillar instances and makes them resolvable via
/// [Vestige], [Confluence], and `context.pillar<T>()` within its
/// subtree — shadowing any ancestor Beacon or Titan registrations.
///
/// ## Primary Use Cases
///
/// ### Testing
///
/// ```dart
/// testWidgets('uses mock auth', (tester) async {
///   final mockAuth = MockAuthPillar()..initialize();
///
///   await tester.pumpWidget(
///     PillarScope(
///       overrides: [mockAuth],
///       child: MaterialApp(
///         home: Vestige<MockAuthPillar>(
///           builder: (_, auth) => Text(auth.user.value?.name ?? 'none'),
///         ),
///       ),
///     ),
///   );
/// });
/// ```
///
/// ### Feature Flags / A-B Testing
///
/// ```dart
/// PillarScope(
///   overrides: [FeatureFlagPillar(enableNewUI: true)..initialize()],
///   child: FeatureScreen(),
/// )
/// ```
///
/// ### Scoped Dependency Injection
///
/// ```dart
/// PillarScope(
///   overrides: [TenantPillar(tenantId: 'acme')..initialize()],
///   child: TenantDashboard(),
/// )
/// ```
///
/// ## Important
///
/// - `PillarScope` does NOT create or dispose its Pillars.
/// - Pillars should be initialized before passing them in.
/// - For owned/managed Pillars, use [Beacon] instead.
/// - Internally uses [Beacon.value], so Vestige resolution works automatically.
class PillarScope extends StatelessWidget {
  /// The Pillar instances to provide in this scope.
  ///
  /// Each Pillar shadows any ancestor provider of the same runtime type.
  /// The Pillar must already be initialized.
  ///
  /// ```dart
  /// PillarScope(
  ///   overrides: [mockAuth, mockTheme],
  ///   child: child,
  /// )
  /// ```
  final List<Pillar> overrides;

  /// The widget subtree that can access the overridden Pillars.
  final Widget child;

  /// Creates a PillarScope that overrides Pillar resolution for a subtree.
  const PillarScope({super.key, required this.overrides, required this.child});

  @override
  Widget build(BuildContext context) {
    return Beacon.value(values: overrides, child: child);
  }
}
