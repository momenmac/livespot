// This stub file is used when not running on web

/// Stub implementation of downloadFile
Future<bool> downloadFileImpl({
  required String url,
  required String filename,
}) async {
  // This won't actually be called on mobile platforms,
  // but is needed for compilation
  return false;
}

/// Stub implementation of openUrl
Future<bool> openUrlImpl(String url) async {
  // This won't actually be called on mobile platforms,
  // but is needed for compilation
  return false;
}
