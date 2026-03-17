import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// Sentinel — Silent HTTP Interception
// ---------------------------------------------------------------------------

/// A complete HTTP transaction record captured by [Sentinel].
///
/// Contains request method, URL, headers, body, response status,
/// timing information, and outcome. Each record represents a single
/// HTTP round-trip observed by the [_SentinelHttpClient] wrapper.
///
/// ```dart
/// final records = Colossus.instance.sentinelRecords;
/// for (final r in records) {
///   print('${r.method} ${r.url} → ${r.statusCode} (${r.duration.inMilliseconds}ms)');
/// }
/// ```
class SentinelRecord {
  /// Unique request ID for correlation.
  final String id;

  /// HTTP method (GET, POST, PUT, DELETE, etc.).
  final String method;

  /// Full request URL including query parameters.
  final Uri url;

  /// When the request was initiated.
  final DateTime timestamp;

  /// Total round-trip duration.
  final Duration duration;

  // ── Request ──

  /// Request headers (name → value list).
  final Map<String, List<String>> requestHeaders;

  /// Request body bytes (null for GET/HEAD, capped at [SentinelConfig.maxBodyCapture]).
  final List<int>? requestBody;

  /// Request body size in bytes (always accurate, even if body is capped).
  final int requestSize;

  /// Detected request content type.
  final String? requestContentType;

  // ── Response ──

  /// HTTP response status code (null if connection failed).
  final int? statusCode;

  /// Response headers.
  final Map<String, List<String>>? responseHeaders;

  /// Response body bytes (capped at [SentinelConfig.maxBodyCapture]).
  final List<int>? responseBody;

  /// Response body size in bytes.
  final int? responseSize;

  /// Detected response content type.
  final String? responseContentType;

  // ── Outcome ──

  /// Whether the request was successful (2xx status).
  final bool success;

  /// Error message if the request failed.
  final String? error;

  /// Creates a [SentinelRecord].
  const SentinelRecord({
    required this.id,
    required this.method,
    required this.url,
    required this.timestamp,
    required this.duration,
    this.requestHeaders = const {},
    this.requestBody,
    this.requestSize = 0,
    this.requestContentType,
    this.statusCode,
    this.responseHeaders,
    this.responseBody,
    this.responseSize,
    this.responseContentType,
    this.success = false,
    this.error,
  });

  /// Convert to the existing Colossus API metric format.
  Map<String, dynamic> toMetricJson() => {
    'method': method,
    'url': url.toString(),
    'statusCode': statusCode,
    'durationMs': duration.inMilliseconds,
    'success': success,
    'error': error,
    'requestSize': requestSize,
    'responseSize': responseSize,
    'source': 'sentinel',
    'timestamp': timestamp.toIso8601String(),
  };

  /// Full record with request/response details.
  Map<String, dynamic> toDetailJson() => {
    ...toMetricJson(),
    'id': id,
    'requestHeaders': requestHeaders,
    'requestBody': requestBody != null ? _tryDecodeUtf8(requestBody!) : null,
    'requestContentType': requestContentType,
    'responseHeaders': responseHeaders,
    'responseBody': responseBody != null ? _tryDecodeUtf8(responseBody!) : null,
    'responseContentType': responseContentType,
  };

  static String? _tryDecodeUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return '<binary ${bytes.length} bytes>';
    }
  }
}

// ---------------------------------------------------------------------------
// SentinelConfig
// ---------------------------------------------------------------------------

/// Configuration for [Sentinel] HTTP interception.
///
/// ```dart
/// Colossus.init(
///   sentinelConfig: SentinelConfig(
///     excludePatterns: [r'localhost:864\d'],
///     maxBodyCapture: 64 * 1024,
///   ),
/// );
/// ```
class SentinelConfig {
  /// Maximum body size to capture (bytes). Default: 64 KB.
  final int maxBodyCapture;

  /// URL patterns to exclude from capture (regex strings).
  final List<String> excludePatterns;

  /// URL patterns to include (if set, only matching URLs are captured).
  final List<String>? includePatterns;

  /// Whether to capture request bodies. Default: true.
  final bool captureRequestBody;

  /// Whether to capture response bodies. Default: true.
  final bool captureResponseBody;

  /// Whether to capture headers. Default: true.
  final bool captureHeaders;

  /// Maximum records to retain in memory. Default: 500.
  final int maxRecords;

  /// Creates a [SentinelConfig].
  const SentinelConfig({
    this.maxBodyCapture = 64 * 1024,
    this.excludePatterns = const [],
    this.includePatterns,
    this.captureRequestBody = true,
    this.captureResponseBody = true,
    this.captureHeaders = true,
    this.maxRecords = 500,
  });
}

// ---------------------------------------------------------------------------
// Sentinel — Installer
// ---------------------------------------------------------------------------

/// **Sentinel** — the silent watcher that intercepts all HTTP traffic.
///
/// Installs an [HttpOverrides] wrapper around `dart:io`'s [HttpClient]
/// to capture every HTTP request and response — like Charles Proxy but
/// built into the app. Works with any HTTP client library (package:http,
/// dio, Envoy, raw HttpClient, etc.) because all Dart HTTP flows through
/// `dart:io` on native platforms.
///
/// ```dart
/// Sentinel.install(
///   config: SentinelConfig(maxBodyCapture: 32 * 1024),
///   onRecord: (record) {
///     print('${record.method} ${record.url} → ${record.statusCode}');
///   },
/// );
/// ```
class Sentinel {
  Sentinel._();

  static _SentinelHttpOverrides? _overrides;

  /// Whether Sentinel is currently installed.
  static bool get isInstalled => _overrides != null;

  /// Install Sentinel HTTP interception.
  ///
  /// Wraps the current [HttpOverrides] so existing overrides are preserved.
  /// Each completed HTTP transaction fires [onRecord] with the full
  /// [SentinelRecord].
  ///
  /// Set [chainPreviousOverrides] to `false` in test environments where
  /// the previous [HttpOverrides] blocks network access (e.g. Flutter test).
  static void install({
    SentinelConfig config = const SentinelConfig(),
    required void Function(SentinelRecord record) onRecord,
    bool chainPreviousOverrides = true,
  }) {
    if (_overrides != null) return; // Already installed

    final previous = chainPreviousOverrides ? HttpOverrides.current : null;
    _overrides = _SentinelHttpOverrides(
      previous: previous,
      config: config,
      onRecord: onRecord,
    );
    HttpOverrides.global = _overrides;
  }

  /// Uninstall Sentinel and restore the previous [HttpOverrides].
  static void uninstall() {
    if (_overrides == null) return;
    HttpOverrides.global = _overrides!._previous;
    _overrides = null;
  }

  /// Creates an [HttpClient] wrapped by Sentinel interception.
  ///
  /// Useful when zone-scoped [HttpOverrides] (e.g. in Flutter test)
  /// prevent the standard [HttpClient] constructor from using
  /// Sentinel's global override.
  ///
  /// Returns `null` if Sentinel is not installed.
  static HttpClient? createClient([SecurityContext? context]) {
    return _overrides?.createHttpClient(context);
  }
}

// ---------------------------------------------------------------------------
// HttpOverrides wrapper
// ---------------------------------------------------------------------------

class _SentinelHttpOverrides extends HttpOverrides {
  final HttpOverrides? _previous;
  final SentinelConfig _config;
  final void Function(SentinelRecord record) _onRecord;

  /// Compiled exclude patterns.
  late final List<RegExp> _excludeRegexes = _config.excludePatterns
      .map((p) => RegExp(p))
      .toList();

  /// Compiled include patterns.
  late final List<RegExp>? _includeRegexes = _config.includePatterns
      ?.map((p) => RegExp(p))
      .toList();

  _SentinelHttpOverrides({
    required HttpOverrides? previous,
    required SentinelConfig config,
    required void Function(SentinelRecord record) onRecord,
  }) : _previous = previous,
       _config = config,
       _onRecord = onRecord;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final inner = _previous != null
        ? _previous.createHttpClient(context)
        : super.createHttpClient(context);
    return _SentinelHttpClient(inner, _config, _onRecord, _shouldCapture);
  }

  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    if (_previous != null) {
      return _previous.findProxyFromEnvironment(url, environment);
    }
    return super.findProxyFromEnvironment(url, environment);
  }

  /// Whether the given URL should be captured (passes include/exclude filters).
  bool _shouldCapture(Uri url) {
    final urlStr = url.toString();

    // Check excludes
    for (final regex in _excludeRegexes) {
      if (regex.hasMatch(urlStr)) return false;
    }

    // Check includes (if set, URL must match at least one)
    final includes = _includeRegexes;
    if (includes != null && includes.isNotEmpty) {
      for (final regex in includes) {
        if (regex.hasMatch(urlStr)) return true;
      }
      return false;
    }

    return true;
  }
}

// ---------------------------------------------------------------------------
// HttpClient wrapper — THE ONLY 2 INTERCEPT POINTS: open() and openUrl()
// ---------------------------------------------------------------------------

class _SentinelHttpClient implements HttpClient {
  final HttpClient _inner;
  final SentinelConfig _config;
  final void Function(SentinelRecord record) _onRecord;
  final bool Function(Uri url) _shouldCapture;

  _SentinelHttpClient(
    this._inner,
    this._config,
    this._onRecord,
    this._shouldCapture,
  );

  int _requestCounter = 0;

  String _nextId() => 'sentinel-${_requestCounter++}';

  // ── Intercept points ──

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) async {
    final url = Uri(scheme: 'http', host: host, port: port, path: path);
    final request = await _inner.open(method, host, port, path);
    if (!_shouldCapture(url)) return request;
    return _SentinelRequest(
      request,
      method,
      url,
      _config,
      _onRecord,
      _nextId(),
    );
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final request = await _inner.openUrl(method, url);
    if (!_shouldCapture(url)) return request;
    return _SentinelRequest(
      request,
      method,
      url,
      _config,
      _onRecord,
      _nextId(),
    );
  }

  // ── Pure delegation — convenience methods ──

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      open('GET', host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      open('POST', host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      open('PUT', host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      open('DELETE', host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      open('HEAD', host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open('PATCH', host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  // ── Pure delegation — properties ──

  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  Duration get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;

  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? value) => _inner.userAgent = value;

  // ── Pure delegation — callbacks ──

  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? f,
  ) => _inner.authenticate = f;

  @override
  set authenticateProxy(
    Future<bool> Function(String host, int port, String scheme, String? realm)?
    f,
  ) => _inner.authenticateProxy = f;

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) => _inner.badCertificateCallback = callback;

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    )?
    f,
  ) => _inner.connectionFactory = f;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;

  // ── Lifecycle ──

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) => _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) => _inner.addProxyCredentials(host, port, realm, credentials);
}

// ---------------------------------------------------------------------------
// HttpClientRequest wrapper — captures request body, wraps response
// ---------------------------------------------------------------------------

class _SentinelRequest implements HttpClientRequest {
  final HttpClientRequest _inner;
  final String _method;
  final Uri _requestUrl;
  final SentinelConfig _config;
  final void Function(SentinelRecord record) _onRecord;
  final String _id;
  final Stopwatch _stopwatch = Stopwatch()..start();
  final List<int> _bodyBuffer = [];

  _SentinelRequest(
    this._inner,
    this._method,
    this._requestUrl,
    this._config,
    this._onRecord,
    this._id,
  );

  // ── Intercept body writes ──

  @override
  void add(List<int> data) {
    if (_config.captureRequestBody &&
        _bodyBuffer.length < _config.maxBodyCapture) {
      final remaining = _config.maxBodyCapture - _bodyBuffer.length;
      _bodyBuffer.addAll(
        data.length <= remaining ? data : data.sublist(0, remaining),
      );
    }
    _inner.add(data);
  }

  @override
  void write(Object? object) {
    final str = '$object';
    add(utf8.encode(str));
  }

  @override
  void writeln([Object? object = '']) {
    write('$object\n');
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    write(objects.join(separator));
  }

  @override
  void writeCharCode(int charCode) {
    add([charCode]);
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    if (!_config.captureRequestBody) {
      return _inner.addStream(stream);
    }
    final buffered = stream.map((data) {
      if (_bodyBuffer.length < _config.maxBodyCapture) {
        final remaining = _config.maxBodyCapture - _bodyBuffer.length;
        _bodyBuffer.addAll(
          data.length <= remaining ? data : data.sublist(0, remaining),
        );
      }
      return data;
    });
    return _inner.addStream(buffered);
  }

  // ── Intercept close — wrap the response ──

  @override
  Future<HttpClientResponse> close() async {
    final requestHeaders = _config.captureHeaders
        ? _captureHeaders(_inner.headers)
        : <String, List<String>>{};
    final requestContentType = _inner.headers.contentType?.toString();

    try {
      final response = await _inner.close();
      return _SentinelResponse(
        response,
        _config,
        _onRecord,
        id: _id,
        method: _method,
        url: _requestUrl,
        stopwatch: _stopwatch,
        requestHeaders: requestHeaders,
        requestBody: _config.captureRequestBody ? _bodyBuffer : null,
        requestSize: _bodyBuffer.length,
        requestContentType: requestContentType,
      );
    } catch (e) {
      _stopwatch.stop();
      _onRecord(
        SentinelRecord(
          id: _id,
          method: _method,
          url: _requestUrl,
          timestamp: DateTime.now().subtract(_stopwatch.elapsed),
          duration: _stopwatch.elapsed,
          requestHeaders: requestHeaders,
          requestBody: _config.captureRequestBody ? _bodyBuffer : null,
          requestSize: _bodyBuffer.length,
          requestContentType: requestContentType,
          error: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    _stopwatch.stop();
    _onRecord(
      SentinelRecord(
        id: _id,
        method: _method,
        url: _requestUrl,
        timestamp: DateTime.now().subtract(_stopwatch.elapsed),
        duration: _stopwatch.elapsed,
        error: exception?.toString() ?? 'Request aborted',
      ),
    );
    _inner.abort(exception, stackTrace);
  }

  // ── Pure delegation ──

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  int get contentLength => _inner.contentLength;
  @override
  set contentLength(int value) => _inner.contentLength = value;

  @override
  String get method => _inner.method;

  @override
  Uri get uri => _inner.uri;

  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  bool get persistentConnection => _inner.persistentConnection;
  @override
  set persistentConnection(bool value) => _inner.persistentConnection = value;

  @override
  bool get bufferOutput => _inner.bufferOutput;
  @override
  set bufferOutput(bool value) => _inner.bufferOutput = value;

  @override
  Encoding get encoding => _inner.encoding;
  @override
  set encoding(Encoding value) => _inner.encoding = value;

  @override
  bool get followRedirects => _inner.followRedirects;
  @override
  set followRedirects(bool value) => _inner.followRedirects = value;

  @override
  int get maxRedirects => _inner.maxRedirects;
  @override
  set maxRedirects(int value) => _inner.maxRedirects = value;

  @override
  Future<HttpClientResponse> get done => _inner.done;

  @override
  Future flush() => _inner.flush();

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _inner.addError(error, stackTrace);
  }

  static Map<String, List<String>> _captureHeaders(HttpHeaders headers) {
    final map = <String, List<String>>{};
    headers.forEach((name, values) {
      map[name] = List<String>.from(values);
    });
    return map;
  }
}

// ---------------------------------------------------------------------------
// HttpClientResponse wrapper — captures response body on stream completion
// ---------------------------------------------------------------------------

class _SentinelResponse extends Stream<List<int>>
    implements HttpClientResponse {
  final HttpClientResponse _inner;
  final SentinelConfig _config;
  final void Function(SentinelRecord record) _onRecord;
  final String _id;
  final String _method;
  final Uri _url;
  final Stopwatch _stopwatch;
  final Map<String, List<String>> _requestHeaders;
  final List<int>? _requestBody;
  final int _requestSize;
  final String? _requestContentType;

  _SentinelResponse(
    this._inner,
    this._config,
    this._onRecord, {
    required String id,
    required String method,
    required Uri url,
    required Stopwatch stopwatch,
    required Map<String, List<String>> requestHeaders,
    required List<int>? requestBody,
    required int requestSize,
    required String? requestContentType,
  }) : _id = id,
       _method = method,
       _url = url,
       _stopwatch = stopwatch,
       _requestHeaders = requestHeaders,
       _requestBody = requestBody,
       _requestSize = requestSize,
       _requestContentType = requestContentType;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final buffer = <int>[];

    // Use StreamTransformer so our record fires in handleDone before
    // the subscription's onDone (which drain/asFuture may replace).
    final transformed = _inner.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (data, sink) {
          if (_config.captureResponseBody &&
              buffer.length < _config.maxBodyCapture) {
            final remaining = _config.maxBodyCapture - buffer.length;
            buffer.addAll(
              data.length <= remaining ? data : data.sublist(0, remaining),
            );
          }
          sink.add(data);
        },
        handleError: (Object error, StackTrace stackTrace, EventSink sink) {
          _stopwatch.stop();
          _onRecord(
            SentinelRecord(
              id: _id,
              method: _method,
              url: _url,
              timestamp: DateTime.now().subtract(_stopwatch.elapsed),
              duration: _stopwatch.elapsed,
              requestHeaders: _requestHeaders,
              requestBody: _requestBody,
              requestSize: _requestSize,
              requestContentType: _requestContentType,
              statusCode: _inner.statusCode,
              error: error.toString(),
            ),
          );
          sink.addError(error, stackTrace);
        },
        handleDone: (sink) {
          _stopwatch.stop();
          final responseHeaders = _config.captureHeaders
              ? _captureHeaders(_inner.headers)
              : <String, List<String>>{};

          _onRecord(
            SentinelRecord(
              id: _id,
              method: _method,
              url: _url,
              timestamp: DateTime.now().subtract(_stopwatch.elapsed),
              duration: _stopwatch.elapsed,
              requestHeaders: _requestHeaders,
              requestBody: _requestBody,
              requestSize: _requestSize,
              requestContentType: _requestContentType,
              statusCode: _inner.statusCode,
              responseHeaders: responseHeaders,
              responseBody: _config.captureResponseBody ? buffer : null,
              responseSize: buffer.length,
              responseContentType: _inner.headers.contentType?.toString(),
              success: _inner.statusCode >= 200 && _inner.statusCode < 300,
            ),
          );
          sink.close();
        },
      ),
    );

    return transformed.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  static Map<String, List<String>> _captureHeaders(HttpHeaders headers) {
    final map = <String, List<String>>{};
    headers.forEach((name, values) {
      map[name] = List<String>.from(values);
    });
    return map;
  }

  // ── Pure delegation ──

  @override
  int get statusCode => _inner.statusCode;

  @override
  String get reasonPhrase => _inner.reasonPhrase;

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  int get contentLength => _inner.contentLength;

  @override
  bool get isRedirect => _inner.isRedirect;

  @override
  List<RedirectInfo> get redirects => _inner.redirects;

  @override
  bool get persistentConnection => _inner.persistentConnection;

  @override
  X509Certificate? get certificate => _inner.certificate;

  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  HttpClientResponseCompressionState get compressionState =>
      _inner.compressionState;

  @override
  Future<Socket> detachSocket() => _inner.detachSocket();

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) => _inner.redirect(method, url, followLoops);
}
