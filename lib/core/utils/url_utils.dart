import 'dart:io';

class UrlUtils {
  /// Converts localhost URLs to platform-appropriate URLs
  ///
  /// - Android Emulator: localhost -> 10.0.2.2
  /// - iOS Simulator: localhost -> localhost (works fine)
  /// - Physical Device: localhost -> actual IP (if configured)
  static String rewriteUrl(String url) {
    if (url.isEmpty) return url;

    // If it's already a platform-appropriate URL, return as-is
    if (!url.contains('localhost')) {
      return url;
    }

    // For Android emulator, replace localhost with 10.0.2.2
    if (Platform.isAndroid) {
      return url.replaceAll('localhost', '10.0.2.2');
    }

    // For iOS simulator and other platforms, localhost works fine
    return url;
  }

  /// Rewrite attachment URL for platform compatibility
  static String rewriteAttachmentUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return rewriteUrl(url);
  }

  /// Get platform-appropriate base URL
  static String getPlatformBaseUrl(String baseUrl) {
    return rewriteUrl(baseUrl);
  }
}
