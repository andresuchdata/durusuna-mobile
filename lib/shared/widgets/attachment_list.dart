import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_theme.dart';
import 'attachment_preview.dart';

class AttachmentList extends StatelessWidget {
  final List<Map<String, dynamic>> attachments;
  final AttachmentListMode mode;
  final bool showHeader;
  final String? headerTitle;
  final int? maxItems;
  final VoidCallback? onMoreTap;

  const AttachmentList({
    super.key,
    required this.attachments,
    this.mode = AttachmentListMode.vertical,
    this.showHeader = true,
    this.headerTitle,
    this.maxItems,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    final displayAttachments =
        maxItems != null && attachments.length > maxItems!
            ? attachments.take(maxItems!).toList()
            : attachments;

    final hasMore = maxItems != null && attachments.length > maxItems!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) _buildHeader(context, hasMore),
        _buildAttachmentsList(displayAttachments, hasMore),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool hasMore) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.attach_file,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            headerTitle ?? 'Attachments',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '(${attachments.length})',
            style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 12,
            ),
          ),
          if (hasMore) ...[
            const Spacer(),
            GestureDetector(
              onTap: onMoreTap,
              child: const Text(
                'View all',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentsList(
      List<Map<String, dynamic>> displayAttachments, bool hasMore) {
    switch (mode) {
      case AttachmentListMode.vertical:
        return _buildVerticalList(displayAttachments, hasMore);
      case AttachmentListMode.horizontal:
        return _buildHorizontalList(displayAttachments, hasMore);
      case AttachmentListMode.grid:
        return _buildGridList(displayAttachments, hasMore);
      case AttachmentListMode.compact:
        return _buildCompactList(displayAttachments, hasMore);
    }
  }

  Widget _buildVerticalList(
      List<Map<String, dynamic>> displayAttachments, bool hasMore) {
    return Column(
      children: [
        ...displayAttachments.map((attachment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildAttachmentPreview(
                  attachment, AttachmentPreviewMode.list),
            )),
        if (hasMore) _buildMoreIndicator(),
      ],
    );
  }

  Widget _buildHorizontalList(
      List<Map<String, dynamic>> displayAttachments, bool hasMore) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: displayAttachments.length + (hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == displayAttachments.length && hasMore) {
            return _buildMoreIndicator();
          }
          return _buildAttachmentPreview(
            displayAttachments[index],
            AttachmentPreviewMode.grid,
          );
        },
      ),
    );
  }

  Widget _buildGridList(
      List<Map<String, dynamic>> displayAttachments, bool hasMore) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...displayAttachments.map(
          (attachment) =>
              _buildAttachmentPreview(attachment, AttachmentPreviewMode.grid),
        ),
        if (hasMore) _buildMoreIndicator(),
      ],
    );
  }

  Widget _buildCompactList(
      List<Map<String, dynamic>> displayAttachments, bool hasMore) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...displayAttachments.map(
          (attachment) => _buildAttachmentPreview(
              attachment, AttachmentPreviewMode.compact),
        ),
        if (hasMore) _buildMoreIndicator(isCompact: true),
      ],
    );
  }

  Widget _buildAttachmentPreview(
      Map<String, dynamic> attachment, AttachmentPreviewMode previewMode) {
    return AttachmentPreview(
      fileName:
          attachment['fileName'] ?? attachment['filename'] ?? 'Unknown File',
      fileType: attachment['mimeType'] ??
          attachment['fileType'] ??
          'application/octet-stream',
      fileSize: attachment['size'] ?? attachment['fileSize'] ?? 0,
      fileUrl: attachment['url'] ?? attachment['fileUrl'],
      mode: previewMode,
      onTap: () => _handleAttachmentTap(attachment),
    );
  }

  Widget _buildMoreIndicator({bool isCompact = false}) {
    final remainingCount = attachments.length - (maxItems ?? 0);

    if (isCompact) {
      return GestureDetector(
        onTap: onMoreTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          ),
          child: Text(
            '+$remainingCount more',
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onMoreTap,
      child: Container(
        width: mode == AttachmentListMode.horizontal ? 120 : null,
        height: mode == AttachmentListMode.horizontal ? 120 : 48,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.more_horiz,
              color: AppTheme.primaryColor,
              size: mode == AttachmentListMode.horizontal ? 24 : 20,
            ),
            if (mode == AttachmentListMode.horizontal) ...[
              const SizedBox(height: 4),
              Text(
                '+$remainingCount more',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const SizedBox(width: 8),
              Text(
                '$remainingCount more attachments',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleAttachmentTap(Map<String, dynamic> attachment) async {
    final fileUrl = (attachment['url'] ?? attachment['fileUrl']) as String?;
    final fileName = (attachment['fileName'] ??
        attachment['filename'] ??
        'Unknown File') as String;
    final mimeType = (attachment['mimeType'] ??
        attachment['fileType'] ??
        'application/octet-stream') as String;

    if (fileUrl == null || fileUrl.isEmpty) {
      debugPrint('File URL not available for: $fileName');
      return;
    }

    try {
      // Handle different URL formats
      String downloadUrl = fileUrl;

      // If it's a relative URL, make it absolute
      if (fileUrl.startsWith('/')) {
        downloadUrl = 'http://localhost:3001$fileUrl';
      } else if (!fileUrl.startsWith('http')) {
        downloadUrl = 'http://localhost:3001/api/uploads/serve/$fileUrl';
      }

      debugPrint('Attempting to open: $downloadUrl');

      // Try to open the file
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('Successfully opened: $fileName');
      } else {
        debugPrint('Unable to open file: $fileName at $downloadUrl');
      }
    } catch (e) {
      debugPrint('Error opening attachment $fileName: $e');
    }
  }
}

enum AttachmentListMode {
  vertical, // Stacked vertically, full width
  horizontal, // Scrollable horizontal list
  grid, // Wrapped grid layout
  compact, // Inline chips/tags
}
