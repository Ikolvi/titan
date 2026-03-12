import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../security.dart';
import 'transport.dart';

/// Creates an IO-based [EnvoyTransport] using `dart:io` [HttpClient].
///
/// - [connectTimeout]: Timeout for establishing a connection.
/// - [pin]: Optional [EnvoyPin] for SSL certificate pinning.
/// - [proxy]: Optional [EnvoyProxy] for HTTP proxy configuration.
EnvoyTransport createTransport({
  Duration? connectTimeout,
  Object? pin,
  Object? proxy,
}) => IoEnvoyTransport(
  connectTimeout: connectTimeout,
  pin: pin as EnvoyPin?,
  proxy: proxy as EnvoyProxy?,
);

/// IO-platform HTTP transport using `dart:io` [HttpClient].
///
/// Supports all [HttpClient] features including SSL pinning,
/// proxy configuration, redirect following, and connection management.
class IoEnvoyTransport extends EnvoyTransport {
  /// Creates an IO transport.
  IoEnvoyTransport({this.connectTimeout, EnvoyPin? pin, EnvoyProxy? proxy})
    : _pin = pin,
      _proxy = proxy;

  /// Timeout for establishing a connection.
  final Duration? connectTimeout;

  final EnvoyPin? _pin;
  final EnvoyProxy? _proxy;
  HttpClient? _httpClient;
  bool _closed = false;

  /// Returns the underlying [HttpClient], creating it if needed.
  HttpClient get _client {
    if (_closed) throw StateError('Transport has been closed');
    if (_httpClient == null) {
      _httpClient = HttpClient()..connectionTimeout = connectTimeout;
      _applyPin();
      _applyProxy();
    }
    return _httpClient!;
  }

  void _applyPin() {
    final pin = _pin;
    if (pin == null) return;

    if (pin.allowSelfSigned) {
      _httpClient!.badCertificateCallback = (cert, host, port) {
        if (pin.hostOverride != null && host != pin.hostOverride) return false;
        return true;
      };
      return;
    }

    if (pin.fingerprints.isEmpty) return;

    _httpClient!.badCertificateCallback = (cert, host, port) {
      if (pin.hostOverride != null && host != pin.hostOverride) return false;
      final sha1Bytes = cert.sha1;
      final fingerprint = sha1Bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      return pin.fingerprints.contains(fingerprint);
    };
  }

  void _applyProxy() {
    final proxy = _proxy;
    if (proxy == null) return;

    _httpClient!.findProxy = (uri) {
      if (proxy.bypass.any((b) => uri.host.endsWith(b))) {
        return 'DIRECT';
      }
      return 'PROXY ${proxy.host}:${proxy.port}';
    };

    if (proxy.username != null && proxy.password != null) {
      _httpClient!.addProxyCredentials(
        proxy.host,
        proxy.port,
        'Basic',
        HttpClientBasicCredentials(proxy.username!, proxy.password!),
      );
    }
  }

  @override
  Future<TransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Uint8List? body,
    bool followRedirects = true,
    int maxRedirects = 5,
  }) async {
    final request = await _openRequest(method, uri);

    // Set headers
    headers.forEach((key, value) {
      request.headers.set(key, value);
    });

    // Configure redirects
    request.followRedirects = followRedirects;
    request.maxRedirects = maxRedirects;

    // Write body
    if (body != null) {
      request.contentLength = body.length;
      request.add(body);
    }

    // Send and receive response
    final response = await request.close();

    // Read response body
    final chunks = <List<int>>[];
    await response.listen((chunk) => chunks.add(chunk)).asFuture<void>();

    final totalLength = chunks.fold<int>(0, (sum, c) => sum + c.length);
    final bytes = Uint8List(totalLength);
    var offset = 0;
    for (final chunk in chunks) {
      bytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    // Build response headers
    final responseHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      responseHeaders[name] = values.join(', ');
    });

    return TransportResponse(
      statusCode: response.statusCode,
      headers: responseHeaders,
      bodyBytes: bytes,
    );
  }

  Future<HttpClientRequest> _openRequest(String method, Uri uri) {
    return switch (method.toUpperCase()) {
      'GET' => _client.getUrl(uri),
      'POST' => _client.postUrl(uri),
      'PUT' => _client.putUrl(uri),
      'DELETE' => _client.deleteUrl(uri),
      'PATCH' => _client.patchUrl(uri),
      'HEAD' => _client.headUrl(uri),
      _ => _client.openUrl(method, uri),
    };
  }

  @override
  void close({bool force = false}) {
    _closed = true;
    _httpClient?.close(force: force);
    _httpClient = null;
  }
}
