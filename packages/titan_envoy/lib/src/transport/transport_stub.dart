import 'transport.dart';

/// Creates a platform-appropriate [EnvoyTransport].
///
/// This stub is used when no platform implementation is available.
/// It should never be reached in practice — conditional imports
/// in [transport_factory.dart] select the IO or Web implementation.
EnvoyTransport createTransport({
  Duration? connectTimeout,
  Object? pin,
  Object? proxy,
}) => throw UnsupportedError(
  'Cannot create EnvoyTransport — '
  'no platform implementation available. '
  'Import from a platform that supports dart:io or dart:html.',
);
