/// Context extensions for Atlas navigation.
///
/// ```dart
/// // Navigate
/// context.atlas.to('/profile/42');
/// context.atlas.back();
///
/// // Get current waypoint
/// final wp = context.atlas.waypoint;
/// ```
library;

import 'package:flutter/widgets.dart';

import '../core/waypoint.dart';
import '../navigation/atlas.dart';

/// Extension on [BuildContext] for Atlas navigation.
extension AtlasContext on BuildContext {
  /// Access Atlas navigation methods from any BuildContext.
  ///
  /// ```dart
  /// context.atlas.to('/profile/42');
  /// context.atlas.back();
  /// context.atlas.replace('/home');
  /// ```
  AtlasContextProxy get atlas => const AtlasContextProxy();
}

/// Proxy object providing Atlas navigation via BuildContext.
class AtlasContextProxy {
  const AtlasContextProxy();

  /// Navigate to a path.
  ///
  /// ```dart
  /// context.atlas.to('/profile/42');
  /// context.atlas.to('/search?q=dart', extra: searchData);
  /// ```
  void to(String path, {Object? extra}) => Atlas.to(path, extra: extra);

  /// Navigate to a named route.
  ///
  /// ```dart
  /// context.atlas.toNamed('profile', runes: {'id': '42'});
  /// ```
  void toNamed(
    String name, {
    Map<String, String> runes = const {},
    Map<String, String> query = const {},
    Object? extra,
  }) =>
      Atlas.toNamed(name, runes: runes, query: query, extra: extra);

  /// Replace the current route.
  void replace(String path, {Object? extra}) =>
      Atlas.replace(path, extra: extra);

  /// Go back.
  void back() => Atlas.back();

  /// Go back to a specific path.
  void backTo(String path) => Atlas.backTo(path);

  /// Reset navigation to a single route.
  void reset(String path, {Object? extra}) =>
      Atlas.reset(path, extra: extra);

  /// Get the current waypoint.
  Waypoint get waypoint => Atlas.current;

  /// Whether we can go back.
  bool get canBack => Atlas.canBack;
}
