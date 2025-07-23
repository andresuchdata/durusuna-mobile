import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/services/media_service.dart';
import '../../../../shared/models/attachment.dart';

class MediaUploadWidget extends StatefulWidget {
  final String classId;
  final List<Attachment> currentAttachments;
  final Function(List<Attachment>) onAttachmentsChanged;
  final Function(MediaUploadProgress)? onUploadProgress;

  const MediaUploadWidget({
    super.key,
    required this.classId,
    required this.currentAttachments,
    required this.onAttachmentsChanged,
    this.onUploadProgress,
  });

  @override
  State<MediaUploadWidget> createState() => _MediaUploadWidgetState();
}

class _MediaUploadWidgetState extends State<MediaUploadWidget> {
  final MediaService _mediaService = MediaService();
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.attach_file,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Attachments (${widget.currentAttachments.length}/5)',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              if (widget.currentAttachments.length < 5) ...[
                TextButton.icon(
                  onPressed: _isUploading ? null : _showMediaPicker,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Media'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ],
          ),

          // Upload progress
          if (_isUploading) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _uploadStatus,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor: AppTheme.borderColor,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ],
            ),
          ],

          // Attachments list
          if (widget.currentAttachments.isNotEmpty) ...[
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.currentAttachments.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final attachment = widget.currentAttachments[index];
                return _buildAttachmentItem(attachment, index);
              },
            ),
          ],

          // Upload tips
          if (widget.currentAttachments.isEmpty && !_isUploading) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can attach up to 5 files (images, videos, documents) with a maximum size of 5MB each.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentItem(Attachment attachment, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          // File type icon
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

          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.getDisplayName(maxLength: 35),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      attachment.fileTypeDescription,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    const Text(' • ',
                        style: TextStyle(color: AppTheme.textTertiary)),
                    Text(
                      attachment.sizeFormattedWithFallback,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Remove button
          IconButton(
            onPressed: () => _removeAttachment(index),
            icon: const Icon(Icons.close, size: 20),
            color: AppTheme.textTertiary,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Add Attachment',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _takePicture();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Record Video'),
              onTap: () {
                Navigator.pop(context);
                _recordVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Choose Document'),
              onTap: () {
                Navigator.pop(context);
                _pickDocuments();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    final remainingSlots = 5 - widget.currentAttachments.length;
    final images =
        await _mediaService.pickMultipleImages(limit: remainingSlots);
    if (images.isNotEmpty) {
      await _uploadFiles(images);
    }
  }

  Future<void> _takePicture() async {
    final image = await _mediaService.pickImage(source: ImageSource.camera);
    if (image != null) {
      await _uploadFiles([image]);
    }
  }

  Future<void> _recordVideo() async {
    final video = await _mediaService.pickVideo(source: ImageSource.camera);
    if (video != null) {
      await _uploadFiles([video]);
    }
  }

  Future<void> _pickDocuments() async {
    final remainingSlots = 5 - widget.currentAttachments.length;
    final files = await _mediaService.pickFiles(
      allowMultiple: remainingSlots > 1,
      fileSizeLimit: 5 * 1024 * 1024, // 5MB
    );
    if (files.isNotEmpty) {
      await _uploadFiles(files.take(remainingSlots).toList());
    }
  }

  Future<void> _uploadFiles(List<MediaPickerResult> files) async {
    if (files.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Preparing upload...';
    });

    try {
      final attachments = await _mediaService.uploadClassUpdateAttachments(
        files: files,
        classId: widget.classId,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress.progress;
            _uploadStatus = progress.status;
          });
          widget.onUploadProgress?.call(progress);
        },
      );

      setState(() {
        _isUploading = false;
      });

      final updatedAttachments = [...widget.currentAttachments, ...attachments];
      widget.onAttachmentsChanged(updatedAttachments);

      // Use post-frame callback to avoid widget lifecycle issues
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            try {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '${attachments.length} file(s) uploaded successfully'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            } catch (e) {
              debugPrint('Error showing success snackbar: $e');
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            try {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Upload failed: $e'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            } catch (e) {
              debugPrint('Error showing error snackbar: $e');
            }
          }
        });
      }
    }
  }

  void _removeAttachment(int index) {
    final updatedAttachments = [...widget.currentAttachments];
    updatedAttachments.removeAt(index);
    widget.onAttachmentsChanged(updatedAttachments);
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
