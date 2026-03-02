/// Oracle of Atlas — Navigation observer for analytics, logging, and debugging.
///
/// Attach observers to Atlas to receive lifecycle events whenever
/// navigation occurs.
///
/// ```dart
/// class AnalyticsObserver extends AtlasObserver {
///   @override
///   void onNavigate(Waypoint from, Waypoint to) {
///     analytics.trackScreen(to.path);
///   }
/// }
///
/// final atlas = Atlas(
///   passages: [...],
///   observers: [AnalyticsObserver()],
/// );
/// ```
library;

import '../core/waypoint.dart';

/// Base class for Atlas navigation observers.
///
/// Extend this class and override the methods you care about.
///
/// ```dart
/// class LogObserver extends AtlasObserver {
///   @override
///   void onNavigate(Waypoint from, Waypoint to) {
///     print('${from.path} → ${to.path}');
///   }
/// }
/// ```
abstract class AtlasObserver {
  const AtlasObserver();

  /// Called when navigating to a new route (`Atlas.to`, `Atlas.toNamed`).
  void onNavigate(Waypoint from, Waypoint to) {}

  /// Called when replacing the current route (`Atlas.replace`).
  void onReplace(Waypoint from, Waypoint to) {}

  /// Called when going back (`Atlas.back`, `Atlas.backTo`).
  void onPop(Waypoint from, Waypoint to) {}

  /// Called when resetting the navigation stack (`Atlas.reset`).
  void onReset(Waypoint to) {}

  /// Called when a Sentinel redirects navigation.
  void onGuardRedirect(String originalPath, String redirectPath) {}

  /// Called when a Drift redirects navigation.
  void onDriftRedirect(String originalPath, String redirectPath) {}

  /// Called when a 404 occurs (no matching Passage).
  void onNotFound(String path) {}
}

/// A logging observer that prints navigation events to the console.
///
/// ```dart
/// Atlas(
///   passages: [...],
///   observers: [AtlasLoggingObserver()],
/// )
/// ```
class AtlasLoggingObserver extends AtlasObserver {
  /// Optional prefix for log messages.
  final String prefix;

  const AtlasLoggingObserver({this.prefix = 'Atlas'});

  @override
  void onNavigate(Waypoint from, Waypoint to) {
    // ignore: avoid_print
    print('$prefix: navigate ${from.path} → ${to.path}');
  }

  @override
  void onReplace(Waypoint from, Waypoint to) {
    // ignore: avoid_print
    print('$prefix: replace ${from.path} → ${to.path}');
  }

  @override
  void onPop(Waypoint from, Waypoint to) {
    // ignore: avoid_print
    print('$prefix: pop ${from.path} → ${to.path}');
  }

  @override
  void onReset(Waypoint to) {
    // ignore: avoid_print
    print('$prefix: reset → ${to.path}');
  }

  @override
  void onGuardRedirect(String originalPath, String redirectPath) {
    // ignore: avoid_print
    print('$prefix: sentinel $originalPath → $redirectPath');
  }

  @override
  void onDriftRedirect(String originalPath, String redirectPath) {
    // ignore: avoid_print
    print('$prefix: drift $originalPath → $redirectPath');
  }

  @override
  void onNotFound(String path) {
    // ignore: avoid_print
    print('$prefix: 404 $path');
  }
}

/// A ready-made analytics observer that delegates to callbacks.
///
/// Plugs into Firebase Analytics, Amplitude, Mixpanel, Segment,
/// or any analytics service with a simple callback API.
///
/// ## Usage
///
/// ```dart
/// Atlas(
///   passages: [...],
///   observers: [
///     AtlasAnalyticsObserver(
///       onScreen: (name, params) {
///         FirebaseAnalytics.instance.logEvent(
///           name: 'screen_view',
///           parameters: {'screen_name': name, ...params},
///         );
///       },
///     ),
///   ],
/// )
/// ```
///
/// ## Custom Screen Names
///
/// Use [screenNameResolver] to map paths to human-readable names:
///
/// ```dart
/// AtlasAnalyticsObserver(
///   screenNameResolver: (path, name, metadata) =>
///       metadata?['title'] as String? ?? name ?? path,
///   onScreen: (name, params) => analytics.trackScreen(name),
/// )
/// ```
class AtlasAnalyticsObserver extends AtlasObserver {
  /// Called on every screen view (navigation, replace, or reset).
  ///
  /// [screenName] is resolved via [screenNameResolver], or falls back
  /// to the route name, then to the path.
  final void Function(String screenName, Map<String, String> parameters)?
  onScreen;

  /// Called on every navigation event with structured event data.
  final void Function(String event, Map<String, dynamic> parameters)? onEvent;

  /// Resolves a path + route name + metadata into a human-readable
  /// screen name for analytics dashboards.
  ///
  /// Receives the matched path, optional route name, and optional metadata.
  /// If null, falls back to `name ?? path`.
  final String Function(
    String path,
    String? name,
    Map<String, dynamic>? metadata,
  )?
  screenNameResolver;

  /// Creates an analytics observer.
  const AtlasAnalyticsObserver({
    this.onScreen,
    this.onEvent,
    this.screenNameResolver,
  });

  String _resolveScreenName(Waypoint waypoint) {
    if (screenNameResolver != null) {
      return screenNameResolver!(
        waypoint.path,
        waypoint.name,
        waypoint.metadata,
      );
    }
    return waypoint.name ?? waypoint.path;
  }

  @override
  void onNavigate(Waypoint from, Waypoint to) {
    final screenName = _resolveScreenName(to);
    onScreen?.call(screenName, {'path': to.path, 'from': from.path});
    onEvent?.call('navigate', {
      'from': from.path,
      'to': to.path,
      'screen_name': screenName,
    });
  }

  @override
  void onReplace(Waypoint from, Waypoint to) {
    final screenName = _resolveScreenName(to);
    onScreen?.call(screenName, {'path': to.path, 'from': from.path});
    onEvent?.call('replace', {
      'from': from.path,
      'to': to.path,
      'screen_name': screenName,
    });
  }

  @override
  void onPop(Waypoint from, Waypoint to) {
    final screenName = _resolveScreenName(to);
    onScreen?.call(screenName, {'path': to.path, 'from': from.path});
    onEvent?.call('pop', {
      'from': from.path,
      'to': to.path,
      'screen_name': screenName,
    });
  }

  @override
  void onReset(Waypoint to) {
    final screenName = _resolveScreenName(to);
    onScreen?.call(screenName, {'path': to.path});
    onEvent?.call('reset', {'to': to.path, 'screen_name': screenName});
  }

  @override
  void onGuardRedirect(String originalPath, String redirectPath) {
    onEvent?.call('guard_redirect', {'from': originalPath, 'to': redirectPath});
  }

  @override
  void onDriftRedirect(String originalPath, String redirectPath) {
    onEvent?.call('drift_redirect', {'from': originalPath, 'to': redirectPath});
  }

  @override
  void onNotFound(String path) {
    onEvent?.call('not_found', {'path': path});
  }
}
