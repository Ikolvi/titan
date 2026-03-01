/// Waypoint — The current navigation state.
///
/// Contains the resolved path, extracted Runes (parameters),
/// query parameters, and any extra data passed during navigation.
///
/// ```dart
/// Passage('/profile/:id', (waypoint) {
///   final id = waypoint.runes['id']!;
///   final tab = waypoint.query['tab'];
///   return ProfileScreen(id: id, tab: tab);
/// })
/// ```
library;

/// The current navigation state at a given point in the journey.
class Waypoint {
  /// The full matched path (e.g., `/profile/42`).
  final String path;

  /// The route pattern that matched (e.g., `/profile/:id`).
  final String pattern;

  /// Extracted path parameters (Runes).
  ///
  /// ```dart
  /// // For pattern '/profile/:id' matching '/profile/42':
  /// waypoint.runes['id'] // '42'
  /// ```
  final Map<String, String> runes;

  /// Query parameters from the URL.
  ///
  /// ```dart
  /// // For '/search?q=dart&page=2':
  /// waypoint.query['q']    // 'dart'
  /// waypoint.query['page'] // '2'
  /// ```
  final Map<String, String> query;

  /// Extra data passed during navigation.
  ///
  /// ```dart
  /// Atlas.to('/details', extra: myObject);
  /// // In builder:
  /// final data = waypoint.extra as MyObject;
  /// ```
  final Object? extra;

  /// The remaining path after a wildcard match.
  final String? remaining;

  /// The full URI including query string.
  Uri get uri => Uri.parse(path).replace(queryParameters: query.isEmpty ? null : query);

  const Waypoint({
    required this.path,
    required this.pattern,
    this.runes = const {},
    this.query = const {},
    this.extra,
    this.remaining,
  });

  /// Create a copy with updated fields.
  Waypoint copyWith({
    String? path,
    String? pattern,
    Map<String, String>? runes,
    Map<String, String>? query,
    Object? extra,
    String? remaining,
  }) {
    return Waypoint(
      path: path ?? this.path,
      pattern: pattern ?? this.pattern,
      runes: runes ?? this.runes,
      query: query ?? this.query,
      extra: extra ?? this.extra,
      remaining: remaining ?? this.remaining,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Waypoint &&
          path == other.path &&
          pattern == other.pattern;

  @override
  int get hashCode => Object.hash(path, pattern);

  @override
  String toString() => 'Waypoint($path)';
}
