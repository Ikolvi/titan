/// Platform-safe directory helpers for web and native.
///
/// On native platforms, uses `dart:io` [Directory] and [Platform].
/// On web, returns `null` since filesystem access is unavailable.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'platform_dirs_io.dart'
    if (dart.library.html) 'platform_dirs_web.dart'
    as platform;

/// Returns a temporary directory path for Shade recordings, or `null` on web.
String? getShadeDirectory() {
  if (kIsWeb) return null;
  return platform.getShadeDirectory();
}

/// Returns a user-accessible directory for exporting reports, or `null` on web.
String? getExportDirectory() {
  if (kIsWeb) return null;
  return platform.getExportDirectory();
}

/// Returns a temporary directory for blueprint exports, or `null` on web.
String? getBlueprintOutputDirectory() {
  if (kIsWeb) return null;
  return platform.getBlueprintOutputDirectory();
}

/// Creates a temporary directory and returns its path, or `null` on web.
String? createTempDirectory(String prefix) {
  if (kIsWeb) return null;
  return platform.createTempDirectory(prefix);
}

/// Writes Annals export to a temp file.
/// Returns the file path on success, or `null` on web/failure.
String? exportAnnalsToFile(void Function(StringSink sink) writer) {
  if (kIsWeb) return null;
  return platform.exportAnnalsToFile(writer);
}
