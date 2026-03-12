import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'transport.dart';

/// Creates a web-based [EnvoyTransport] using the browser `fetch()` API.
///
/// SSL pinning ([pin]) and proxy ([proxy]) are handled by the browser
/// and ignored here.
EnvoyTransport createTransport({
  Duration? connectTimeout,
  Object? pin,
  Object? proxy,
}) => WebEnvoyTransport(connectTimeout: connectTimeout);

/// Web-platform HTTP transport using the browser `fetch()` API.
///
/// Uses `dart:js_interop` to call the native `fetch()` function.
/// SSL pinning and proxy configuration are not applicable on web
/// (the browser manages TLS and proxy settings).
class WebEnvoyTransport extends EnvoyTransport {
  /// Creates a web transport.
  WebEnvoyTransport({this.connectTimeout});

  /// Timeout for the request.
  final Duration? connectTimeout;

  bool _closed = false;

  @override
  Future<TransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Uint8List? body,
    bool followRedirects = true,
    int maxRedirects = 5,
  }) async {
    if (_closed) throw StateError('Transport has been closed');

    // Build JS headers
    final jsHeaders = _JSHeaders();
    headers.forEach((key, value) {
      jsHeaders.set(key.toJS, value.toJS);
    });

    // Build request init
    final init = _createRequestInit(
      method: method.toJS,
      headers: jsHeaders,
      body: body?.toJS,
      redirect: followRedirects ? 'follow'.toJS : 'error'.toJS,
    );

    // Execute fetch with optional timeout
    final JSPromise<_JSResponse> fetchPromise = _jsFetch(
      uri.toString().toJS,
      init,
    );

    final _JSResponse response;
    if (connectTimeout != null) {
      response = await fetchPromise.toDart.timeout(
        connectTimeout!,
        onTimeout: () =>
            throw TimeoutException('Request timed out', connectTimeout),
      );
    } else {
      response = await fetchPromise.toDart;
    }

    // Read response body as bytes
    final jsArrayBuffer = await response.arrayBuffer().toDart;
    final bytes = jsArrayBuffer.toDart.asUint8List();

    // Extract response headers
    final responseHeaders = <String, String>{};
    _forEachHeader(response.headers, (String key, String value) {
      responseHeaders[key] = value;
    });

    return TransportResponse(
      statusCode: response.status,
      headers: responseHeaders,
      bodyBytes: bytes,
    );
  }

  @override
  void close({bool force = false}) {
    _closed = true;
  }
}

// ── JS Interop Bindings for fetch() ─────────────────────────────

@JS('fetch')
external JSPromise<_JSResponse> _jsFetch(JSString url, [JSObject? init]);

/// Creates a RequestInit object for the fetch() call.
///
/// We construct a plain JS object with the required properties
/// rather than using a typed extension type, for maximum compatibility.
_JSRequestInit _createRequestInit({
  required JSString method,
  required _JSHeaders headers,
  JSUint8Array? body,
  JSString? redirect,
}) {
  final init = _JSRequestInit();
  init.method = method;
  init.headers = headers;
  if (body != null) init.body = body;
  if (redirect != null) init.redirect = redirect;
  return init;
}

/// Minimal binding for the JavaScript `Headers` interface.
@JS('Headers')
extension type _JSHeaders._(JSObject _) implements JSObject {
  external factory _JSHeaders();

  /// Sets a header value.
  external void set(JSString name, JSString value);

  /// Gets a header value.
  external JSString? get(JSString name);

  /// Calls the JS forEach method on the Headers object.
  external void forEach(JSFunction callback);
}

/// Minimal binding for the JavaScript `Response` interface.
@JS('Response')
extension type _JSResponse._(JSObject _) implements JSObject {
  /// HTTP status code.
  external int get status;

  /// Whether the response was successful (status 200-299).
  external bool get ok;

  /// Response headers.
  external _JSHeaders get headers;

  /// Returns the response body as an ArrayBuffer promise.
  external JSPromise<JSArrayBuffer> arrayBuffer();

  /// Returns the response body as a text promise.
  external JSPromise<JSString> text();
}

/// Minimal binding for the JavaScript `RequestInit` dictionary.
extension type _JSRequestInit._(JSObject _) implements JSObject {
  /// Creates an empty RequestInit.
  _JSRequestInit() : _ = JSObject();

  /// The HTTP method.
  external set method(JSString value);

  /// The request headers.
  external set headers(JSObject value);

  /// The request body.
  external set body(JSAny? value);

  /// Redirect mode ('follow', 'error', 'manual').
  external set redirect(JSString value);
}

/// Iterates over JS Headers using forEach.
void _forEachHeader(
  _JSHeaders headers,
  void Function(String key, String value) callback,
) {
  // The JS Headers.forEach callback signature is (value, key, parent).
  // Note: value comes before key in JS's Headers.forEach.
  headers.forEach(
    ((JSString value, JSString key) {
      callback(key.toDart, value.toDart);
    }).toJS,
  );
}
