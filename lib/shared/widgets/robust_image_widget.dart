import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_theme.dart';
import '../../core/storage/storage_service.dart';
import '../../core/utils/url_utils.dart';

class RobustImageWidget extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const RobustImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<RobustImageWidget> createState() => _RobustImageWidgetState();
}

class _RobustImageWidgetState extends State<RobustImageWidget> {
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
  }

  Future<void> _loadAuthToken() async {
    final token = await StorageService.getToken();
    if (mounted) {
      setState(() {
        _authToken = token;
      });
    }
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Cache-Control': 'no-cache',
      'Accept': 'image/*',
    };

    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  @override
  Widget build(BuildContext context) {
    print('🖼️ RobustImageWidget.build()');
    print('🌐 Original URL: ${widget.imageUrl}');

    final rewrittenUrl = UrlUtils.rewriteAttachmentUrl(widget.imageUrl);
    print('🔄 Rewritten URL: $rewrittenUrl');
    print('🔑 Auth token available: ${_authToken != null}');
    print('📋 Headers: $_headers');

    final content = CachedNetworkImage(
      imageUrl: rewrittenUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      httpHeaders: _headers,
      placeholder: (context, url) {
        print('⏳ Loading image placeholder for: $url');
        return widget.placeholder ??
            const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
      },
      errorWidget: (context, url, error) {
        print('❌ Image load error: $error for URL: $url');
        debugPrint('Image load error: $error for URL: $url');

        // Try fallback without auth headers if initial request failed
        if (_authToken != null) {
          print('🔄 Trying fallback without auth headers');
          return CachedNetworkImage(
            imageUrl: rewrittenUrl,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            httpHeaders: const {
              'Cache-Control': 'no-cache',
              'Accept': 'image/*',
            },
            placeholder: (context, url) {
              print('⏳ Fallback placeholder for: $url');
              return widget.placeholder ??
                  const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
            },
            errorWidget: (context, url, error) {
              print('❌ Fallback image load also failed: $error');
              debugPrint('Fallback image load also failed: $error');
              return widget.errorWidget ??
                  const Icon(
                    Icons.broken_image,
                    color: AppTheme.textTertiary,
                    size: 32,
                  );
            },
          );
        }

        print('❌ No fallback available, showing error widget');
        return widget.errorWidget ??
            const Icon(
              Icons.broken_image,
              color: AppTheme.textTertiary,
              size: 32,
            );
      },
    );

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    return content;
  }
}
