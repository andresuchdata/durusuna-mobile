import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';

class AttachmentPreview extends StatelessWidget {
  final String fileName;
  final String fileType;
  final int fileSize;
  final String? fileUrl;
  final VoidCallback? onTap;
  final bool showSize;
  final AttachmentPreviewMode mode;

  const AttachmentPreview({
    super.key,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    this.fileUrl,
    this.onTap,
    this.showSize = true,
    this.mode = AttachmentPreviewMode.list,
  });

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case AttachmentPreviewMode.list:
        return _buildListMode();
      case AttachmentPreviewMode.compact:
        return _buildCompactMode();
      case AttachmentPreviewMode.grid:
        return _buildGridMode();
    }
  }

  Widget _buildListMode() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              _buildFileIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showSize) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _getFileTypeLabel(),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const Text(
                            ' • ',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _formatFileSize(),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  _isImage ? Icons.visibility : Icons.download,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMode() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFileIcon(size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridMode() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFileIcon(size: 32),
              const SizedBox(height: 8),
              Text(
                fileName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              if (showSize) ...[
                const SizedBox(height: 4),
                Text(
                  _formatFileSize(),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileIcon({double size = 24}) {
    IconData iconData;
    Color iconColor;

    if (_isImage) {
      iconData = Icons.image;
      iconColor = Colors.blue;
    } else if (_isVideo) {
      iconData = Icons.videocam;
      iconColor = Colors.red;
    } else if (_isAudio) {
      iconData = Icons.audiotrack;
      iconColor = Colors.orange;
    } else if (_isPdf) {
      iconData = Icons.picture_as_pdf;
      iconColor = Colors.red;
    } else if (_isWord) {
      iconData = Icons.description;
      iconColor = Colors.blue;
    } else if (_isExcel) {
      iconData = Icons.grid_on;
      iconColor = Colors.green;
    } else if (_isPowerPoint) {
      iconData = Icons.slideshow;
      iconColor = Colors.orange;
    } else if (_isZip) {
      iconData = Icons.archive;
      iconColor = Colors.purple;
    } else {
      iconData = Icons.attach_file;
      iconColor = AppTheme.textSecondary;
    }

    return Icon(
      iconData,
      size: size,
      color: iconColor,
    );
  }

  bool get _isImage => fileType.startsWith('image/');
  bool get _isVideo => fileType.startsWith('video/');
  bool get _isAudio => fileType.startsWith('audio/');
  bool get _isPdf => fileType == 'application/pdf';
  bool get _isWord =>
      fileType.contains('word') || fileType.contains('document');
  bool get _isExcel => fileType.contains('excel') || fileType.contains('sheet');
  bool get _isPowerPoint =>
      fileType.contains('powerpoint') || fileType.contains('presentation');
  bool get _isZip =>
      fileType.contains('zip') || fileType.contains('compressed');

  String _getFileTypeLabel() {
    if (_isImage) return 'Image';
    if (_isVideo) return 'Video';
    if (_isAudio) return 'Audio';
    if (_isPdf) return 'PDF';
    if (_isWord) return 'Document';
    if (_isExcel) return 'Spreadsheet';
    if (_isPowerPoint) return 'Presentation';
    if (_isZip) return 'Archive';

    final extension = fileName.split('.').last.toUpperCase();
    return extension.length <= 4 ? extension : 'File';
  }

  String _formatFileSize() {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024)
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    if (fileSize < 1024 * 1024 * 1024)
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

enum AttachmentPreviewMode {
  list, // Full width with icon, name, size, type
  compact, // Inline chip-like display
  grid, // Grid tile with large icon
}
