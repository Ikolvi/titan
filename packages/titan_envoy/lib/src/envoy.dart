import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'courier.dart';
import 'dispatch.dart';
import 'envoy_error.dart';
import 'missive.dart';
import 'parcel.dart';
import 'recall.dart';
import 'security.dart';
import 'transport/transport.dart';
import 'transport/transport_factory.dart';

/// Envoy — Titan's HTTP client for making network requests.
///
/// Supports all HTTP methods, interceptor chains via [Courier], request
/// cancellation via [Recall], timeouts, and pluggable adapters.
///
/// ```dart
/// final envoy = Envoy(baseUrl: 'https://api.example.com');
///
/// // Simple GET
/// final dispatch = await envoy.get('/users');
/// print(dispatch.data); // parsed JSON
///
/// // POST with body
/// final created = await envoy.post('/users', data: {'name': 'Kael'});
///
/// // With couriers (interceptors)
/// envoy
///   ..addCourier(LogCourier())
///   ..addCourier(RetryCourier(maxRetries: 3));
///
/// // Cleanup
/// envoy.close();
/// ```
class Envoy {
  /// Creates a new [Envoy] HTTP client.
  ///
  /// - [baseUrl]: Prepended to all relative paths.
  /// - [headers]: Default headers sent with every request.
  /// - [connectTimeout]: Timeout for establishing a connection.
  /// - [sendTimeout]: Default timeout for sending request body.
  /// - [receiveTimeout]: Default timeout for receiving response.
  /// - [validateStatus]: Default status validator. Returns `true` for
  ///   status codes considered successful.
  /// - [followRedirects]: Whether to follow redirects (default: `true`).
  /// - [maxRedirects]: Maximum redirect hops (default: `5`).
  /// - [pin]: SSL/TLS certificate pinning configuration.
  /// - [proxy]: HTTP/HTTPS proxy configuration.
  Envoy({
    this.baseUrl = '',
    Map<String, String>? headers,
    this.connectTimeout,
    this.sendTimeout,
    this.receiveTimeout,
    this.validateStatus,
    this.followRedirects = true,
    this.maxRedirects = 5,
    this.pin,
    this.proxy,
  }) : defaultHeaders = headers ?? {};

  /// Base URL prepended to all relative request paths.
  String baseUrl;

  /// Default headers sent with every request.
  ///
  /// Individual [Missive] headers take precedence over defaults.
  final Map<String, String> defaultHeaders;

  /// Timeout for establishing a connection.
  Duration? connectTimeout;

  /// Default timeout for sending request body.
  Duration? sendTimeout;

  /// Default timeout for receiving response.
  Duration? receiveTimeout;

  /// Default status code validator.
  ///
  /// Return `true` to treat the status as successful.
  /// Defaults to `status >= 200 && status < 300`.
  bool Function(int status)? validateStatus;

  /// Whether to follow redirects by default.
  bool followRedirects;

  /// Maximum number of redirect hops.
  int maxRedirects;

  /// SSL/TLS certificate pinning configuration.
  ///
  /// When set, server certificates are validated against pinned
  /// fingerprints to prevent man-in-the-middle attacks.
  final EnvoyPin? pin;

  /// HTTP/HTTPS proxy configuration.
  ///
  /// Routes all requests through the specified proxy server.
  final EnvoyProxy? proxy;

  final List<Courier> _couriers = [];
  EnvoyTransport? _transport;
  bool _closed = false;

  /// The registered [Courier] interceptors.
  List<Courier> get couriers => List.unmodifiable(_couriers);

  EnvoyTransport get _activeTransport {
    if (_closed) throw StateError('Envoy has been closed');
    return _transport ??= createTransport(
      connectTimeout: connectTimeout,
      pin: pin,
      proxy: proxy,
    );
  }

  // ── HTTP Methods ─────────────────────────────────────────────────

  /// Sends a GET request. Returns a [Dispatch] with the response.
  ///
  /// ```dart
  /// final dispatch = await envoy.get('/users', queryParameters: {'page': '1'});
  /// print(dispatch.jsonList); // [{"id": 1, "name": "Kael"}, ...]
  /// ```
  Future<Dispatch> get(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Recall? recall,
    Duration? receiveTimeout,
    Map<String, Object?>? extra,
  }) {
    return send(
      Missive(
        method: Method.get,
        uri: _resolveUri(path),
        headers: _mergeHeaders(headers),
        queryParameters: queryParameters ?? const {},
        recall: recall,
        receiveTimeout: receiveTimeout ?? this.receiveTimeout,
        extra: extra ?? const {},
      ),
    );
  }

  /// Sends a POST request. Returns a [Dispatch] with the response.
  ///
  /// ```dart
  /// final dispatch = await envoy.post('/users', data: {'name': 'Kael'});
  /// print(dispatch.statusCode); // 201
  /// ```
  Future<Dispatch> post(
    String path, {
    Object? data,
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Recall? recall,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    Map<String, Object?>? extra,
  }) {
    return send(
      Missive(
        method: Method.post,
        uri: _resolveUri(path),
        data: data,
        headers: _mergeHeaders(headers),
        queryParameters: queryParameters ?? const {},
        recall: recall,
        sendTimeout: sendTimeout ?? this.sendTimeout,
        receiveTimeout: receiveTimeout ?? this.receiveTimeout,
        extra: extra ?? const {},
      ),
    );
  }

  /// Sends a PUT request. Returns a [Dispatch] with the response.
  ///
  /// ```dart
  /// final dispatch = await envoy.put('/users/1', data: {'name': 'Updated'});
  /// ```
  Future<Dispatch> put(
    String path, {
    Object? data,
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Recall? recall,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    Map<String, Object?>? extra,
  }) {
    return send(
      Missive(
        method: Method.put,
        uri: _resolveUri(path),
        data: data,
        headers: _mergeHeaders(headers),
        queryParameters: queryParameters ?? const {},
        recall: recall,
        sendTimeout: sendTimeout ?? this.sendTimeout,
        receiveTimeout: receiveTimeout ?? this.receiveTimeout,
        extra: extra ?? const {},
      ),
    );
  }

  /// Sends a DELETE request. Returns a [Dispatch] with the response.
  ///
  /// ```dart
  /// final dispatch = await envoy.delete('/users/1');
  /// print(dispatch.statusCode); // 204
  /// ```
  Future<Dispatch> delete(
    String path, {
    Object? data,
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Recall? recall,
    Duration? receiveTimeout,
    Map<String, Object?>? extra,
  }) {
    return send(
      Missive(
        method: Method.delete,
        uri: _resolveUri(path),
        data: data,
        headers: _mergeHeaders(headers),
        queryParameters: queryParameters ?? const {},
        recall: recall,
        receiveTimeout: receiveTimeout ?? this.receiveTimeout,
        extra: extra ?? const {},
      ),
    );
  }

  /// Sends a PATCH request. Returns a [Dispatch] with the response.
  ///
  /// ```dart
  /// final dispatch = await envoy.patch('/users/1', data: {'name': 'Patched'});
  /// ```
  Future<Dispatch> patch(
    String path, {
    Object? data,
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Recall? recall,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    Map<String, Object?>? extra,
  }) {
    return send(
      Missive(
        method: Method.patch,
        uri: _resolveUri(path),
        data: data,
        headers: _mergeHeaders(headers),
        queryParameters: queryParameters ?? const {},
        recall: recall,
        sendTimeout: sendTimeout ?? this.sendTimeout,
        receiveTimeout: receiveTimeout ?? this.receiveTimeout,
        extra: extra ?? const {},
      ),
    );
  }

  /// Sends a HEAD request. Returns a [Dispatch] with headers only.
  ///
  /// ```dart
  /// final dispatch = await envoy.head('/resource');
  /// print(dispatch.headers['content-length']);
  /// ```
  Future<Dispatch> head(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Recall? recall,
    Duration? receiveTimeout,
    Map<String, Object?>? extra,
  }) {
    return send(
      Missive(
        method: Method.head,
        uri: _resolveUri(path),
        headers: _mergeHeaders(headers),
        queryParameters: queryParameters ?? const {},
        recall: recall,
        receiveTimeout: receiveTimeout ?? this.receiveTimeout,
        extra: extra ?? const {},
      ),
    );
  }

  // ── Core Send ────────────────────────────────────────────────────

  /// Sends a fully configured [Missive] through the courier chain.
  ///
  /// This is the low-level method that all HTTP convenience methods
  /// delegate to. Use this for custom request configurations.
  ///
  /// ```dart
  /// final dispatch = await envoy.send(Missive(
  ///   method: Method.get,
  ///   uri: Uri.parse('https://api.example.com/custom'),
  ///   headers: {'X-Custom': 'value'},
  /// ));
  /// ```
  Future<Dispatch> send(Missive missive) async {
    if (_closed) throw StateError('Envoy has been closed');

    try {
      // Check for early cancellation
      missive.recall?.throwIfCancelled(missive);

      // Build the courier chain and execute
      final chain = CourierChain(couriers: _couriers, execute: _executeRequest);
      return await chain.proceed(missive);
    } on EnvoyError {
      rethrow;
    } catch (e, st) {
      if (_isCancellation(e)) {
        throw EnvoyError.cancelled(missive: missive);
      }
      throw EnvoyError(
        type: EnvoyErrorType.unknown,
        missive: missive,
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Downloads a URL and returns the response body as bytes.
  ///
  /// Progress is reported through the [onReceiveProgress] callback on the
  /// [Missive], or via the optional [onProgress] parameter.
  ///
  /// ```dart
  /// final dispatch = await envoy.download(
  ///   '/files/report.pdf',
  ///   onProgress: (received, total) {
  ///     print('${(received / total * 100).toStringAsFixed(1)}%');
  ///   },
  /// );
  /// final bytes = dispatch.data as Uint8List;
  /// ```
  Future<Dispatch> download(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Recall? recall,
    Duration? receiveTimeout,
    void Function(int received, int total)? onProgress,
    Map<String, Object?>? extra,
  }) {
    return send(
      Missive(
        method: Method.get,
        uri: _resolveUri(path),
        headers: _mergeHeaders(headers),
        queryParameters: queryParameters ?? const {},
        recall: recall,
        receiveTimeout: receiveTimeout ?? this.receiveTimeout,
        responseType: ResponseType.bytes,
        onReceiveProgress: onProgress,
        extra: extra ?? const {},
      ),
    );
  }

  /// Sends a request and returns the response body as a byte stream.
  ///
  /// The returned [Dispatch.data] will be a [Stream<List<int>>] that
  /// you can pipe to a file or process incrementally.
  ///
  /// ```dart
  /// final dispatch = await envoy.stream('/files/large.zip');
  /// final stream = dispatch.data as Stream<List<int>>;
  /// final file = File('large.zip').openWrite();
  /// await stream.pipe(file);
  /// ```
  Future<Dispatch> stream(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Recall? recall,
    Duration? receiveTimeout,
    Map<String, Object?>? extra,
  }) {
    return send(
      Missive(
        method: Method.get,
        uri: _resolveUri(path),
        headers: _mergeHeaders(headers),
        queryParameters: queryParameters ?? const {},
        recall: recall,
        receiveTimeout: receiveTimeout ?? this.receiveTimeout,
        responseType: ResponseType.stream,
        extra: extra ?? const {},
      ),
    );
  }

  // ── Courier Management ───────────────────────────────────────────

  /// Adds a [Courier] to the interceptor chain.
  ///
  /// Couriers are called in the order they are added. The first courier
  /// added is the outermost (first to intercept requests, last to see
  /// responses).
  void addCourier(Courier courier) {
    _couriers.add(courier);
  }

  /// Removes a [Courier] from the interceptor chain.
  void removeCourier(Courier courier) {
    _couriers.remove(courier);
  }

  /// Removes all couriers from the chain.
  void clearCouriers() {
    _couriers.clear();
  }

  // ── Lifecycle ────────────────────────────────────────────────────

  /// Closes the HTTP client and releases resources.
  ///
  /// After calling [close], no new requests can be sent.
  /// Set [force] to `true` to abort in-flight requests immediately.
  void close({bool force = false}) {
    _closed = true;
    _transport?.close(force: force);
    _transport = null;
  }

  // ── Private ──────────────────────────────────────────────────────

  Uri _resolveUri(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    return Uri.parse('$baseUrl$path');
  }

  Map<String, String> _mergeHeaders(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) return Map.of(defaultHeaders);
    return {...defaultHeaders, ...headers};
  }

  /// Executes the actual HTTP request via the platform transport.
  Future<Dispatch> _executeRequest(Missive missive) async {
    final stopwatch = Stopwatch()..start();
    final uri = missive.resolvedUri;

    // Check cancellation before starting
    missive.recall?.throwIfCancelled(missive);

    try {
      // Prepare body bytes and content-type header
      final prepared = _prepareBody(missive);
      final requestHeaders = Map<String, String>.from(missive.headers);
      if (prepared.contentType != null &&
          !requestHeaders.containsKey('content-type')) {
        requestHeaders['content-type'] = prepared.contentType!;
      }

      // Send via platform transport (with cancellation support)
      final Future<TransportResponse> responseFuture = _activeTransport.send(
        method: missive.method.name.toUpperCase(),
        uri: uri,
        headers: requestHeaders,
        body: prepared.bodyBytes,
        followRedirects: missive.followRedirects,
        maxRedirects: missive.maxRedirects,
      );

      final TransportResponse response;
      if (missive.recall != null) {
        response = await Future.any<TransportResponse>([
          responseFuture,
          missive.recall!.whenCancelled.then<TransportResponse>((_) {
            throw EnvoyError.cancelled(missive: missive);
          }),
        ]);
      } else if (missive.receiveTimeout != null) {
        response = await responseFuture.timeout(
          missive.receiveTimeout!,
          onTimeout: () => throw TimeoutException(
            'Request timed out',
            missive.receiveTimeout,
          ),
        );
      } else {
        response = await responseFuture;
      }

      stopwatch.stop();

      // For stream response type, return bytes as a single-element stream
      if (missive.responseType == ResponseType.stream) {
        final stream = Stream.value(response.bodyBytes as List<int>);
        return Dispatch(
          statusCode: response.statusCode,
          data: stream,
          headers: response.headers,
          missive: missive,
          duration: stopwatch.elapsed,
        );
      }

      // Report receive progress
      missive.onReceiveProgress?.call(
        response.bodyBytes.length,
        response.bodyBytes.length,
      );

      // Parse response data
      final rawBody = _decodeBody(response.bodyBytes, missive.responseType);

      Object? data;
      try {
        data = _parseResponse(rawBody, missive.responseType);
      } catch (_) {
        data = rawBody;
      }

      final dispatch = Dispatch(
        statusCode: response.statusCode,
        data: data,
        rawBody: rawBody is String ? rawBody : '',
        headers: response.headers,
        missive: missive,
        duration: stopwatch.elapsed,
      );

      // Validate status
      final validator = missive.validateStatus ?? validateStatus ?? _isOk;
      if (!validator(response.statusCode)) {
        throw EnvoyError.badResponse(missive: missive, dispatch: dispatch);
      }

      return dispatch;
    } on EnvoyError {
      rethrow;
    } on TimeoutException catch (e, st) {
      stopwatch.stop();
      throw EnvoyError.timeout(missive: missive, error: e, stackTrace: st);
    } catch (e, st) {
      stopwatch.stop();
      if (_isCancellation(e)) {
        throw EnvoyError.cancelled(missive: missive);
      }
      // Catch connection errors (SocketException on IO, TypeError on web)
      throw EnvoyError.connectionError(
        missive: missive,
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Prepares the request body as bytes and determines content-type.
  _PreparedBody _prepareBody(Missive missive) {
    final data = missive.data;
    if (data == null) return const _PreparedBody();

    if (data is Parcel) {
      if (data.hasFiles) {
        final boundary = Parcel.generateBoundary();
        final body = data.buildMultipartBody(boundary);
        return _PreparedBody(
          bodyBytes: body is Uint8List ? body : Uint8List.fromList(body),
          contentType: 'multipart/form-data; boundary=$boundary',
        );
      } else {
        final encoded = data.toUrlEncoded();
        final bytes = utf8.encode(encoded);
        return _PreparedBody(
          bodyBytes: Uint8List.fromList(bytes),
          contentType: 'application/x-www-form-urlencoded',
        );
      }
    } else if (data is Uint8List) {
      return _PreparedBody(bodyBytes: data);
    } else if (data is Stream<List<int>>) {
      // Stream bodies are not supported via transport layer.
      // Collect to bytes (best effort).
      return const _PreparedBody();
    } else {
      final encoded = missive.encodedBody;
      if (encoded != null) {
        final contentType = (data is Map || data is List)
            ? 'application/json'
            : null;
        final bytes = utf8.encode(encoded);
        return _PreparedBody(
          bodyBytes: Uint8List.fromList(bytes),
          contentType: contentType,
        );
      }
    }

    return const _PreparedBody();
  }

  /// Decodes raw bytes to either [String] or [Uint8List] based on type.
  Object _decodeBody(Uint8List bytes, ResponseType responseType) {
    if (responseType == ResponseType.bytes) return bytes;
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Parses the raw response body according to [responseType].
  Object? _parseResponse(Object rawBody, ResponseType responseType) {
    if (responseType == ResponseType.bytes) return rawBody;
    final text = rawBody as String;
    return switch (responseType) {
      ResponseType.json => text.isEmpty ? null : jsonDecode(text),
      ResponseType.plain => text,
      ResponseType.bytes => rawBody,
      ResponseType.stream => null,
    };
  }

  bool _isCancellation(Object e) {
    if (e is EnvoyError && e.type == EnvoyErrorType.cancelled) return true;
    return e.toString().contains('Request recalled');
  }

  static bool _isOk(int status) => status >= 200 && status < 300;
}

/// Holds prepared body bytes and optional content-type header.
class _PreparedBody {
  const _PreparedBody({this.bodyBytes, this.contentType});

  /// The body as raw bytes, or null if no body.
  final Uint8List? bodyBytes;

  /// Content-type header value, or null if already set.
  final String? contentType;
}
