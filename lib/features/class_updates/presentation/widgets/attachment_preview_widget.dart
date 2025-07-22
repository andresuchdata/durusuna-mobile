import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/attachment.dart';
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
    // Show only first few attachments in compact mode
    final displayAttachments = attachments.take(3).toList();
    final hasMore = attachments.length > 3;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...displayAttachments.map(
            (attachment) => _buildCompactAttachmentItem(context, attachment)),
        if (hasMore) _buildMoreIndicator(context, attachments.length - 3),
      ],
    );
  }

  Widget _buildFullView(BuildContext context) {
    // Group attachments by type for better presentation
    final imageAttachments = attachments.where((a) => a.isImage).toList();
    final otherAttachments = attachments.where((a) => !a.isImage).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image gallery
        if (imageAttachments.isNotEmpty)
          _buildImageGallery(context, imageAttachments),

        // Other attachments list
        if (otherAttachments.isNotEmpty) ...[
          if (imageAttachments.isNotEmpty) const SizedBox(height: 12),
          ...otherAttachments.map((attachment) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildFullAttachmentItem(context, attachment),
              )),
        ],
      ],
    );
  }

  Widget _buildImageGallery(BuildContext context, List<Attachment> images) {
    if (images.length == 1) {
      return _buildSingleImage(context, images.first);
    } else if (images.length == 2) {
      return _buildTwoImages(context, images);
    } else {
      return _buildMultipleImages(context, images);
    }
  }

  Widget _buildSingleImage(BuildContext context, Attachment image) {
    return GestureDetector(
      onTap: () => _openAttachmentViewer(context, image),
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppTheme.backgroundColor,
        ),
        clipBehavior: Clip.hardEdge,
        child: CachedNetworkImage(
          imageUrl: image.url,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: AppTheme.backgroundColor,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: AppTheme.backgroundColor,
            child: const Icon(
              Icons.broken_image,
              color: AppTheme.textTertiary,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTwoImages(BuildContext context, List<Attachment> images) {
    return SizedBox(
      height: 150,
      child: Row(
        children: [
          Expanded(
            child: _buildImageThumbnail(context, images[0]),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildImageThumbnail(context, images[1]),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleImages(BuildContext context, List<Attachment> images) {
    final displayImages = images.take(4).toList();
    final hasMore = images.length > 4;

    return SizedBox(
      height: 150,
      child: Row(
        children: [
          Expanded(
            child: _buildImageThumbnail(context, displayImages[0]),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildImageThumbnail(context, displayImages[1]),
                ),
                if (displayImages.length > 2) ...[
                  const SizedBox(height: 4),
                  Expanded(
                    child: displayImages.length > 3 || hasMore
                        ? _buildImageWithOverlay(
                            context,
                            displayImages.length > 3
                                ? displayImages[2]
                                : displayImages[2],
                            hasMore
                                ? images.length - 3
                                : displayImages.length > 3
                                    ? 1
                                    : 0,
                          )
                        : _buildImageThumbnail(context, displayImages[2]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(BuildContext context, Attachment image) {
    return GestureDetector(
      onTap: () => _openAttachmentViewer(context, image),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppTheme.backgroundColor,
        ),
        clipBehavior: Clip.hardEdge,
        child: CachedNetworkImage(
          imageUrl: image.thumbnailUrl ?? image.url,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: AppTheme.backgroundColor,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: AppTheme.backgroundColor,
            child: const Icon(
              Icons.broken_image,
              color: AppTheme.textTertiary,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageWithOverlay(
      BuildContext context, Attachment image, int remainingCount) {
    return GestureDetector(
      onTap: () => _openAttachmentViewer(context, image),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppTheme.backgroundColor,
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: image.thumbnailUrl ?? image.url,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: AppTheme.backgroundColor,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppTheme.backgroundColor,
                child: const Icon(
                  Icons.broken_image,
                  color: AppTheme.textTertiary,
                  size: 24,
                ),
              ),
            ),
            if (remainingCount > 0)
              Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Text(
                    '+$remainingCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
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

  Widget _buildCompactAttachmentItem(
      BuildContext context, Attachment attachment) {
    return GestureDetector(
      onTap: () => _openAttachmentViewer(context, attachment),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: _getFileTypeColor(attachment.fileType).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: attachment.isImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: CachedNetworkImage(
                  imageUrl: attachment.thumbnailUrl ?? attachment.url,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Icon(
                    Icons.image,
                    color: AppTheme.textSecondary,
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.broken_image,
                    color: AppTheme.textTertiary,
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
          color: AppTheme.backgroundColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getFileTypeColor(attachment.fileType).withOpacity(0.1),
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
                    '${attachment.fileTypeDescription} • ${attachment.sizeFormatted}',
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
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '+$remainingCount',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
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
    // Convert attachments to the format expected by AttachmentViewerPage
    final attachmentMaps = attachments.map((a) => a.toJson()).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AttachmentViewerPage(
          attachments: attachmentMaps,
          initialIndex: attachments.indexOf(attachment),
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
