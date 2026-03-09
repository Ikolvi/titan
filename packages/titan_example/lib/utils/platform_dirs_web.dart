/// Web stub implementation of platform directory helpers.
///
/// All functions return `null` since web has no filesystem access.
library;

/// Returns `null` on web — no filesystem.
String? getShadeDirectory() => null;

/// Returns `null` on web — no filesystem.
String? getExportDirectory() => null;

/// Returns `null` on web — no filesystem.
String? getBlueprintOutputDirectory() => null;

/// Returns `null` on web — no filesystem.
String? createTempDirectory(String prefix) => null;

/// Returns `null` on web — no filesystem.
String? exportAnnalsToFile(void Function(StringSink sink) writer) => null;
