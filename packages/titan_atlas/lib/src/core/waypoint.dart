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

  /// Route metadata attached to the matching Passage.
  ///
  /// ```dart
  /// Passage('/admin', (_) => Admin(), metadata: {'title': 'Admin Panel', 'icon': Icons.admin})
  /// // In builder or observer:
  /// waypoint.metadata?['title'] // 'Admin Panel'
  /// ```
  final Map<String, dynamic>? metadata;

  /// The named route identifier (if the matching Passage has one).
  final String? name;

  /// The full URI including query string.
  Uri get uri =>
      Uri.parse(path).replace(queryParameters: query.isEmpty ? null : query);

  const Waypoint({
    required this.path,
    required this.pattern,
    this.runes = const {},
    this.query = const {},
    this.extra,
    this.remaining,
    this.metadata,
    this.name,
  });

  // -------------------------------------------------------------------------
  // Type-safe Rune accessors
  // -------------------------------------------------------------------------

  /// Get a Rune as an `int`, or `null` if not present or not parseable.
  ///
  /// ```dart
  /// final id = waypoint.intRune('id'); // 42
  /// ```
  int? intRune(String key) {
    final v = runes[key];
    return v == null ? null : int.tryParse(v);
  }

  /// Get a Rune as a `double`, or `null` if not present or not parseable.
  double? doubleRune(String key) {
    final v = runes[key];
    return v == null ? null : double.tryParse(v);
  }

  /// Get a Rune as a `bool` (`'true'`/`'1'` → true, else false).
  bool? boolRune(String key) {
    final v = runes[key];
    if (v == null) return null;
    return v == 'true' || v == '1';
  }

  /// Get a query parameter as an `int`, or `null`.
  int? intQuery(String key) {
    final v = query[key];
    return v == null ? null : int.tryParse(v);
  }

  /// Get a query parameter as a `double`, or `null`.
  double? doubleQuery(String key) {
    final v = query[key];
    return v == null ? null : double.tryParse(v);
  }

  /// Get a query parameter as a `bool`, or `null`.
  bool? boolQuery(String key) {
    final v = query[key];
    if (v == null) return null;
    return v == 'true' || v == '1';
  }

  /// Get a query parameter with a default value.
  ///
  /// ```dart
  /// // '/search?q=dart' → waypoint.queryOr('q', '') == 'dart'
  /// // '/search'        → waypoint.queryOr('q', '') == ''
  /// ```
  String queryOr(String key, String defaultValue) => query[key] ?? defaultValue;

  /// Get a query parameter as `int` with a default value.
  ///
  /// ```dart
  /// waypoint.intQueryOr('page', 1) // 1 if missing or unparseable
  /// ```
  int intQueryOr(String key, int defaultValue) => intQuery(key) ?? defaultValue;

  /// Get a query parameter as `double` with a default value.
  double doubleQueryOr(String key, double defaultValue) =>
      doubleQuery(key) ?? defaultValue;

  /// Get a query parameter as `bool` with a default value.
  bool boolQueryOr(String key, bool defaultValue) =>
      boolQuery(key) ?? defaultValue;

  /// Parse a comma-separated (or custom separator) query parameter
  /// into a list of strings.
  ///
  /// ```dart
  /// // '/search?tags=dart,flutter,mobile'
  /// waypoint.listQuery('tags'); // ['dart', 'flutter', 'mobile']
  /// ```
  List<String> listQuery(String key, {String separator = ','}) {
    final v = query[key];
    if (v == null || v.isEmpty) return const [];
    return v.split(separator);
  }

  /// Whether a query parameter exists (regardless of value).
  bool hasQuery(String key) => query.containsKey(key);

  /// Whether a Rune (path parameter) exists.
  bool hasRune(String key) => runes.containsKey(key);

  /// Get a Rune with a default value.
  ///
  /// ```dart
  /// waypoint.runeOr('tab', 'overview')
  /// ```
  String runeOr(String key, String defaultValue) => runes[key] ?? defaultValue;

  /// Create a copy with updated fields.
  Waypoint copyWith({
    String? path,
    String? pattern,
    Map<String, String>? runes,
    Map<String, String>? query,
    Object? extra,
    String? remaining,
    Map<String, dynamic>? metadata,
    String? name,
  }) {
    return Waypoint(
      path: path ?? this.path,
      pattern: pattern ?? this.pattern,
      runes: runes ?? this.runes,
      query: query ?? this.query,
      extra: extra ?? this.extra,
      remaining: remaining ?? this.remaining,
      metadata: metadata ?? this.metadata,
      name: name ?? this.name,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Waypoint && path == other.path && pattern == other.pattern;

  @override
  int get hashCode => Object.hash(path, pattern);

  @override
  String toString() => 'Waypoint($path)';
}
