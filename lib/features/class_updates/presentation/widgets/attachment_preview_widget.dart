import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/attachment.dart';
import '../../../../shared/widgets/robust_image_widget.dart';
import '../../../../shared/widgets/built_in_attachment_viewer.dart';
import '../../../../shared/widgets/attachment_viewer_page.dart';

class AttachmentPreviewWidget extends StatelessWidget {
  final List<Attachment> attachments;
  final bool isCompact;
  final bool showTitle;
  final VoidCallback? onTap;

  const AttachmentPreviewWidget({
    super.key,
    required this.attachments,
    this.isCompact = false,
    this.showTitle = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Row(
            children: [
              const Icon(
                Icons.attach_file,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                '${attachments.length} attachment${attachments.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (isCompact) _buildCompactView(context) else _buildFullView(context),
      ],
    );
  }

  Widget _buildCompactView(BuildContext context) {
    // Group attachments by type for better presentation
    final imageAttachments = attachments.where((a) => a.isImage).toList();
    final otherAttachments = attachments.where((a) => !a.isImage).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image previews
        if (imageAttachments.isNotEmpty)
          _buildImagePreview(context, imageAttachments),

        // Other attachments
        if (otherAttachments.isNotEmpty) ...[
          if (imageAttachments.isNotEmpty) const SizedBox(height: 8),
          _buildOtherAttachmentsCompact(context, otherAttachments),
        ],
      ],
    );
  }

  Widget _buildImagePreview(BuildContext context, List<Attachment> images) {
    if (images.length == 1) {
      return _buildSingleImagePreview(context, images.first);
    } else if (images.length == 2) {
      return _buildTwoImagesPreview(context, images);
    } else {
      return _buildMultipleImagesPreview(context, images);
    }
  }

  Widget _buildSingleImagePreview(BuildContext context, Attachment image) {
    return GestureDetector(
      onTap: () => _openAttachmentViewer(context, image),
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor),
        ),
        clipBehavior: Clip.hardEdge,
        child: RobustImageWidget(
          imageUrl: image.url,
          fit: BoxFit.cover,
          placeholder: Container(
            color: AppTheme.backgroundColor,
            child: const Center(
              child: Icon(Icons.image, color: AppTheme.textSecondary, size: 32),
            ),
          ),
          errorWidget: Container(
            color: AppTheme.backgroundColor,
            child: const Center(
              child: Icon(Icons.broken_image,
                  color: AppTheme.textTertiary, size: 32),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTwoImagesPreview(BuildContext context, List<Attachment> images) {
    return SizedBox(
      height: 100,
      child: Row(
        children: [
          Expanded(child: _buildCompactAttachmentItem(context, images[0])),
          const SizedBox(width: 4),
          Expanded(child: _buildCompactAttachmentItem(context, images[1])),
        ],
      ),
    );
  }

  Widget _buildMultipleImagesPreview(
      BuildContext context, List<Attachment> images) {
    final displayImages = images.take(3).toList();
    final hasMore = images.length > 3;

    return SizedBox(
      height: 100,
      child: Row(
        children: [
          Expanded(
              child: _buildCompactAttachmentItem(context, displayImages[0])),
          const SizedBox(width: 4),
          Expanded(
              child: _buildCompactAttachmentItem(context, displayImages[1])),
          const SizedBox(width: 4),
          Expanded(
            child: hasMore
                ? _buildImageWithOverlay(
                    context, displayImages[2], images.length - 2)
                : _buildCompactAttachmentItem(context, displayImages[2]),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWithOverlay(
      BuildContext context, Attachment image, int remainingCount) {
    return GestureDetector(
      onTap: () {
        // Open AttachmentViewerPage to show all attachments in a list
        final attachmentMaps = attachments.map((a) => a.toJson()).toList();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AttachmentViewerPage(
              attachments: attachmentMaps,
              title: 'Attachments',
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RobustImageWidget(
              imageUrl: image.url,
              fit: BoxFit.cover,
              placeholder: Container(
                color: AppTheme.backgroundColor,
                child: const Icon(Icons.image,
                    color: AppTheme.textSecondary, size: 24),
              ),
              errorWidget: Container(
                color: AppTheme.backgroundColor,
                child: const Icon(Icons.broken_image,
                    color: AppTheme.textTertiary, size: 24),
              ),
            ),
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Text(
                  '+$remainingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherAttachmentsCompact(
      BuildContext context, List<Attachment> others) {
    final displayOthers = others.take(3).toList();
    final hasMore = others.length > 3;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...displayOthers.map(
            (attachment) => _buildCompactAttachmentItem(context, attachment)),
        if (hasMore) _buildMoreIndicator(context, others.length - 3),
      ],
    );
  }

  Widget _buildFullView(BuildContext context) {
    // Show all attachments in a simple list view
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...attachments.map((attachment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildFullAttachmentItem(context, attachment),
            )),
      ],
    );
  }

  Widget _buildCompactAttachmentItem(
      BuildContext context, Attachment attachment) {
    return GestureDetector(
      onTap: () => _openAttachmentViewer(context, attachment),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: attachment.isImage
              ? Colors.transparent
              : _getFileTypeColor(attachment.fileType).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor),
        ),
        clipBehavior: Clip.hardEdge,
        child: attachment.isImage
            ? RobustImageWidget(
                imageUrl: attachment.url,
                fit: BoxFit.cover,
                placeholder: Container(
                  color: AppTheme.backgroundColor,
                  child: const Icon(
                    Icons.image,
                    color: AppTheme.textSecondary,
                    size: 24,
                  ),
                ),
                errorWidget: Container(
                  color: AppTheme.backgroundColor,
                  child: const Icon(
                    Icons.broken_image,
                    color: AppTheme.textTertiary,
                    size: 24,
                  ),
                ),
              )
            : Icon(
                _getFileTypeIcon(attachment.fileType),
                color: _getFileTypeColor(attachment.fileType),
                size: 24,
              ),
      ),
    );
  }

  Widget _buildFullAttachmentItem(BuildContext context, Attachment attachment) {
    return GestureDetector(
      onTap: () => _openAttachmentViewer(context, attachment),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getFileTypeColor(attachment.fileType)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getFileTypeIcon(attachment.fileType),
                color: _getFileTypeColor(attachment.fileType),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.getDisplayName(maxLength: 40),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${attachment.fileTypeDescription} • ${attachment.sizeFormattedWithFallback}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.open_in_new,
              size: 16,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreIndicator(BuildContext context, int remainingCount) {
    return GestureDetector(
      onTap: () {
        // Open AttachmentViewerPage to show all attachments in a list
        final attachmentMaps = attachments.map((a) => a.toJson()).toList();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AttachmentViewerPage(
              attachments: attachmentMaps,
              title: 'Attachments',
            ),
          ),
        );
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '+$remainingCount',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'more',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAttachmentViewer(BuildContext context, Attachment attachment) {
    // Open the built-in attachment viewer directly
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BuiltInAttachmentViewer(
          attachment: attachment.toJson(),
        ),
      ),
    );
  }

  IconData _getFileTypeIcon(String fileType) {
    switch (fileType) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.audiotrack;
      case 'document':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileTypeColor(String fileType) {
    switch (fileType) {
      case 'image':
        return Colors.blue;
      case 'video':
        return Colors.red;
      case 'audio':
        return Colors.orange;
      case 'document':
        return Colors.green;
      default:
        return AppTheme.textSecondary;
    }
  }
}
