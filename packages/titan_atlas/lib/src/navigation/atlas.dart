/// Atlas — Titan's routing & navigation system.
///
/// The central router that maps URL paths to widgets using Passages,
/// protects routes with Sentinels, and integrates with Flutter's
/// Navigator 2.0 for deep linking and web support.
///
/// ```dart
/// final atlas = Atlas(
///   passages: [
///     Passage('/', (_) => const HomeScreen()),
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
/// // Use in app
/// MaterialApp.router(routerConfig: atlas.config)
///
/// // Navigate
/// Atlas.to('/profile/42');
/// Atlas.back();
/// ```
library;

import 'package:flutter/material.dart';

import '../core/passage.dart';
import '../core/route_trie.dart';
import '../core/sentinel.dart';
import '../core/shift.dart';
import '../core/waypoint.dart';

// ---------------------------------------------------------------------------
// Route entry — flattened internal representation
// ---------------------------------------------------------------------------

class _ResolvedRoute {
  final String pattern;
  final PassageBuilder builder;
  final Shift? shift;
  final Widget Function(Widget child)? shell;
  final String? name;
  final Map<String, dynamic>? metadata;

  const _ResolvedRoute({
    required this.pattern,
    required this.builder,
    this.shift,
    this.shell,
    this.name,
    this.metadata,
  });
}

// ---------------------------------------------------------------------------
// Atlas Configuration (route state for Navigator 2.0)
// ---------------------------------------------------------------------------

/// The resolved navigation state.
class AtlasConfiguration {
  /// The current waypoint.
  final Waypoint waypoint;

  /// The navigation stack (for stack-based navigation).
  final List<Waypoint> stack;

  const AtlasConfiguration({
    required this.waypoint,
    this.stack = const [],
  });
}

// ---------------------------------------------------------------------------
// Atlas — The main router
// ---------------------------------------------------------------------------

/// **Atlas** — Titan's routing & navigation system.
///
/// Declarative, URL-based routing with zero boilerplate.
///
/// ```dart
/// final atlas = Atlas(
///   passages: [
///     Passage('/', (_) => HomeScreen()),
///     Passage('/login', (_) => LoginScreen()),
///     Passage('/profile/:id', (wp) => ProfileScreen(id: wp.runes['id']!)),
///   ],
///   sentinels: [
///     Sentinel((path, _) => isLoggedIn ? null : '/login'),
///   ],
///   drift: (path, waypoint) => null, // global redirect
///   onError: (path) => NotFoundScreen(path: path),
/// );
///
/// void main() => runApp(
///   MaterialApp.router(routerConfig: atlas.config),
/// );
/// ```
class Atlas {
  /// Global Atlas instance (set when [config] is accessed).
  static Atlas? _instance;

  /// The route trie for O(k) matching.
  final RouteTrie<_ResolvedRoute> _trie = RouteTrie<_ResolvedRoute>();

  /// Named routes for named navigation.
  final Map<String, String> _namedRoutes = {};

  /// Route guards.
  final List<Sentinel> _sentinels;

  /// Global redirect function.
  final String? Function(String path, Waypoint waypoint)? _drift;

  /// Error page builder (404).
  final Widget Function(String path)? _onError;

  /// Initial path.
  final String _initialPath;

  /// Default page transition.
  final Shift? _defaultShift;

  /// The router delegate.
  late final AtlasDelegate _delegate;

  /// The route information parser.
  late final AtlasParser _parser;

  /// Create an Atlas router.
  ///
  /// ```dart
  /// final atlas = Atlas(
  ///   passages: [
  ///     Passage('/', (_) => Home()),
  ///     Passage('/about', (_) => About()),
  ///   ],
  /// );
  /// ```
  Atlas({
    required List<AtlasRoute> passages,
    List<Sentinel> sentinels = const [],
    String? Function(String path, Waypoint waypoint)? drift,
    Widget Function(String path)? onError,
    String initialPath = '/',
    Shift? defaultShift,
  })  : _sentinels = sentinels,
        _drift = drift,
        _onError = onError,
        _initialPath = initialPath,
        _defaultShift = defaultShift {
    // Flatten and register all routes in the trie
    _registerRoutes(passages, null);

    // Initialize Navigator 2.0 components
    _delegate = AtlasDelegate(this);
    _parser = AtlasParser(_initialPath);

    // Set global instance
    _instance = this;
  }

  /// Recursively register routes in the trie.
  void _registerRoutes(
    List<AtlasRoute> routes,
    Widget Function(Widget child)? parentShell,
  ) {
    for (final route in routes) {
      switch (route) {
        case Passage():
          final resolved = _ResolvedRoute(
            pattern: route.path,
            builder: route.builder,
            shift: route.shift,
            shell: parentShell,
            name: route.name,
            metadata: route.metadata,
          );
          _trie.insert(route.path, resolved);
          if (route.name != null) {
            _namedRoutes[route.name!] = route.path;
          }
          // Register nested passages
          if (route.passages.isNotEmpty) {
            _registerRoutes(route.passages, parentShell);
          }

        case Sanctum():
          _registerRoutes(route.passages, route.shell);
      }
    }
  }

  /// Resolve a path to a widget, applying Sentinels and Drifts.
  _NavigationResult _resolve(String path, {Object? extra}) {
    // Parse the URI
    final uri = Uri.parse(path);
    final cleanPath = uri.path.isEmpty ? '/' : uri.path;
    final query = uri.queryParameters;

    // Create initial waypoint
    var waypoint = Waypoint(
      path: cleanPath,
      pattern: cleanPath,
      query: query,
      extra: extra,
    );

    // Apply global drift (redirect)
    if (_drift != null) {
      final redirect = _drift(cleanPath, waypoint);
      if (redirect != null && redirect != cleanPath) {
        return _resolve(redirect, extra: extra);
      }
    }

    // Apply sentinels
    for (final sentinel in _sentinels) {
      if (!sentinel.isAsync) {
        final redirect = sentinel.evaluate(cleanPath, waypoint);
        if (redirect != null && redirect != cleanPath) {
          return _resolve(redirect, extra: extra);
        }
      }
    }

    // Match route in trie
    final match = _trie.match(cleanPath);
    if (match == null) {
      // 404 — not found
      return _NavigationResult(
        waypoint: waypoint,
        widget: _onError?.call(cleanPath) ??
            _DefaultErrorPage(path: cleanPath),
        shift: null,
        shell: null,
      );
    }

    // Update waypoint with matched data
    waypoint = Waypoint(
      path: cleanPath,
      pattern: match.pattern,
      runes: match.runes,
      query: query,
      extra: extra,
      remaining: match.remaining,
    );

    final resolved = match.value;
    final widget = resolved.builder(waypoint);

    return _NavigationResult(
      waypoint: waypoint,
      widget: widget,
      shift: resolved.shift ?? _defaultShift,
      shell: resolved.shell,
    );
  }

  /// Get the RouterConfig for use with MaterialApp.router.
  ///
  /// ```dart
  /// MaterialApp.router(routerConfig: atlas.config)
  /// ```
  RouterConfig<Object> get config => RouterConfig(
        routerDelegate: _delegate,
        routeInformationParser: _parser,
        routeInformationProvider: PlatformRouteInformationProvider(
          initialRouteInformation: RouteInformation(
            uri: Uri.parse(_initialPath),
          ),
        ),
      );

  // -------------------------------------------------------------------------
  // Static navigation API
  // -------------------------------------------------------------------------

  /// Navigate to a path.
  ///
  /// ```dart
  /// Atlas.to('/profile/42');
  /// Atlas.to('/search?q=dart');
  /// Atlas.to('/details', extra: myData);
  /// ```
  static void to(String path, {Object? extra}) {
    _ensureInstance();
    _instance!._delegate._push(path, extra: extra);
  }

  /// Navigate to a named route.
  ///
  /// ```dart
  /// Atlas.toNamed('profile', runes: {'id': '42'});
  /// ```
  static void toNamed(
    String name, {
    Map<String, String> runes = const {},
    Map<String, String> query = const {},
    Object? extra,
  }) {
    _ensureInstance();
    final pattern = _instance!._namedRoutes[name];
    if (pattern == null) {
      throw StateError('Atlas: No passage named "$name" registered.');
    }
    // Replace :param with actual values
    var path = pattern;
    for (final entry in runes.entries) {
      path = path.replaceAll(':${entry.key}', entry.value);
    }
    if (query.isNotEmpty) {
      path += '?${Uri(queryParameters: query).query}';
    }
    to(path, extra: extra);
  }

  /// Replace the current route with a new path.
  ///
  /// ```dart
  /// Atlas.replace('/home');
  /// ```
  static void replace(String path, {Object? extra}) {
    _ensureInstance();
    _instance!._delegate._replace(path, extra: extra);
  }

  /// Go back to the previous route.
  ///
  /// ```dart
  /// Atlas.back();
  /// ```
  static void back() {
    _ensureInstance();
    _instance!._delegate._pop();
  }

  /// Go back to a specific path, removing all routes above it.
  ///
  /// ```dart
  /// Atlas.backTo('/home');
  /// ```
  static void backTo(String path) {
    _ensureInstance();
    _instance!._delegate._popUntil(path);
  }

  /// Reset the navigation stack to a single route.
  ///
  /// ```dart
  /// Atlas.reset('/login');
  /// ```
  static void reset(String path, {Object? extra}) {
    _ensureInstance();
    _instance!._delegate._reset(path, extra: extra);
  }

  /// Get the current waypoint.
  static Waypoint get current {
    _ensureInstance();
    return _instance!._delegate._currentWaypoint;
  }

  /// Check if we can go back.
  static bool get canBack {
    _ensureInstance();
    return _instance!._delegate._canPop;
  }

  static void _ensureInstance() {
    if (_instance == null) {
      throw StateError(
        'Atlas: No Atlas instance. Create an Atlas and use atlas.config '
        'with MaterialApp.router first.',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Navigation result (internal)
// ---------------------------------------------------------------------------

class _NavigationResult {
  final Waypoint waypoint;
  final Widget widget;
  final Shift? shift;
  final Widget Function(Widget child)? shell;

  const _NavigationResult({
    required this.waypoint,
    required this.widget,
    this.shift,
    this.shell,
  });
}

// ---------------------------------------------------------------------------
// AtlasDelegate — Navigator 2.0 RouterDelegate
// ---------------------------------------------------------------------------

/// The [RouterDelegate] for Atlas routing.
class AtlasDelegate extends RouterDelegate<AtlasConfiguration>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AtlasConfiguration> {
  final Atlas _atlas;
  final List<_NavigationResult> _stack = [];

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  AtlasDelegate(this._atlas) {
    // Resolve initial path
    final result = _atlas._resolve(_atlas._initialPath);
    _stack.add(result);
  }

  Waypoint get _currentWaypoint => _stack.last.waypoint;
  bool get _canPop => _stack.length > 1;

  void _push(String path, {Object? extra}) {
    final result = _atlas._resolve(path, extra: extra);
    _stack.add(result);
    notifyListeners();
  }

  void _replace(String path, {Object? extra}) {
    final result = _atlas._resolve(path, extra: extra);
    if (_stack.isNotEmpty) _stack.removeLast();
    _stack.add(result);
    notifyListeners();
  }

  void _pop() {
    if (_stack.length > 1) {
      _stack.removeLast();
      notifyListeners();
    }
  }

  void _popUntil(String path) {
    while (_stack.length > 1 && _stack.last.waypoint.path != path) {
      _stack.removeLast();
    }
    notifyListeners();
  }

  void _reset(String path, {Object? extra}) {
    final result = _atlas._resolve(path, extra: extra);
    _stack
      ..clear()
      ..add(result);
    notifyListeners();
  }

  @override
  AtlasConfiguration get currentConfiguration =>
      AtlasConfiguration(waypoint: _currentWaypoint);

  @override
  Future<void> setNewRoutePath(AtlasConfiguration configuration) async {
    // Handle URL changes (browser, deep links)
    final path = configuration.waypoint.path;
    if (_stack.isEmpty || _stack.last.waypoint.path != path) {
      final result = _atlas._resolve(path);
      _stack
        ..clear()
        ..add(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: _buildPages(),
      onDidRemovePage: (page) {
        if (_stack.length > 1) {
          _stack.removeLast();
        }
      },
    );
  }

  List<Page<dynamic>> _buildPages() {
    return _stack.map((result) {
      Widget page = result.widget;

      // Wrap in shell if this route has one
      if (result.shell != null) {
        page = result.shell!(page);
      }

      // Apply shift (transition) or default MaterialPage
      if (result.shift != null) {
        return result.shift!.buildPage(page, result.waypoint);
      }

      return MaterialPage(
        key: ValueKey(result.waypoint.path),
        child: page,
      );
    }).toList(growable: false);
  }
}

// ---------------------------------------------------------------------------
// AtlasParser — Navigator 2.0 RouteInformationParser
// ---------------------------------------------------------------------------

/// Parses route information (URLs) into [AtlasConfiguration].
class AtlasParser extends RouteInformationParser<AtlasConfiguration> {
  final String _initialPath;

  const AtlasParser(this._initialPath);

  @override
  Future<AtlasConfiguration> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = routeInformation.uri;
    final path = uri.path.isEmpty ? _initialPath : uri.path;
    final query = uri.queryParameters;

    return AtlasConfiguration(
      waypoint: Waypoint(
        path: path,
        pattern: path,
        query: query,
      ),
    );
  }

  @override
  RouteInformation? restoreRouteInformation(
    AtlasConfiguration configuration,
  ) {
    return RouteInformation(uri: configuration.waypoint.uri);
  }
}

// ---------------------------------------------------------------------------
// Default 404 page
// ---------------------------------------------------------------------------

class _DefaultErrorPage extends StatelessWidget {
  final String path;
  const _DefaultErrorPage({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '404',
              style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'No passage found for: $path',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
