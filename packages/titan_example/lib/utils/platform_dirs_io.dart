/// Native (dart:io) implementation of platform directory helpers.
library;

import 'dart:io';

/// Returns the Shade storage directory path.
String getShadeDirectory() {
  return '${Directory.systemTemp.path}/questboard_shade';
}

/// Returns a user-accessible export directory path.
String getExportDirectory() {
  try {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null) {
      final downloads = '$home/Downloads/colossus_reports';
      Directory(downloads).createSync(recursive: true);
      return downloads;
    }
  } catch (_) {
    // Fall back to temp
  }
  return '${Directory.systemTemp.path}/colossus_reports';
}

/// Returns a temporary directory for blueprint exports.
String getBlueprintOutputDirectory() {
  return '${Directory.systemTemp.path}/questboard_blueprint';
}

/// Creates a temporary directory and returns its path.
String createTempDirectory(String prefix) {
  return Directory.systemTemp.createTempSync(prefix).path;
}

/// Writes Annals export to a file in a temp directory.
/// Returns the file path on success, or `null` on failure.
String? exportAnnalsToFile(void Function(StringSink sink) writer) {
  try {
    final dir = Directory.systemTemp.createTempSync('annals_');
    final file = File('${dir.path}/annals.json');
    final sink = file.openWrite();
    writer(sink);
    sink.close();
    return file.path;
  } catch (_) {
    return null;
  }
}
