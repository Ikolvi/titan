import 'dart:typed_data';

/// Raw HTTP response from the platform transport layer.
///
/// Contains the status code, response headers, and body as raw bytes.
/// Used by [Envoy] internally to build [Dispatch] objects.
class TransportResponse {
  /// Creates a transport response.
  const TransportResponse({
    required this.statusCode,
    required this.headers,
    required this.bodyBytes,
  });

  /// HTTP status code (e.g. 200, 404, 500).
  final int statusCode;

  /// Response headers as a flat key-value map.
  ///
  /// Multi-valued headers are joined with `, `.
  final Map<String, String> headers;

  /// Raw response body bytes.
  final Uint8List bodyBytes;
}

/// Platform-agnostic HTTP transport for Envoy.
///
/// Abstracts the low-level HTTP request/response cycle so Envoy
/// works identically on native (dart:io) and web (fetch API) platforms.
///
/// Implementations:
/// - **IO**: Uses [HttpClient] from `dart:io` with full support for
///   SSL pinning, proxies, redirects, and progress tracking.
/// - **Web**: Uses the browser `fetch()` API via `dart:js_interop`.
///   SSL pinning and proxy configuration are not applicable (handled
///   by the browser).
abstract class EnvoyTransport {
  /// Sends an HTTP request and returns the raw response.
  ///
  /// - [method]: HTTP method (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS).
  /// - [uri]: Fully resolved request URI.
  /// - [headers]: Request headers including content-type.
  /// - [body]: Optional request body as raw bytes.
  /// - [followRedirects]: Whether to follow HTTP redirects.
  /// - [maxRedirects]: Maximum number of redirect hops.
  Future<TransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Uint8List? body,
    bool followRedirects = true,
    int maxRedirects = 5,
  });

  /// Closes the transport and releases resources.
  ///
  /// After calling [close], no new requests can be sent.
  /// Set [force] to `true` to abort in-flight requests immediately.
  void close({bool force = false});
}
