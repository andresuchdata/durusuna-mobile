import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/url_utils.dart';
import 'robust_image_widget.dart';

class BuiltInAttachmentViewer extends StatefulWidget {
  final Map<String, dynamic> attachment;

  const BuiltInAttachmentViewer({
    super.key,
    required this.attachment,
  });

  @override
  State<BuiltInAttachmentViewer> createState() =>
      _BuiltInAttachmentViewerState();
}

class _BuiltInAttachmentViewerState extends State<BuiltInAttachmentViewer> {
  late String fileName;
  late String mimeType;
  late String? fileUrl;
  late int fileSize;
  late String downloadUrl;

  @override
  void initState() {
    super.initState();
    _initializeFileData();
  }

  void _initializeFileData() {
    fileName = widget.attachment['fileName'] ??
        widget.attachment['filename'] ??
        'Unknown File';
    mimeType = widget.attachment['mimeType'] ??
        widget.attachment['fileType'] ??
        'application/octet-stream';
    fileUrl = widget.attachment['url'] ?? widget.attachment['fileUrl'];
    fileSize = widget.attachment['size'] ?? widget.attachment['fileSize'] ?? 0;

    // Handle different URL formats using dynamic backend URL
    downloadUrl = fileUrl ?? '';
    if (downloadUrl.isNotEmpty) {
      if (downloadUrl.startsWith('/')) {
        // Use the current backend base URL without /api suffix
        final backendUrl = ApiConstants.baseUrl.replaceAll('/api', '');
        downloadUrl = '$backendUrl$downloadUrl';
      } else if (!downloadUrl.startsWith('http')) {
        downloadUrl = '${ApiConstants.baseUrl}/uploads/serve/$downloadUrl';
      }
      // Rewrite URL for platform compatibility (mainly for local development)
      downloadUrl = UrlUtils.rewriteUrl(downloadUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isImage ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: _isImage ? Colors.black : Colors.white,
        foregroundColor: _isImage ? Colors.white : AppTheme.textPrimary,
        title: Text(
          fileName,
          style: TextStyle(
            color: _isImage ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.download,
              color: _isImage ? Colors.white : AppTheme.textPrimary,
            ),
            onPressed: _downloadFile,
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (fileUrl == null || fileUrl!.isEmpty) {
      return _buildErrorView('File URL not available');
    }

    if (_isImage) {
      return _buildImageViewer();
    } else if (_isVideo) {
      return _buildVideoViewer();
    } else if (_isPdf) {
      return _buildPdfViewer();
    } else {
      return _buildFileInfoView();
    }
  }

  Widget _buildImageViewer() {
    return Center(
      child: InteractiveViewer(
        child: RobustImageWidget(
          imageUrl: downloadUrl,
          fit: BoxFit.contain,
          placeholder: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          errorWidget: _buildErrorView('Failed to load image'),
        ),
      ),
    );
  }

  Widget _buildVideoViewer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.play_circle_fill,
            size: 64,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Video Player',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            fileName,
            style: const TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _downloadFile,
            icon: const Icon(Icons.download),
            label: const Text('Download to Play'),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'PDF Document',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            fileName,
            style: const TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _downloadFile,
            icon: const Icon(Icons.download),
            label: const Text('Download PDF'),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Open in Browser'),
          ),
        ],
      ),
    );
  }

  Widget _buildFileInfoView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              children: [
                Icon(
                  _getFileIcon(),
                  size: 64,
                  color: _getFileColor(),
                ),
                const SizedBox(height: 16),
                Text(
                  fileName,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _getFileTypeLabel(),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatFileSize(),
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _downloadFile,
                    icon: const Icon(Icons.download),
                    label: const Text('Download File'),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: _isImage ? Colors.white : AppTheme.errorColor,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: _isImage ? Colors.white : AppTheme.errorColor,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _downloadFile() async {
    if (downloadUrl.isEmpty) return;

    try {
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening $fileName...')),
          );
        }
      } else {
        _showErrorSnackBar('Unable to download file');
      }
    } catch (e) {
      _showErrorSnackBar('Error downloading file: $e');
    }
  }

  Future<void> _openInBrowser() async {
    if (downloadUrl.isEmpty) return;

    try {
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.inAppWebView);
      } else {
        _showErrorSnackBar('Unable to open in browser');
      }
    } catch (e) {
      _showErrorSnackBar('Error opening in browser: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  // File type helpers
  bool get _isImage => mimeType.startsWith('image/');
  bool get _isVideo => mimeType.startsWith('video/');
  bool get _isAudio => mimeType.startsWith('audio/');
  bool get _isPdf => mimeType == 'application/pdf';
  bool get _isWord =>
      mimeType.contains('word') || mimeType.contains('document');
  bool get _isExcel => mimeType.contains('excel') || mimeType.contains('sheet');
  bool get _isPowerPoint =>
      mimeType.contains('powerpoint') || mimeType.contains('presentation');
  bool get _isZip =>
      mimeType.contains('zip') || mimeType.contains('compressed');

  IconData _getFileIcon() {
    if (_isImage) return Icons.image;
    if (_isVideo) return Icons.videocam;
    if (_isAudio) return Icons.audiotrack;
    if (_isPdf) return Icons.picture_as_pdf;
    if (_isWord) return Icons.description;
    if (_isExcel) return Icons.grid_on;
    if (_isPowerPoint) return Icons.slideshow;
    if (_isZip) return Icons.archive;
    return Icons.attach_file;
  }

  Color _getFileColor() {
    if (_isImage) return Colors.blue;
    if (_isVideo) return Colors.red;
    if (_isAudio) return Colors.orange;
    if (_isPdf) return Colors.red;
    if (_isWord) return Colors.blue;
    if (_isExcel) return Colors.green;
    if (_isPowerPoint) return Colors.orange;
    if (_isZip) return Colors.purple;
    return AppTheme.textSecondary;
  }

  String _getFileTypeLabel() {
    if (_isImage) return 'Image';
    if (_isVideo) return 'Video';
    if (_isAudio) return 'Audio';
    if (_isPdf) return 'PDF Document';
    if (_isWord) return 'Word Document';
    if (_isExcel) return 'Excel Spreadsheet';
    if (_isPowerPoint) return 'PowerPoint Presentation';
    if (_isZip) return 'Archive';

    final extension = fileName.split('.').last.toUpperCase();
    return extension.length <= 4 ? '$extension File' : 'File';
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
