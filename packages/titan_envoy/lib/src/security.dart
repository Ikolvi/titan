import 'dart:io';

/// **EnvoyPin** — SSL/TLS certificate pinning configuration for [Envoy].
///
/// Validates server certificates against known SHA-1 fingerprints
/// to prevent man-in-the-middle attacks. Uses the fingerprint
/// natively provided by Dart's [X509Certificate].
///
/// ```dart
/// final envoy = Envoy(
///   baseUrl: 'https://api.example.com',
///   pin: EnvoyPin(
///     fingerprints: [
///       'ab:cd:ef:12:34:56:78:90:ab:cd:ef:12:34:56:78:90:ab:cd:ef:12',
///     ],
///     allowSelfSigned: false,
///   ),
/// );
/// ```
class EnvoyPin {
  /// Creates a certificate pin configuration.
  ///
  /// - [fingerprints]: SHA-1 certificate fingerprints (colon-separated hex).
  ///   Dart's [X509Certificate.sha1] returns a `Uint8List` that is
  ///   formatted as `XX:XX:XX:...` for comparison.
  /// - [hostOverride]: Only pin for this specific host (null = pin all).
  /// - [allowSelfSigned]: Whether to allow self-signed certificates.
  const EnvoyPin({
    this.fingerprints = const [],
    this.hostOverride,
    this.allowSelfSigned = false,
  });

  /// Allowed SHA-1 certificate fingerprints.
  ///
  /// Each entry should be a lowercase hex string of the SHA-1 hash, e.g.
  /// `'a1b2c3d4e5f6...'` (40 hex chars, no colons).
  final List<String> fingerprints;

  /// Only apply pinning to this specific host.
  ///
  /// If null, pinning applies to all hosts.
  final String? hostOverride;

  /// Whether to accept self-signed certificates.
  ///
  /// Use only for development/testing. Never enable in production.
  final bool allowSelfSigned;

  /// Configures the [HttpClient] with this pin's certificate validation.
  void applyTo(HttpClient client) {
    if (allowSelfSigned) {
      client.badCertificateCallback = (cert, host, port) {
        if (hostOverride != null && host != hostOverride) return false;
        return true;
      };
      return;
    }

    if (fingerprints.isEmpty) return;

    client.badCertificateCallback = (cert, host, port) {
      if (hostOverride != null && host != hostOverride) return false;

      // Compare SHA-1 fingerprint from the certificate
      final sha1Bytes = cert.sha1;
      final fingerprint = sha1Bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      return fingerprints.contains(fingerprint);
    };
  }
}

/// **EnvoyProxy** — HTTP/HTTPS proxy configuration for [Envoy].
///
/// ```dart
/// final envoy = Envoy(
///   baseUrl: 'https://api.example.com',
///   proxy: EnvoyProxy(
///     host: 'proxy.corporate.com',
///     port: 8080,
///     username: 'user',
///     password: 'pass',
///   ),
/// );
/// ```
class EnvoyProxy {
  /// Creates a proxy configuration.
  ///
  /// - [host]: Proxy server hostname.
  /// - [port]: Proxy server port.
  /// - [username]: Optional proxy authentication username.
  /// - [password]: Optional proxy authentication password.
  /// - [bypass]: List of hostnames that should bypass the proxy.
  const EnvoyProxy({
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.bypass = const [],
  });

  /// Proxy server hostname.
  final String host;

  /// Proxy server port.
  final int port;

  /// Proxy authentication username.
  final String? username;

  /// Proxy authentication password.
  final String? password;

  /// Hostnames that bypass the proxy.
  final List<String> bypass;

  /// Configures the [HttpClient] with this proxy.
  void applyTo(HttpClient client) {
    client.findProxy = (uri) {
      if (bypass.any((b) => uri.host.endsWith(b))) {
        return 'DIRECT';
      }
      return 'PROXY $host:$port';
    };

    if (username != null && password != null) {
      client.addProxyCredentials(
        host,
        port,
        'Basic',
        HttpClientBasicCredentials(username!, password!),
      );
    }
  }

  @override
  String toString() =>
      'EnvoyProxy($host:$port${username != null ? ' auth=$username' : ''})';
}
