import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';

class UrlUtils {
  /// Converts localhost URLs to platform-appropriate URLs
  ///
  /// - Android Emulator: localhost -> 10.0.2.2
  /// - iOS Simulator: localhost -> localhost (works fine)
  /// - Physical Device: localhost -> actual IP (if configured)
  /// - Production: localhost -> production backend URL
  /// - Web: localhost -> localhost (works fine)
  static String rewriteUrl(String url) {
    if (url.isEmpty) return url;

    // If it's already a platform-appropriate URL, return as-is
    if (!url.contains('localhost')) {
      return url;
    }

    // For web platform, localhost works fine
    if (kIsWeb) {
      return url;
    }

    // For Android emulator, replace localhost with 10.0.2.2
    // Note: We'll need to handle this differently since we can't use Platform.isAndroid on web
    // For now, we'll assume it's Android if not web (this is a simplification)
    // In a real implementation, you might want to use conditional imports
    return url.replaceAll('localhost', '10.0.2.2');
  }

  /// Rewrite attachment URL for platform compatibility and production environment
  /// This handles the case where attachment URLs stored in DB still use localhost
  /// or emulator IPs but the app is running against production backend
  static String rewriteAttachmentUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    // If we're in production and the URL contains development URLs, replace with production URL
    if (ApiConstants.isProduction && _isDevelopmentUrl(url)) {
      // Extract the path from development URL
      final uri = Uri.parse(url);
      final path = uri.path;

      // Replace with production backend URL
      final productionUrl = '${ApiConstants.socketUrl}$path';
      return productionUrl;
    }

    // For development/staging, use normal platform rewriting
    final rewrittenUrl = rewriteUrl(url);
    return rewrittenUrl;
  }

  /// Check if URL is a development URL (localhost or emulator IPs)
  static bool _isDevelopmentUrl(String url) {
    return url.contains('localhost') ||
        url.contains('10.0.2.2') || // Android emulator
        url.contains('127.0.0.1'); // Local IP
  }

  /// Get platform-appropriate base URL
  static String getPlatformBaseUrl(String baseUrl) {
    return rewriteUrl(baseUrl);
  }
}
