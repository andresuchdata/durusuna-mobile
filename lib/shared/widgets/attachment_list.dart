import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';
import 'attachment_preview.dart';
import 'built_in_attachment_viewer.dart';
import 'media_viewer.dart';

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
          const Icon(
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
    return Builder(
      builder: (context) => AttachmentPreview(
        fileName:
            attachment['fileName'] ?? attachment['filename'] ?? 'Unknown File',
        fileType: attachment['mimeType'] ??
            attachment['fileType'] ??
            'application/octet-stream',
        fileSize: attachment['size'] ?? attachment['fileSize'] ?? 0,
        fileUrl: attachment['url'] ?? attachment['fileUrl'],
        mode: previewMode,
        onTap: () {
          _openAttachmentViewer(context, attachment);
        },
      ),
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
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
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
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
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

  void _openAttachmentViewer(
      BuildContext context, Map<String, dynamic> attachment) {
    // Check if it's a media file (image, video, audio) using boolean flags
    final isImage =
        attachment['isImage'] == true || attachment['is_image'] == true;
    final isVideo =
        attachment['isVideo'] == true || attachment['is_video'] == true;
    final isAudio =
        attachment['isAudio'] == true || attachment['is_audio'] == true;
    final isMediaFile = isImage || isVideo || isAudio;

    if (isMediaFile) {
      // Use MediaViewer for ALL media files (provides consistent immersive experience)
      final mediaAttachments = attachments.where((att) {
        final isImg = att['isImage'] == true || att['is_image'] == true;
        final isVid = att['isVideo'] == true || att['is_video'] == true;
        final isAud = att['isAudio'] == true || att['is_audio'] == true;
        return isImg || isVid || isAud;
      }).toList();

      final initialIndex = mediaAttachments.indexOf(attachment);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MediaViewer(
            attachments: mediaAttachments,
            initialIndex: initialIndex.clamp(0, mediaAttachments.length - 1),
            title: 'Media',
          ),
        ),
      );
    } else {
      // Use BuiltInAttachmentViewer for documents and other files
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BuiltInAttachmentViewer(
            attachment: attachment,
          ),
        ),
      );
    }
  }
}

enum AttachmentListMode {
  vertical, // Stacked vertically, full width
  horizontal, // Scrollable horizontal list
  grid, // Wrapped grid layout
  compact, // Inline chips/tags
}
