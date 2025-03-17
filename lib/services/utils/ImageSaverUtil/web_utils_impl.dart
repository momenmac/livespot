/// Default implementation for non-web platforms
/// This file should only contain code that can run on all platforms
class WebUtilsImpl {
  /// Stub implementation for non-web platforms
  static Future<bool> downloadFileImpl({
    required String url,
    required String filename,
  }) async {
    // This implementation is only used on non-web platforms
    // It should never be actually called
    print('Warning: Web download not supported on this platform');
    return false;
  }
}
