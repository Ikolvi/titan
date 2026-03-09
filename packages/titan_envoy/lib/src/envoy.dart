import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'courier.dart';
import 'dispatch.dart';
import 'envoy_error.dart';
import 'missive.dart';
import 'parcel.dart';
import 'recall.dart';
import 'security.dart';

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
  HttpClient? _httpClient;
  bool _closed = false;

  /// The registered [Courier] interceptors.
  List<Courier> get couriers => List.unmodifiable(_couriers);

  HttpClient get _client {
    if (_closed) throw StateError('Envoy has been closed');
    if (_httpClient == null) {
      _httpClient = HttpClient()..connectionTimeout = connectTimeout;
      pin?.applyTo(_httpClient!);
      proxy?.applyTo(_httpClient!);
    }
    return _httpClient!;
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
    _httpClient?.close(force: force);
    _httpClient = null;
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

  /// Executes the actual HTTP request using dart:io [HttpClient].
  Future<Dispatch> _executeRequest(Missive missive) async {
    final stopwatch = Stopwatch()..start();
    final uri = missive.resolvedUri;

    // Check cancellation before starting
    missive.recall?.throwIfCancelled(missive);

    try {
      final request = await _openRequest(uri, missive);

      // Set headers
      missive.headers.forEach((key, value) {
        request.headers.set(key, value);
      });

      // Set follow redirects
      request.followRedirects = missive.followRedirects;
      request.maxRedirects = missive.maxRedirects;

      // Write body
      await _writeBody(request, missive);

      // Send request (with cancellation support)
      final HttpClientResponse response;
      if (missive.recall != null) {
        response = await _sendWithCancellation(request, missive);
      } else {
        response = await _applyTimeout(
          request.close(),
          missive.receiveTimeout,
          missive,
        );
      }

      // For stream response type, return the stream directly
      if (missive.responseType == ResponseType.stream) {
        stopwatch.stop();

        // Build response headers map
        final responseHeaders = <String, String>{};
        response.headers.forEach((name, values) {
          responseHeaders[name] = values.join(', ');
        });

        // Wrap with cancellation support if recall
        Stream<List<int>> bodyStream = response;
        if (missive.recall != null) {
          final controller = StreamController<List<int>>();
          StreamSubscription<List<int>>? sub;
          sub = response.listen(
            controller.add,
            onDone: controller.close,
            onError: controller.addError,
          );
          missive.recall!.whenCancelled.then((_) {
            sub?.cancel();
            if (!controller.isClosed) {
              controller.addError(EnvoyError.cancelled(missive: missive));
              controller.close();
            }
          });
          bodyStream = controller.stream;
        }

        return Dispatch(
          statusCode: response.statusCode,
          data: bodyStream,
          headers: responseHeaders,
          missive: missive,
          duration: stopwatch.elapsed,
        );
      }

      // Read response body with progress
      final rawBody = await _readResponse(response, missive);
      stopwatch.stop();

      // Build response headers map
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(', ');
      });

      // Parse response data (gracefully handle parse errors)
      Object? data;
      try {
        data = _parseResponse(rawBody, missive.responseType, response);
      } catch (_) {
        // If parsing fails on a non‑success status, we still want
        // to report badResponse rather than parseError.
        data = rawBody;
      }

      final dispatch = Dispatch(
        statusCode: response.statusCode,
        data: data,
        rawBody: rawBody is String ? rawBody : '',
        headers: responseHeaders,
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
    } on SocketException catch (e, st) {
      stopwatch.stop();
      throw EnvoyError.connectionError(
        missive: missive,
        error: e,
        stackTrace: st,
      );
    } on HttpException catch (e, st) {
      stopwatch.stop();
      throw EnvoyError.connectionError(
        missive: missive,
        error: e,
        stackTrace: st,
      );
    } on TimeoutException catch (e, st) {
      stopwatch.stop();
      throw EnvoyError.timeout(missive: missive, error: e, stackTrace: st);
    } catch (e, st) {
      stopwatch.stop();
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

  Future<HttpClientRequest> _openRequest(Uri uri, Missive missive) async {
    final Future<HttpClientRequest> request;
    switch (missive.method) {
      case Method.get:
        request = _client.getUrl(uri);
      case Method.post:
        request = _client.postUrl(uri);
      case Method.put:
        request = _client.putUrl(uri);
      case Method.delete:
        request = _client.deleteUrl(uri);
      case Method.patch:
        request = _client.patchUrl(uri);
      case Method.head:
        request = _client.headUrl(uri);
      case Method.options:
        request = _client.openUrl('OPTIONS', uri);
    }
    return _applyTimeout(request, connectTimeout, missive);
  }

  Future<void> _writeBody(HttpClientRequest request, Missive missive) async {
    final data = missive.data;
    if (data == null) return;

    if (data is Parcel) {
      if (data.hasFiles) {
        final boundary = Parcel.generateBoundary();
        request.headers.contentType = ContentType(
          'multipart',
          'form-data',
          parameters: {'boundary': boundary},
        );
        final body = data.buildMultipartBody(boundary);
        request.contentLength = body.length;
        _writeWithProgress(request, body, missive.onSendProgress);
      } else {
        request.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
        );
        final encoded = data.toUrlEncoded();
        final bytes = utf8.encode(encoded);
        request.contentLength = bytes.length;
        _writeWithProgress(request, bytes, missive.onSendProgress);
      }
    } else if (data is Stream<List<int>>) {
      // Stream body — pipe directly
      await data.forEach(request.add);
    } else if (data is Uint8List) {
      request.contentLength = data.length;
      _writeWithProgress(request, data, missive.onSendProgress);
    } else {
      final encoded = missive.encodedBody;
      if (encoded != null) {
        if (!missive.headers.containsKey('content-type') &&
            (data is Map || data is List)) {
          request.headers.contentType = ContentType.json;
        }
        final bytes = utf8.encode(encoded);
        request.contentLength = bytes.length;
        _writeWithProgress(request, bytes, missive.onSendProgress);
      }
    }
  }

  void _writeWithProgress(
    HttpClientRequest request,
    List<int> bytes,
    void Function(int sent, int total)? onProgress,
  ) {
    if (onProgress == null) {
      request.add(bytes);
      return;
    }

    // Report progress in chunks for large bodies
    const chunkSize = 8192;
    final total = bytes.length;
    var sent = 0;

    while (sent < total) {
      final end = (sent + chunkSize).clamp(0, total);
      request.add(bytes.sublist(sent, end));
      sent = end;
      onProgress(sent, total);
    }
  }

  Future<HttpClientResponse> _sendWithCancellation(
    HttpClientRequest request,
    Missive missive,
  ) async {
    final recall = missive.recall!;
    final responseFuture = request.close();

    final result = await Future.any<HttpClientResponse>([
      responseFuture,
      recall.whenCancelled.then<HttpClientResponse>((_) {
        request.abort();
        throw EnvoyError.cancelled(missive: missive);
      }),
    ]);

    return result;
  }

  /// Reads the response body, supporting progress tracking.
  ///
  /// For [ResponseType.bytes], collects raw bytes with progress.
  /// For other types, decodes to a string with progress.
  Future<Object> _readResponse(
    HttpClientResponse response,
    Missive missive,
  ) async {
    final total = response.contentLength;
    final onProgress = missive.onReceiveProgress;

    if (missive.responseType == ResponseType.bytes) {
      // Collect raw bytes with progress
      final completer = Completer<Uint8List>();
      final chunks = <List<int>>[];
      var received = 0;

      final subscription = response.listen(
        (chunk) {
          chunks.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        },
        onDone: () {
          final bytes = Uint8List(received);
          var offset = 0;
          for (final chunk in chunks) {
            bytes.setRange(offset, offset + chunk.length, chunk);
            offset += chunk.length;
          }
          completer.complete(bytes);
        },
        onError: (Object e, StackTrace st) {
          if (!completer.isCompleted) completer.completeError(e, st);
        },
      );

      if (missive.recall != null) {
        missive.recall!.whenCancelled.then((_) {
          subscription.cancel();
          if (!completer.isCompleted) {
            completer.completeError(EnvoyError.cancelled(missive: missive));
          }
        });
      }

      return completer.future;
    }

    // Text-based response (json / plain)
    final completer = Completer<String>();
    final body = StringBuffer();
    var received = 0;

    final subscription = response.listen(
      (chunk) {
        received += chunk.length;
        body.write(utf8.decode(chunk, allowMalformed: true));
        onProgress?.call(received, total);
      },
      onDone: () => completer.complete(body.toString()),
      onError: (Object e, StackTrace st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      },
    );

    if (missive.recall != null) {
      missive.recall!.whenCancelled.then((_) {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.completeError(EnvoyError.cancelled(missive: missive));
        }
      });
    }

    return completer.future;
  }

  /// Parses the raw response body according to [responseType].
  Object? _parseResponse(
    Object rawBody,
    ResponseType responseType,
    HttpClientResponse response,
  ) {
    if (responseType == ResponseType.bytes) return rawBody;
    final text = rawBody as String;
    return switch (responseType) {
      ResponseType.json => text.isEmpty ? null : jsonDecode(text),
      ResponseType.plain => text,
      ResponseType.bytes => rawBody, // already handled above
      ResponseType.stream => null, // stream handled before _readResponse
    };
  }

  Future<T> _applyTimeout<T>(
    Future<T> future,
    Duration? timeout,
    Missive missive,
  ) {
    if (timeout == null) return future;
    return future.timeout(
      timeout,
      onTimeout: () => throw TimeoutException('Request timed out', timeout),
    );
  }

  bool _isCancellation(Object e) {
    if (e is EnvoyError && e.type == EnvoyErrorType.cancelled) return true;
    return e.toString().contains('Request recalled');
  }

  static bool _isOk(int status) => status >= 200 && status < 300;
}
