/// **EnvoyPin** — SSL/TLS certificate pinning configuration for [Envoy].
///
/// Holds pinning data (fingerprints, host override, self-signed flag).
/// The actual certificate validation is applied by the platform-specific
/// transport layer (IO only — browsers manage TLS natively).
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
  /// - [fingerprints]: SHA-1 certificate fingerprints.
  ///   Each entry should be a lowercase hex string of the SHA-1 hash
  ///   (40 hex chars, no colons).
  /// - [hostOverride]: Only pin for this specific host (null = pin all).
  /// - [allowSelfSigned]: Whether to allow self-signed certificates.
  ///   Use only for development/testing. Never enable in production.
  const EnvoyPin({
    this.fingerprints = const [],
    this.hostOverride,
    this.allowSelfSigned = false,
  });

  /// Allowed SHA-1 certificate fingerprints.
  final List<String> fingerprints;

  /// Only apply pinning to this specific host.
  ///
  /// If null, pinning applies to all hosts.
  final String? hostOverride;

  /// Whether to accept self-signed certificates.
  final bool allowSelfSigned;
}

/// **EnvoyProxy** — HTTP/HTTPS proxy configuration for [Envoy].
///
/// Holds proxy data (host, port, credentials). The actual proxy routing
/// is applied by the platform-specific transport layer (IO only — browsers
/// use system proxy settings).
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

  @override
  String toString() =>
      'EnvoyProxy($host:$port${username != null ? ' auth=$username' : ''})';
}
