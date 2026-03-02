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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:titan/titan.dart';

import '../core/atlas_observer.dart';
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
  final String? Function(Waypoint waypoint)? redirect;
  final List<Pillar Function()> pillarFactories;

  const _ResolvedRoute({
    required this.pattern,
    required this.builder,
    this.shift,
    this.shell,
    this.name,
    this.metadata,
    this.redirect,
    this.pillarFactories = const [],
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

  /// Creates an [AtlasConfiguration] with the current [waypoint] and
  /// optional navigation [stack].
  const AtlasConfiguration({required this.waypoint, this.stack = const []});
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

  /// Navigation observers.
  final List<AtlasObserver> _observers;

  /// Global redirect function.
  final String? Function(String path, Waypoint waypoint)? _drift;

  /// Error page builder (404).
  final Widget Function(String path)? _onError;

  /// Initial path.
  final String _initialPath;

  /// Default page transition.
  final Shift? _defaultShift;

  /// Listenable that triggers re-evaluation of Sentinels and Drift.
  final Listenable? _refreshListenable;

  /// Cleanup callback for the refresh listener.
  void Function()? _refreshSubscription;

  /// Guard against re-entrant refresh calls.
  bool _isRefreshing = false;

  /// The router delegate.
  late final AtlasDelegate _delegate;

  /// The route information parser.
  late final AtlasParser _parser;

  /// Create an Atlas router.
  ///
  /// ```dart
  /// final atlas = Atlas(
  ///   pillars: [AuthPillar.new, AppPillar.new],
  ///   passages: [
  ///     Passage('/', (_) => Home()),
  ///     Passage('/about', (_) => About()),
  ///   ],
  ///   observers: [AtlasLoggingObserver()],
  /// );
  /// ```
  Atlas({
    required List<AtlasRoute> passages,
    List<Pillar Function()> pillars = const [],
    List<Sentinel> sentinels = const [],
    List<AtlasObserver> observers = const [],
    String? Function(String path, Waypoint waypoint)? drift,
    Widget Function(String path)? onError,
    String initialPath = '/',
    Shift? defaultShift,
    Listenable? refreshListenable,
  }) : _sentinels = sentinels,
       _observers = observers,
       _drift = drift,
       _onError = onError,
       _initialPath = initialPath,
       _defaultShift = defaultShift,
       _refreshListenable = refreshListenable {
    // Clean up previous instance's refresh listener
    if (_instance != null) {
      _instance!._removeRefreshListener();
    }

    // Register global Pillars via Titan DI
    for (final factory in pillars) {
      Titan.forge(factory());
    }

    // Flatten and register all routes in the trie
    _registerRoutes(passages, null, const []);

    // Initialize Navigator 2.0 components
    _delegate = AtlasDelegate(this);
    _parser = AtlasParser(_initialPath);

    // Set global instance
    _instance = this;

    // Subscribe to refresh listenable for reactive Sentinel re-evaluation
    if (_refreshListenable case final listenable?) {
      void onRefresh() => _onRefresh();
      listenable.addListener(onRefresh);
      _refreshSubscription = () => listenable.removeListener(onRefresh);
    }
  }

  /// Recursively register routes in the trie.
  void _registerRoutes(
    List<AtlasRoute> routes,
    Widget Function(Widget child)? parentShell,
    List<Pillar Function()> parentPillars,
  ) {
    for (final route in routes) {
      switch (route) {
        case Passage():
          // Combine parent (Sanctum) pillars with Passage's own pillars
          final combinedPillars = [...parentPillars, ...route.pillars];
          final resolved = _ResolvedRoute(
            pattern: route.path,
            builder: route.builder,
            shift: route.shift,
            shell: parentShell,
            name: route.name,
            metadata: route.metadata,
            redirect: route.redirect,
            pillarFactories: combinedPillars,
          );
          _trie.insert(route.path, resolved);
          if (route.name != null) {
            _namedRoutes[route.name!] = route.path;
          }
          // Register nested passages
          if (route.passages.isNotEmpty) {
            _registerRoutes(route.passages, parentShell, combinedPillars);
          }

        case Sanctum():
          _registerRoutes(route.passages, route.shell, [
            ...parentPillars,
            ...route.pillars,
          ]);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Refresh listenable — reactive Sentinel re-evaluation
  // -------------------------------------------------------------------------

  /// Handles refresh notifications by re-evaluating the current path
  /// through Drift and Sentinels. If the resolved path differs from the
  /// current path, Atlas navigates to the new destination.
  void _onRefresh() {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final currentWaypoint = _delegate._currentWaypoint;
      final currentPath = currentWaypoint.uri.toString();

      if (_hasAsyncSentinels) {
        _resolveAsync(currentPath).then((result) {
          _applyRefreshResult(currentPath, result);
          _isRefreshing = false;
        });
      } else {
        final result = _resolve(currentPath);
        _applyRefreshResult(currentPath, result);
        _isRefreshing = false;
      }
    } catch (_) {
      _isRefreshing = false;
    }
  }

  /// Applies the result of a refresh re-evaluation. If the resolved path
  /// differs from the current path, resets the navigation stack.
  void _applyRefreshResult(String originalPath, _NavigationResult result) {
    final resolvedPath = result.waypoint.path;
    if (resolvedPath != originalPath) {
      // Sentinel or Drift redirected — navigate to the new destination
      _delegate._reset(resolvedPath);
    } else {
      // Dispose pillars that were unnecessarily created during re-resolve
      result.disposePillars();
    }
  }

  /// Removes the refresh listener subscription.
  void _removeRefreshListener() {
    _refreshSubscription?.call();
    _refreshSubscription = null;
  }

  /// Resolve a path to a widget, applying Drifts, Sentinels, and per-route redirects.
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
        for (final observer in _observers) {
          observer.onDriftRedirect(cleanPath, redirect);
        }
        return _resolve(redirect, extra: extra);
      }
    }

    // Apply sentinels (sync)
    for (final sentinel in _sentinels) {
      if (!sentinel.isAsync) {
        final redirect = sentinel.evaluate(cleanPath, waypoint);
        if (redirect != null && redirect != cleanPath) {
          for (final observer in _observers) {
            observer.onGuardRedirect(cleanPath, redirect);
          }
          return _resolve(redirect, extra: extra);
        }
      }
    }

    // Match route in trie
    final match = _trie.match(cleanPath);
    if (match == null) {
      // 404 — not found
      for (final observer in _observers) {
        observer.onNotFound(cleanPath);
      }
      return _NavigationResult(
        waypoint: waypoint,
        widget: _onError?.call(cleanPath) ?? _DefaultErrorPage(path: cleanPath),
        shift: null,
        shell: null,
      );
    }

    final resolved = match.value;

    // Update waypoint with matched data + metadata + name
    waypoint = Waypoint(
      path: cleanPath,
      pattern: match.pattern,
      runes: match.runes,
      query: query,
      extra: extra,
      remaining: match.remaining,
      metadata: resolved.metadata,
      name: resolved.name,
    );

    // Apply per-route redirect
    if (resolved.redirect != null) {
      final redirect = resolved.redirect!(waypoint);
      if (redirect != null && redirect != cleanPath) {
        return _resolve(redirect, extra: extra);
      }
    }

    // Create route-scoped Pillars BEFORE calling the builder
    final ownedPillars = <Pillar>[];
    for (final factory in resolved.pillarFactories) {
      final pillar = factory();
      Titan.forge(pillar);
      ownedPillars.add(pillar);
    }

    final widget = resolved.builder(waypoint);

    return _NavigationResult(
      waypoint: waypoint,
      widget: widget,
      shift: resolved.shift ?? _defaultShift,
      shell: resolved.shell,
      ownedPillars: ownedPillars,
    );
  }

  /// Resolve a path asynchronously (applies async Sentinels).
  ///
  /// Call this instead of `_resolve` when you have `Sentinel.async` guards.
  Future<_NavigationResult> _resolveAsync(String path, {Object? extra}) async {
    final uri = Uri.parse(path);
    final cleanPath = uri.path.isEmpty ? '/' : uri.path;
    final query = uri.queryParameters;

    var waypoint = Waypoint(
      path: cleanPath,
      pattern: cleanPath,
      query: query,
      extra: extra,
    );

    // Apply drift
    if (_drift != null) {
      final redirect = _drift(cleanPath, waypoint);
      if (redirect != null && redirect != cleanPath) {
        for (final observer in _observers) {
          observer.onDriftRedirect(cleanPath, redirect);
        }
        return _resolveAsync(redirect, extra: extra);
      }
    }

    // Apply ALL sentinels (sync + async)
    for (final sentinel in _sentinels) {
      final redirect = await sentinel.evaluateAsync(cleanPath, waypoint);
      if (redirect != null && redirect != cleanPath) {
        for (final observer in _observers) {
          observer.onGuardRedirect(cleanPath, redirect);
        }
        return _resolveAsync(redirect, extra: extra);
      }
    }

    // Match route in trie
    final match = _trie.match(cleanPath);
    if (match == null) {
      for (final observer in _observers) {
        observer.onNotFound(cleanPath);
      }
      return _NavigationResult(
        waypoint: waypoint,
        widget: _onError?.call(cleanPath) ?? _DefaultErrorPage(path: cleanPath),
        shift: null,
        shell: null,
      );
    }

    final resolved = match.value;

    waypoint = Waypoint(
      path: cleanPath,
      pattern: match.pattern,
      runes: match.runes,
      query: query,
      extra: extra,
      remaining: match.remaining,
      metadata: resolved.metadata,
      name: resolved.name,
    );

    if (resolved.redirect != null) {
      final redirect = resolved.redirect!(waypoint);
      if (redirect != null && redirect != cleanPath) {
        return _resolveAsync(redirect, extra: extra);
      }
    }

    // Create route-scoped Pillars BEFORE calling the builder
    final ownedPillars = <Pillar>[];
    for (final factory in resolved.pillarFactories) {
      final pillar = factory();
      Titan.forge(pillar);
      ownedPillars.add(pillar);
    }

    final widget = resolved.builder(waypoint);

    return _NavigationResult(
      waypoint: waypoint,
      widget: widget,
      shift: resolved.shift ?? _defaultShift,
      shell: resolved.shell,
      ownedPillars: ownedPillars,
    );
  }

  /// Whether any registered Sentinel is async.
  bool get _hasAsyncSentinels => _sentinels.any((s) => s.isAsync);

  /// Get the RouterConfig for use with MaterialApp.router.
  ///
  /// Automatically ensures `WidgetsBinding` is initialized before creating
  /// the route information provider. Safe to call before `runApp()`.
  ///
  /// ```dart
  /// MaterialApp.router(routerConfig: atlas.config)
  /// ```
  RouterConfig<Object> get config {
    // Ensure the binding exists — PlatformRouteInformationProvider requires it.
    WidgetsFlutterBinding.ensureInitialized();

    return RouterConfig(
      routerDelegate: _delegate,
      routeInformationParser: _parser,
      routeInformationProvider: PlatformRouteInformationProvider(
        initialRouteInformation: RouteInformation(uri: Uri.parse(_initialPath)),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Static navigation API
  // -------------------------------------------------------------------------

  /// Navigate to a path.
  ///
  /// Pushes a new route onto the stack. Use [go] for declarative
  /// navigation that reuses existing stack entries.
  ///
  /// ```dart
  /// Atlas.to('/profile/42');
  /// Atlas.to('/search?q=dart');
  /// Atlas.to('/details', extra: myData);
  /// ```
  static void to(String path, {Object? extra}) {
    _ensureInstance();
    if (_instance!._hasAsyncSentinels) {
      _instance!._delegate._pushAsync(path, extra: extra);
    } else {
      _instance!._delegate._push(path, extra: extra);
    }
  }

  /// Push a route and wait for a result.
  ///
  /// Returns a [Future] that completes with the result value when the
  /// pushed route is popped (via [back]). If the route is popped without
  /// a result (system back, [go], [reset], etc.), the Future completes
  /// with `null`.
  ///
  /// ```dart
  /// final confirmed = await Atlas.push<bool>('/confirm-dialog');
  /// if (confirmed == true) {
  ///   // User confirmed
  /// }
  /// ```
  static Future<T?> push<T>(String path, {Object? extra}) {
    _ensureInstance();
    return _instance!._delegate._pushWithResult<T>(path, extra: extra);
  }

  /// Navigate to a path (declarative / go-style).
  ///
  /// If the path already exists in the stack, pops back to it instead
  /// of creating a duplicate entry. If the path is new, replaces the
  /// entire stack. Use this for tab navigation, bottom nav bars, and
  /// any scenario where you want to "go to" a destination rather than
  /// "push" it.
  ///
  /// ```dart
  /// Atlas.go('/');        // go to home (reuse existing)
  /// Atlas.go('/hero');    // go to hero tab
  /// ```
  static void go(String path, {Object? extra}) {
    _ensureInstance();
    _instance!._delegate._go(path, extra: extra);
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
  /// Optionally pass a [result] that will be returned to the caller
  /// of [push] for this route.
  ///
  /// ```dart
  /// Atlas.back();           // pop without result
  /// Atlas.back(true);       // pop with result
  /// Atlas.back({'id': 42}); // pop with map result
  /// ```
  static void back([Object? result]) {
    _ensureInstance();
    _instance!._delegate._pop(result);
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

  /// The current navigation stack depth.
  ///
  /// Returns the number of routes in the stack.
  ///
  /// ```dart
  /// if (Atlas.depth > 1) {
  ///   showBackButton();
  /// }
  /// ```
  static int get depth {
    _ensureInstance();
    return _instance!._delegate._stack.length;
  }

  /// The full navigation stack as a list of [Waypoint]s.
  ///
  /// Returns an unmodifiable view of the current navigation history.
  /// Useful for breadcrumb navigation, analytics, and debugging.
  ///
  /// ```dart
  /// // Build breadcrumbs
  /// final breadcrumbs = Atlas.stack;
  /// for (final waypoint in breadcrumbs) {
  ///   print('${waypoint.path} → ');
  /// }
  /// ```
  static List<Waypoint> get stack {
    _ensureInstance();
    return List.unmodifiable(
      _instance!._delegate._stack.map((r) => r.waypoint),
    );
  }

  /// Whether the current route matches the given [path].
  ///
  /// Compares the current waypoint's path with the provided path.
  ///
  /// ```dart
  /// if (Atlas.isAt('/home')) {
  ///   highlightHomeTab();
  /// }
  /// ```
  static bool isAt(String path) {
    _ensureInstance();
    return _instance!._delegate._currentWaypoint.path == path;
  }

  /// Whether the given [path] exists in the current navigation stack.
  ///
  /// ```dart
  /// if (Atlas.canBackTo('/home')) {
  ///   Atlas.backTo('/home');
  /// }
  /// ```
  static bool hasInStack(String path) {
    _ensureInstance();
    return _instance!._delegate._stack.any((r) => r.waypoint.path == path);
  }

  /// Whether the given [path] exists in the registered routes.
  ///
  /// ```dart
  /// if (Atlas.hasRoute('/admin')) {
  ///   showAdminLink();
  /// }
  /// ```
  static bool hasRoute(String path) {
    _ensureInstance();
    return _instance!._trie.match(path) != null;
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

  /// Pillar instances owned by this route entry.
  /// Created during resolution, disposed when route leaves the stack.
  final List<Pillar> ownedPillars;

  /// Completer for push-with-result navigation.
  /// When non-null, the Completer is completed when this entry is popped.
  Completer<Object?>? resultCompleter;

  _NavigationResult({
    required this.waypoint,
    required this.widget,
    this.shift,
    this.shell,
    this.ownedPillars = const [],
  });

  /// Remove and dispose route-scoped Pillars from Titan.
  void disposePillars() {
    for (final pillar in ownedPillars) {
      Titan.removeByType(pillar.runtimeType);
    }
  }
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

  /// Creates an [AtlasDelegate] for the given [Atlas] instance and resolves
  /// the initial route.
  AtlasDelegate(this._atlas) {
    // Resolve initial path (pillars are created inside _resolve)
    final result = _atlas._resolve(_atlas._initialPath);
    _stack.add(result);
  }

  Waypoint get _currentWaypoint => _stack.last.waypoint;
  bool get _canPop => _stack.length > 1;

  void _push(String path, {Object? extra}) {
    final from = _currentWaypoint;
    final result = _atlas._resolve(path, extra: extra);
    _stack.add(result);
    for (final observer in _atlas._observers) {
      observer.onNavigate(from, result.waypoint);
    }
    notifyListeners();
  }

  Future<T?> _pushWithResult<T>(String path, {Object? extra}) {
    final from = _currentWaypoint;
    final completer = Completer<Object?>();
    final result = _atlas._hasAsyncSentinels
        ? null // handled below for async sentinels
        : _atlas._resolve(path, extra: extra);

    if (result != null) {
      result.resultCompleter = completer;
      _stack.add(result);
      for (final observer in _atlas._observers) {
        observer.onNavigate(from, result.waypoint);
      }
      notifyListeners();
    } else {
      // Async sentinel path
      _atlas._resolveAsync(path, extra: extra).then((asyncResult) {
        asyncResult.resultCompleter = completer;
        _stack.add(asyncResult);
        for (final observer in _atlas._observers) {
          observer.onNavigate(from, asyncResult.waypoint);
        }
        notifyListeners();
      });
    }

    return completer.future.then((value) => value as T?);
  }

  void _go(String path, {Object? extra}) {
    // No-op if already at this path
    if (_currentWaypoint.path == path) return;

    final from = _currentWaypoint;

    // If path exists in the stack, pop back to it
    final index = _stack.indexWhere((r) => r.waypoint.path == path);
    if (index >= 0) {
      while (_stack.length > index + 1) {
        final removed = _stack.last;
        removed.resultCompleter?.complete(null);
        removed.disposePillars();
        _stack.removeLast();
      }
    } else {
      // Clear stack and navigate fresh
      for (final entry in _stack) {
        entry.resultCompleter?.complete(null);
        entry.disposePillars();
      }
      final result = _atlas._resolve(path, extra: extra);
      _stack
        ..clear()
        ..add(result);
    }

    for (final observer in _atlas._observers) {
      observer.onNavigate(from, _currentWaypoint);
    }
    notifyListeners();
  }

  Future<void> _pushAsync(String path, {Object? extra}) async {
    final from = _currentWaypoint;
    final result = await _atlas._resolveAsync(path, extra: extra);
    _stack.add(result);
    for (final observer in _atlas._observers) {
      observer.onNavigate(from, result.waypoint);
    }
    notifyListeners();
  }

  void _replace(String path, {Object? extra}) {
    final from = _currentWaypoint;
    if (_stack.isNotEmpty) {
      final removed = _stack.last;
      removed.resultCompleter?.complete(null);
      removed.disposePillars();
      _stack.removeLast();
    }
    final result = _atlas._resolve(path, extra: extra);
    _stack.add(result);
    for (final observer in _atlas._observers) {
      observer.onReplace(from, result.waypoint);
    }
    notifyListeners();
  }

  void _pop([Object? result]) {
    if (_stack.length > 1) {
      final from = _currentWaypoint;
      final popped = _stack.last;
      popped.resultCompleter?.complete(result);
      popped.disposePillars();
      _stack.removeLast();
      for (final observer in _atlas._observers) {
        observer.onPop(from, _currentWaypoint);
      }
      notifyListeners();
    }
  }

  void _popUntil(String path) {
    final from = _currentWaypoint;
    while (_stack.length > 1 && _stack.last.waypoint.path != path) {
      final removed = _stack.last;
      removed.resultCompleter?.complete(null);
      removed.disposePillars();
      _stack.removeLast();
    }
    for (final observer in _atlas._observers) {
      observer.onPop(from, _currentWaypoint);
    }
    notifyListeners();
  }

  void _reset(String path, {Object? extra}) {
    // Complete pending result completers and dispose route-scoped pillars
    for (final entry in _stack) {
      entry.resultCompleter?.complete(null);
      entry.disposePillars();
    }
    final result = _atlas._resolve(path, extra: extra);
    _stack
      ..clear()
      ..add(result);
    for (final observer in _atlas._observers) {
      observer.onReset(result.waypoint);
    }
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
      // Complete pending result completers and dispose route-scoped pillars
      for (final entry in _stack) {
        entry.resultCompleter?.complete(null);
        entry.disposePillars();
      }
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
          final removed = _stack.last;
          removed.resultCompleter?.complete(null);
          removed.disposePillars();
          _stack.removeLast();
        }
      },
    );
  }

  List<Page<dynamic>> _buildPages() {
    return _stack
        .map((result) {
          Widget page = result.widget;

          // Wrap in shell if this route has one
          if (result.shell != null) {
            page = result.shell!(page);
          }

          // Apply shift (transition) or default MaterialPage
          if (result.shift != null) {
            return result.shift!.buildPage(page, result.waypoint);
          }

          return MaterialPage(key: ValueKey(result.waypoint.path), child: page);
        })
        .toList(growable: false);
  }
}

// ---------------------------------------------------------------------------
// AtlasParser — Navigator 2.0 RouteInformationParser
// ---------------------------------------------------------------------------

/// Parses route information (URLs) into [AtlasConfiguration].
class AtlasParser extends RouteInformationParser<AtlasConfiguration> {
  final String _initialPath;

  /// Creates an [AtlasParser] that falls back to [_initialPath] when the
  /// incoming URL is empty.
  const AtlasParser(this._initialPath);

  @override
  Future<AtlasConfiguration> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = routeInformation.uri;
    final path = uri.path.isEmpty ? _initialPath : uri.path;
    final query = uri.queryParameters;

    return AtlasConfiguration(
      waypoint: Waypoint(path: path, pattern: path, query: query),
    );
  }

  @override
  RouteInformation? restoreRouteInformation(AtlasConfiguration configuration) {
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
