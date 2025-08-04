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
    final rewrittenUrl = UrlUtils.rewriteAttachmentUrl(widget.imageUrl);

    final content = CachedNetworkImage(
      imageUrl: rewrittenUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      httpHeaders: _headers,
      placeholder: (context, url) {
        return widget.placeholder ??
            const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
      },
      errorWidget: (context, url, error) {
        debugPrint('Image load error: $error for URL: $url');

        // Try fallback without auth headers if initial request failed
        if (_authToken != null) {
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
              return widget.placeholder ??
                  const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
            },
            errorWidget: (context, url, error) {
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
