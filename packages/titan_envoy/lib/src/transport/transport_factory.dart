import 'transport.dart';

export 'transport_stub.dart'
    if (dart.library.io) 'transport_io.dart'
    if (dart.library.js_interop) 'transport_web.dart';

/// Factory function signature for creating platform-specific transports.
///
/// This type is re-exported from the appropriate platform file via
/// conditional imports. See [transport_io.dart] and [transport_web.dart].
typedef TransportFactory =
    EnvoyTransport Function({
      Duration? connectTimeout,
      Object? pin,
      Object? proxy,
    });
