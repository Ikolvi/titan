/// Passage — A route definition in the Atlas.
///
/// Each Passage maps a URL pattern to a widget builder.
/// Passages can be nested, guarded, and animated.
///
/// ```dart
/// // Simple passage
/// Passage('/home', (_) => const HomeScreen())
///
/// // With Runes (parameters)
/// Passage('/profile/:id', (wp) => ProfileScreen(id: wp.runes['id']!))
///
/// // With transition
/// Passage('/modal', (_) => Modal(), shift: Shift.slideUp())
///
/// // With nested passages
/// Passage('/settings', (_) => SettingsScreen(), passages: [
///   Passage('/settings/account', (_) => AccountScreen()),
///   Passage('/settings/privacy', (_) => PrivacyScreen()),
/// ])
/// ```
library;

import 'package:flutter/widgets.dart';
import 'package:titan/titan.dart';
import 'shift.dart';
import 'waypoint.dart';

/// Builder function for creating a widget from navigation state.
typedef PassageBuilder = Widget Function(Waypoint waypoint);

/// Base class for all route entries in the Atlas.
sealed class AtlasRoute {
  const AtlasRoute();
}

/// **Passage** — A route that maps a URL pattern to a widget.
///
/// The fundamental building block of Atlas navigation.
///
/// ```dart
/// Passage('/home', (waypoint) => const HomeScreen())
/// Passage('/user/:id', (wp) => UserScreen(id: wp.runes['id']!))
/// ```
class Passage extends AtlasRoute {
  /// The URL pattern for this passage.
  ///
  /// Supports:
  /// - Static: `/home`, `/settings/profile`
  /// - Dynamic (Runes): `/profile/:id`, `/post/:slug`
  /// - Wildcard: `/files/*`
  final String path;

  /// Builder that creates the widget for this passage.
  final PassageBuilder builder;

  /// Page transition animation.
  final Shift? shift;

  /// Nested child passages.
  final List<AtlasRoute> passages;

  /// Optional name for this passage (for named navigation).
  final String? name;

  /// Custom metadata attached to this route.
  final Map<String, dynamic>? metadata;

  /// Per-route redirect function.
  ///
  /// Called when this Passage is matched. Return a path to redirect,
  /// or null to allow normal passage.
  ///
  /// ```dart
  /// Passage('/old-page', (_) => Container(),
  ///   redirect: (wp) => '/new-page',
  /// )
  /// ```
  final String? Function(Waypoint waypoint)? redirect;

  /// Route-scoped Pillar factories.
  ///
  /// These Pillars are auto-created when this route is pushed onto
  /// the navigation stack and auto-disposed when the route leaves.
  /// Accessible via `Titan.get<T>()` or `context.pillar<T>()`.
  ///
  /// ```dart
  /// Passage('/checkout', (wp) => CheckoutScreen(),
  ///   pillars: [CheckoutPillar.new, PaymentPillar.new],
  /// )
  /// ```
  final List<Pillar Function()> pillars;

  /// Create a Passage.
  ///
  /// ```dart
  /// Passage('/home', (_) => const HomeScreen())
  /// Passage('/user/:id', (wp) => UserScreen(id: wp.runes['id']!),
  ///   shift: Shift.fade(),
  ///   passages: [
  ///     Passage('/user/:id/posts', (wp) => UserPostsScreen()),
  ///   ],
  /// )
  /// ```
  const Passage(
    this.path,
    this.builder, {
    this.shift,
    this.passages = const [],
    this.name,
    this.metadata,
    this.redirect,
    this.pillars = const [],
  });
}

/// **Sanctum** — A shell route providing persistent layout around nested passages.
///
/// Like a persistent scaffold, tab bar, or navigation rail that stays
/// visible while nested passages change.
///
/// ```dart
/// Sanctum(
///   shell: (child) => AppShell(child: child),
///   passages: [
///     Passage('/home', (_) => HomeScreen()),
///     Passage('/search', (_) => SearchScreen()),
///     Passage('/profile', (_) => ProfileScreen()),
///   ],
/// )
/// ```
class Sanctum extends AtlasRoute {
  /// Builder for the shell widget. Receives the current child page.
  final Widget Function(Widget child) shell;

  /// Passages contained within this shell.
  final List<AtlasRoute> passages;

  /// Optional shift for the shell itself.
  final Shift? shift;

  /// Shell-scoped Pillar factories.
  ///
  /// These Pillars are auto-created when any passage within this
  /// Sanctum is first entered and auto-disposed when all passages
  /// in this Sanctum leave the stack.
  ///
  /// ```dart
  /// Sanctum(
  ///   pillars: [DashboardPillar.new],
  ///   shell: (child) => DashboardLayout(child: child),
  ///   passages: [...],
  /// )
  /// ```
  final List<Pillar Function()> pillars;

  /// Create a Sanctum.
  ///
  /// ```dart
  /// Sanctum(
  ///   shell: (child) => Scaffold(
  ///     body: child,
  ///     bottomNavigationBar: const NavBar(),
  ///   ),
  ///   passages: [
  ///     Passage('/tab1', (_) => Tab1()),
  ///     Passage('/tab2', (_) => Tab2()),
  ///   ],
  /// )
  /// ```
  const Sanctum({
    required this.shell,
    required this.passages,
    this.shift,
    this.pillars = const [],
  });
}
