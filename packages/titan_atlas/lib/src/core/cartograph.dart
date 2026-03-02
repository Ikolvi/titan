/// Cartograph — Deep link parsing, URL building, and route mapping.
///
/// Cartograph provides declarative deep link handling, URL template
/// building, and route name resolution for Atlas. Eliminates boilerplate
/// around universal links, app links, and web URL handling.
///
/// ## Why "Cartograph"?
///
/// A cartograph is a map-maker. Titan's Cartograph maps between
/// external URLs and internal Atlas routes.
///
/// ## Usage
///
/// ```dart
/// // Register named routes for URL building
/// Cartograph.name('user-profile', '/users/:id');
/// Cartograph.name('settings', '/settings');
///
/// // Build URLs from names
/// final url = Cartograph.build('user-profile', runes: {'id': '42'});
/// // → '/users/42'
///
/// // Parse deep links
/// final result = Cartograph.parse(Uri.parse('/users/42'));
/// // result.path == '/users/:id', result.runes == {'id': '42'}
///
/// // Handle incoming deep links
/// Cartograph.handleDeepLink(uri);
/// ```
library;

/// Result of parsing a deep link URI against registered patterns.
class CartographMatch {
  /// The matched route path template.
  final String path;

  /// Extracted path parameters (runes).
  final Map<String, String> runes;

  /// Extracted query parameters.
  final Map<String, String> query;

  /// Extra data attached to this match.
  final Object? extra;

  /// Creates a match result.
  const CartographMatch({
    required this.path,
    this.runes = const {},
    this.query = const {},
    this.extra,
  });

  @override
  String toString() => 'CartographMatch($path, runes: $runes, query: $query)';
}

/// Deep link and URL mapping utilities for Atlas routing.
///
/// ```dart
/// Cartograph.name('profile', '/users/:id');
/// final url = Cartograph.build('profile', runes: {'id': '42'});
/// ```
class Cartograph {
  Cartograph._();

  /// Named route registry: name → path template.
  static final Map<String, String> _namedRoutes = {};

  /// Deep link pattern registry: path template → callback.
  static final Map<String, void Function(CartographMatch match)?> _links = {};

  // ---------------------------------------------------------------------------
  // Named Routes
  // ---------------------------------------------------------------------------

  /// Register a named route with a path template.
  ///
  /// ```dart
  /// Cartograph.name('user-profile', '/users/:id');
  /// Cartograph.name('settings', '/settings');
  /// ```
  static void name(String routeName, String pathTemplate) {
    _namedRoutes[routeName] = pathTemplate;
  }

  /// Register multiple named routes at once.
  ///
  /// ```dart
  /// Cartograph.nameAll({
  ///   'home': '/',
  ///   'profile': '/users/:id',
  ///   'settings': '/settings',
  /// });
  /// ```
  static void nameAll(Map<String, String> routes) {
    _namedRoutes.addAll(routes);
  }

  /// Get the path template for a named route.
  ///
  /// Returns null if the name is not registered.
  static String? pathFor(String routeName) => _namedRoutes[routeName];

  /// Whether a named route is registered.
  static bool hasName(String routeName) => _namedRoutes.containsKey(routeName);

  /// All registered route names.
  static Set<String> get routeNames =>
      Set.unmodifiable(_namedRoutes.keys.toSet());

  // ---------------------------------------------------------------------------
  // URL Building
  // ---------------------------------------------------------------------------

  /// Build a URL path from a named route and parameters.
  ///
  /// Substitutes `:param` segments with values from [runes].
  /// Appends [query] as query parameters.
  ///
  /// Throws [StateError] if the route name is not registered.
  /// Throws [ArgumentError] if required runes are missing.
  ///
  /// ```dart
  /// Cartograph.name('profile', '/users/:id/posts/:postId');
  /// final url = Cartograph.build('profile',
  ///   runes: {'id': '42', 'postId': '7'},
  ///   query: {'tab': 'comments'},
  /// );
  /// // → '/users/42/posts/7?tab=comments'
  /// ```
  static String build(
    String routeName, {
    Map<String, String> runes = const {},
    Map<String, String> query = const {},
  }) {
    final template = _namedRoutes[routeName];
    if (template == null) {
      throw StateError('Route "$routeName" is not registered in Cartograph.');
    }

    return buildFromTemplate(template, runes: runes, query: query);
  }

  /// Build a URL path from a path template and parameters.
  ///
  /// Substitutes `:param` segments with values from [runes].
  ///
  /// ```dart
  /// final url = Cartograph.buildFromTemplate(
  ///   '/users/:id',
  ///   runes: {'id': '42'},
  /// );
  /// // → '/users/42'
  /// ```
  static String buildFromTemplate(
    String template, {
    Map<String, String> runes = const {},
    Map<String, String> query = const {},
  }) {
    final segments = template.split('/');
    final built = <String>[];

    for (final segment in segments) {
      if (segment.startsWith(':')) {
        final paramName = segment.substring(1);
        final value = runes[paramName];
        if (value == null) {
          throw ArgumentError(
            'Missing rune "$paramName" for template "$template".',
          );
        }
        built.add(value);
      } else {
        built.add(segment);
      }
    }

    var path = built.join('/');
    if (path.isEmpty) path = '/';

    if (query.isNotEmpty) {
      final queryString = query.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');
      path = '$path?$queryString';
    }

    return path;
  }

  // ---------------------------------------------------------------------------
  // Deep Link Parsing
  // ---------------------------------------------------------------------------

  /// Register a deep link pattern with an optional handler.
  ///
  /// ```dart
  /// Cartograph.link('/users/:id', (match) {
  ///   Atlas.go('/users/${match.runes['id']}');
  /// });
  /// ```
  static void link(
    String pathTemplate, [
    void Function(CartographMatch match)? handler,
  ]) {
    _links[pathTemplate] = handler;
  }

  /// Parse a URI against registered named routes.
  ///
  /// Returns a [CartographMatch] if the URI matches a registered
  /// pattern, or `null` if no match is found.
  ///
  /// ```dart
  /// final match = Cartograph.parse(Uri.parse('/users/42?tab=posts'));
  /// // match.runes == {'id': '42'}
  /// // match.query == {'tab': 'posts'}
  /// ```
  static CartographMatch? parse(Uri uri) {
    final path = uri.path;
    final pathSegments = _splitPath(path);

    // Check named routes
    for (final entry in _namedRoutes.entries) {
      final match = _matchTemplate(entry.value, pathSegments);
      if (match != null) {
        return CartographMatch(
          path: entry.value,
          runes: match,
          query: uri.queryParameters,
        );
      }
    }

    // Check deep link patterns
    for (final entry in _links.entries) {
      final match = _matchTemplate(entry.key, pathSegments);
      if (match != null) {
        return CartographMatch(
          path: entry.key,
          runes: match,
          query: uri.queryParameters,
        );
      }
    }

    return null;
  }

  /// Handle an incoming deep link URI.
  ///
  /// Parses the URI, and if a matching handler is registered via [link],
  /// invokes it. Returns `true` if a handler was found and invoked.
  ///
  /// ```dart
  /// final handled = Cartograph.handleDeepLink(
  ///   Uri.parse('myapp://users/42'),
  /// );
  /// ```
  static bool handleDeepLink(Uri uri) {
    final path = uri.path;
    final pathSegments = _splitPath(path);

    for (final entry in _links.entries) {
      final match = _matchTemplate(entry.key, pathSegments);
      if (match != null && entry.value != null) {
        entry.value!(
          CartographMatch(
            path: entry.key,
            runes: match,
            query: uri.queryParameters,
          ),
        );
        return true;
      }
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Clear all registered routes and patterns.
  static void reset() {
    _namedRoutes.clear();
    _links.clear();
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Split a path into segments, filtering empty strings.
  static List<String> _splitPath(String path) {
    return path.split('/').where((s) => s.isNotEmpty).toList();
  }

  /// Try to match a path template against path segments.
  ///
  /// Returns extracted runes map on match, or null on mismatch.
  static Map<String, String>? _matchTemplate(
    String template,
    List<String> pathSegments,
  ) {
    final templateSegments = _splitPath(template);
    if (templateSegments.length != pathSegments.length) return null;

    final runes = <String, String>{};

    for (var i = 0; i < templateSegments.length; i++) {
      final tmpl = templateSegments[i];
      final actual = pathSegments[i];

      if (tmpl.startsWith(':')) {
        runes[tmpl.substring(1)] = actual;
      } else if (tmpl != actual) {
        return null;
      }
    }

    return runes;
  }
}
