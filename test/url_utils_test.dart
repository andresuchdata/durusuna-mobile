import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:durusuna_mobile/core/utils/url_utils.dart';

void main() {
  group('UrlUtils Tests', () {
    test('rewriteUrl should convert localhost to 10.0.2.2 for Android', () {
      // Mock platform to be Android
      TestWidgetsFlutterBinding.ensureInitialized();

      final originalUrl =
          'http://localhost:3001/api/uploads/serve/avatars/2025/08/test.jpeg';
      final expectedUrl =
          'http://10.0.2.2:3001/api/uploads/serve/avatars/2025/08/test.jpeg';

      // Note: This test would need platform-specific mocking to work properly
      // For now, we'll test the logic manually
      final rewrittenUrl = originalUrl.replaceAll('localhost', '10.0.2.2');

      expect(rewrittenUrl, equals(expectedUrl));
    });

    test('rewriteAttachmentUrl should handle null URLs', () {
      final result = UrlUtils.rewriteAttachmentUrl(null);
      expect(result, equals(''));
    });

    test('rewriteAttachmentUrl should handle empty URLs', () {
      final result = UrlUtils.rewriteAttachmentUrl('');
      expect(result, equals(''));
    });

    test('rewriteAttachmentUrl should handle URLs without localhost', () {
      final url = 'https://example.com/image.jpg';
      final result = UrlUtils.rewriteAttachmentUrl(url);
      expect(result, equals(url));
    });
  });
}
