import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

import 'dispatch.dart';
import 'envoy.dart';

/// Extension methods on [Pillar] for Envoy-powered data fetching.
///
/// These methods create [Quarry] and [Codex] instances backed by an
/// [Envoy] HTTP client, with automatic lifecycle management (the
/// Quarry/Codex nodes are disposed when the Pillar disposes).
///
/// ## Quick Start
///
/// ```dart
/// class UserPillar extends Pillar {
///   Envoy get envoy => Titan.get<Envoy>();
///
///   // SWR fetch — one line
///   late final users = envoyQuarry<List<User>>(
///     envoy: envoy,
///     path: '/users',
///     fromJson: (data) => (data as List).map(User.fromJson).toList(),
///     staleTime: Duration(minutes: 5),
///   );
///
///   // Paginated fetch — one line
///   late final feed = envoyCodex<Post>(
///     envoy: envoy,
///     path: '/posts',
///     fromPage: (data) => (data['items'] as List).map(Post.fromJson).toList(),
///     hasMore: (data) => data['hasMore'] as bool,
///   );
///
///   @override
///   void onInit() {
///     users.fetch();
///   }
/// }
/// ```
extension EnvoyPillarExtension on Pillar {
  /// Creates an Envoy-backed [Quarry] with SWR caching.
  ///
  /// Fetches data from [path] using [envoy], transforms the response
  /// with [fromJson], and manages the result as reactive state.
  ///
  /// All [Quarry] features work: stale-while-revalidate, retry,
  /// optimistic updates, invalidation, polling.
  ///
  /// - [envoy]: The [Envoy] client to use. Typically `Titan.get<Envoy>()`.
  /// - [path]: API endpoint path (appended to envoy's base URL).
  /// - [fromJson]: Transforms `Dispatch.data` into your domain type.
  /// - [method]: HTTP method (default: GET).
  /// - [queryParameters]: URL query parameters.
  /// - [headers]: Additional request headers.
  /// - [body]: Request body (for POST/PUT/PATCH).
  /// - [staleTime]: How long data stays fresh before becoming stale.
  /// - [retry]: Retry configuration for failed fetches.
  /// - [onSuccess]: Called after a successful fetch.
  /// - [onError]: Called after a failed fetch.
  /// - [name]: Debug name for logging.
  ///
  /// ```dart
  /// late final profile = envoyQuarry<UserProfile>(
  ///   envoy: Titan.get<Envoy>(),
  ///   path: '/me',
  ///   fromJson: (data) => UserProfile.fromJson(data as Map<String, dynamic>),
  ///   staleTime: Duration(minutes: 10),
  /// );
  /// ```
  Quarry<T> envoyQuarry<T>({
    required Envoy envoy,
    required String path,
    required T Function(Object? data) fromJson,
    String method = 'GET',
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Object? body,
    Duration? staleTime,
    QuarryRetry retry = const QuarryRetry(maxAttempts: 0),
    void Function(T data)? onSuccess,
    void Function(Object error)? onError,
    String? name,
  }) {
    final q = Quarry<T>(
      fetcher: () async {
        final dispatch = await _sendByMethod(
          envoy,
          method,
          path,
          data: body,
          queryParameters: queryParameters,
          headers: headers,
        );
        return fromJson(dispatch.data);
      },
      staleTime: staleTime,
      retry: retry,
      onSuccess: onSuccess,
      onError: onError,
      name: name ?? 'envoyQuarry($path)',
    );
    registerNodes(q.managedNodes);
    return q;
  }

  /// Creates an Envoy-backed [Codex] for paginated data.
  ///
  /// Fetches pages from [path] using [envoy], transforms each page's
  /// response with [fromPage], and manages pagination state reactively.
  ///
  /// - [envoy]: The [Envoy] client to use.
  /// - [path]: API endpoint path. Query params `page` and `pageSize`
  ///   are appended automatically.
  /// - [fromPage]: Extracts a list of items from `Dispatch.data`.
  /// - [hasMore]: Determines if more pages are available from `Dispatch.data`.
  /// - [pageSize]: Items per page (default: 20).
  /// - [queryParameters]: Additional query parameters.
  /// - [headers]: Additional request headers.
  /// - [name]: Debug name for logging.
  ///
  /// ```dart
  /// late final quests = envoyCodex<Quest>(
  ///   envoy: Titan.get<Envoy>(),
  ///   path: '/quests',
  ///   fromPage: (data) =>
  ///       (data['items'] as List).map(Quest.fromJson).toList(),
  ///   hasMore: (data) => data['hasMore'] as bool,
  ///   pageSize: 25,
  /// );
  ///
  /// @override
  /// void onInit() {
  ///   quests.fetchInitial(); // Load first page
  /// }
  ///
  /// void loadMore() => quests.fetchNext(); // Load next page
  /// ```
  Codex<T> envoyCodex<T>({
    required Envoy envoy,
    required String path,
    required List<T> Function(Object? data) fromPage,
    required bool Function(Object? data) hasMore,
    int pageSize = 20,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? name,
  }) {
    final c = Codex<T>(
      fetcher: (request) async {
        final params = <String, String>{
          'page': request.page.toString(),
          'pageSize': request.pageSize.toString(),
          ...?queryParameters,
        };

        if (request.cursor != null) {
          params['cursor'] = request.cursor!;
        }

        final dispatch = await envoy.get(
          path,
          queryParameters: params,
          headers: headers,
        );

        final items = fromPage(dispatch.data);
        final more = hasMore(dispatch.data);

        return CodexPage<T>(
          items: items,
          hasMore: more,
          nextCursor: _extractCursor(dispatch),
        );
      },
      pageSize: pageSize,
      name: name ?? 'envoyCodex($path)',
    );
    registerNodes(c.managedNodes);
    return c;
  }

  /// Extracts a cursor from the response for cursor-based pagination.
  ///
  /// Checks `Dispatch.data['cursor']` or `Dispatch.data['nextCursor']`.
  String? _extractCursor(Dispatch dispatch) {
    if (dispatch.data is Map) {
      final map = dispatch.data as Map;
      return (map['cursor'] ?? map['nextCursor'])?.toString();
    }
    return null;
  }

  /// Routes to the correct [Envoy] convenience method based on [method].
  Future<Dispatch> _sendByMethod(
    Envoy envoy,
    String method,
    String path, {
    Object? data,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) {
    return switch (method.toUpperCase()) {
      'POST' => envoy.post(
        path,
        data: data,
        queryParameters: queryParameters,
        headers: headers,
      ),
      'PUT' => envoy.put(
        path,
        data: data,
        queryParameters: queryParameters,
        headers: headers,
      ),
      'PATCH' => envoy.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        headers: headers,
      ),
      'DELETE' => envoy.delete(
        path,
        queryParameters: queryParameters,
        headers: headers,
      ),
      _ => envoy.get(path, queryParameters: queryParameters, headers: headers),
    };
  }
}
