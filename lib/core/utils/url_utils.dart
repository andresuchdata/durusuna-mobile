import 'dart:io';
import '../constants/api_constants.dart';

class UrlUtils {
  /// Converts localhost URLs to platform-appropriate URLs
  ///
  /// - Android Emulator: localhost -> 10.0.2.2
  /// - iOS Simulator: localhost -> localhost (works fine)
  /// - Physical Device: localhost -> actual IP (if configured)
  /// - Production: localhost -> production backend URL
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

  /// Rewrite attachment URL for platform compatibility and production environment
  /// This handles the case where attachment URLs stored in DB still use localhost
  /// but the app is running against production backend
  static String rewriteAttachmentUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    print('🔄 UrlUtils.rewriteAttachmentUrl()');
    print('🌐 Input URL: $url');
    print('🏭 Is production: ${ApiConstants.isProduction}');
    print('📡 Current base URL: ${ApiConstants.baseUrl}');

    // If we're in production and the URL contains localhost, replace it with production URL
    if (ApiConstants.isProduction && url.contains('localhost')) {
      // Extract the path from localhost URL
      final uri = Uri.parse(url);
      final path = uri.path;

      // Replace with production backend URL
      final productionUrl = '${ApiConstants.socketUrl}$path';
      print('🔄 Rewriting localhost to production: $productionUrl');
      return productionUrl;
    }

    // For development/staging, use normal platform rewriting
    final rewrittenUrl = rewriteUrl(url);
    print('🔄 Platform rewritten URL: $rewrittenUrl');
    return rewrittenUrl;
  }

  /// Get platform-appropriate base URL
  static String getPlatformBaseUrl(String baseUrl) {
    return rewriteUrl(baseUrl);
  }
}
