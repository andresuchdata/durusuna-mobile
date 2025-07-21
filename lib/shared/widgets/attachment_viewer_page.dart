import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';
import 'attachment_list.dart';

class AttachmentViewerPage extends StatefulWidget {
  final List<Map<String, dynamic>> attachments;
  final String title;
  final int? initialIndex;

  const AttachmentViewerPage({
    super.key,
    required this.attachments,
    this.title = 'Attachments',
    this.initialIndex,
  });

  @override
  State<AttachmentViewerPage> createState() => _AttachmentViewerPageState();
}

class _AttachmentViewerPageState extends State<AttachmentViewerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'List View'),
            Tab(text: 'Grid View'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildListView(),
          _buildGridView(),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          AttachmentList(
            attachments: widget.attachments,
            mode: AttachmentListMode.vertical,
            showHeader: false,
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          AttachmentList(
            attachments: widget.attachments,
            mode: AttachmentListMode.grid,
            showHeader: false,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final totalSize = widget.attachments.fold<int>(
      0,
      (sum, attachment) => sum + (attachment['fileSize'] as int? ?? 0),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.attach_file,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.attachments.length} Attachments',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (totalSize > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Total size: ${_formatTotalSize(totalSize)}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildFileTypeBreakdown(),
        ],
      ),
    );
  }

  Widget _buildFileTypeBreakdown() {
    final typeMap = <String, int>{};

    for (final attachment in widget.attachments) {
      final fileType = attachment['fileType'] as String? ?? 'unknown';
      final category = _getCategoryFromMimeType(fileType);
      typeMap[category] = (typeMap[category] ?? 0) + 1;
    }

    if (typeMap.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: typeMap.entries.map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getCategoryColor(entry.key).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getCategoryColor(entry.key).withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getCategoryIcon(entry.key),
                size: 14,
                color: _getCategoryColor(entry.key),
              ),
              const SizedBox(width: 4),
              Text(
                '${entry.key} (${entry.value})',
                style: TextStyle(
                  fontSize: 12,
                  color: _getCategoryColor(entry.key),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _getCategoryFromMimeType(String mimeType) {
    if (mimeType.startsWith('image/')) return 'Images';
    if (mimeType.startsWith('video/')) return 'Videos';
    if (mimeType.startsWith('audio/')) return 'Audio';
    if (mimeType == 'application/pdf') return 'PDFs';
    if (mimeType.contains('word') || mimeType.contains('document'))
      return 'Documents';
    if (mimeType.contains('excel') || mimeType.contains('sheet'))
      return 'Spreadsheets';
    if (mimeType.contains('powerpoint') || mimeType.contains('presentation'))
      return 'Presentations';
    if (mimeType.contains('zip') || mimeType.contains('compressed'))
      return 'Archives';
    return 'Other';
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Images':
        return Icons.image;
      case 'Videos':
        return Icons.videocam;
      case 'Audio':
        return Icons.audiotrack;
      case 'PDFs':
        return Icons.picture_as_pdf;
      case 'Documents':
        return Icons.description;
      case 'Spreadsheets':
        return Icons.grid_on;
      case 'Presentations':
        return Icons.slideshow;
      case 'Archives':
        return Icons.archive;
      default:
        return Icons.attach_file;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Images':
        return Colors.blue;
      case 'Videos':
        return Colors.red;
      case 'Audio':
        return Colors.orange;
      case 'PDFs':
        return Colors.red;
      case 'Documents':
        return Colors.blue;
      case 'Spreadsheets':
        return Colors.green;
      case 'Presentations':
        return Colors.orange;
      case 'Archives':
        return Colors.purple;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatTotalSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}
