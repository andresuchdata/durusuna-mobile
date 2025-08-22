import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_update.dart';
import '../../../../shared/models/class_update_comment.dart';
import '../../../../shared/services/class_updates_service.dart';
import '../../../../shared/services/auth_service.dart';

import '../widgets/class_update_comment_card.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../widgets/attachment_preview_widget.dart';
import '../../../../shared/models/attachment.dart';

class ClassUpdateDetailPage extends ConsumerStatefulWidget {
  final ClassUpdate update;
  final String className;

  const ClassUpdateDetailPage({
    super.key,
    required this.update,
    required this.className,
  });

  @override
  ConsumerState<ClassUpdateDetailPage> createState() =>
      _ClassUpdateDetailPageState();
}

class _ClassUpdateDetailPageState extends ConsumerState<ClassUpdateDetailPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  String? _replyToCommentId;
  String? _replyToUsername;

  int _currentPage = 1;
  static const int _commentsPerPage = 20;
  List<ClassUpdateComment> _comments = [];
  bool _isLoadingComments = false;
  bool _hasMoreComments = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingComments && _hasMoreComments) {
        _loadComments();
      }
    }
  }

  Future<void> _loadComments({bool refresh = false}) async {
    if (_isLoadingComments) return;

    setState(() {
      _isLoadingComments = true;
      if (refresh) {
        _currentPage = 1;
        _comments.clear();
      }
    });

    try {
      final service = ref.read(classUpdatesServiceProvider);
      final comments = await service.getComments(
        widget.update.id,
        page: _currentPage,
        limit: _commentsPerPage,
      );

      setState(() {
        if (refresh) {
          _comments = comments;
        } else {
          _comments.addAll(comments);
        }
        _hasMoreComments = comments.length == _commentsPerPage;
        _currentPage++;
        _isLoadingComments = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingComments = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load comments: $e')),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    try {
      final service = ref.read(classUpdatesServiceProvider);
      final newComment = await service.addComment(
        updateId: widget.update.id,
        content: content,
        replyToId: _replyToCommentId,
      );

      setState(() {
        _comments.insert(0, newComment);
        _commentController.clear();
        _replyToCommentId = null;
        _replyToUsername = null;
      });

      _commentFocusNode.unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    }
  }

  void _replyToComment(ClassUpdateComment comment) {
    setState(() {
      _replyToCommentId = comment.id;
      _replyToUsername = comment.author?.displayName ?? 'User';
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToUsername = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.className),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Main update content
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Update card
                  _buildUpdateCard(),

                  const SizedBox(height: 24),

                  // Comments section
                  _buildCommentsSection(),
                ],
              ),
            ),
          ),

          // Comment input
          if (authState.user != null) _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildUpdateCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Author avatar
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    widget.update.author != null
                        ? '${widget.update.author!.firstName[0]}${widget.update.author!.lastName[0]}'
                        : 'T',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Author info and timestamp
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.update.author?.displayName ?? 'Teacher',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _getUpdateTypeColor(widget.update.updateType),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.update.updateTypeIcon,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          // Pin indicator
                          if (widget.update.isPinned) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.push_pin,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeago.format(widget.update.createdAt),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Title
          if (widget.update.title != null && widget.update.title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.update.title!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // Content (full text)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.update.content,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),

          // Attachments
          if (widget.update.hasAttachments)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildAttachments(),
            ),

          // Reactions
          if (widget.update.hasReactions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildReactions(),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAttachments() {
    final attachments = <Attachment>[];

    try {
      if (widget.update.attachments != null &&
          widget.update.attachments is List) {
        final attachmentList = widget.update.attachments as List;

        for (int i = 0; i < attachmentList.length; i++) {
          final item = attachmentList[i];

          try {
            if (item != null && item is Map<String, dynamic>) {
              final attachment = Attachment.fromJson(item);
              attachments.add(attachment);
            }
          } catch (e) {
            debugPrint('Error parsing attachment item $i: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing attachments: $e');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: AttachmentPreviewWidget(
        attachments: attachments,
        isCompact: false,
      ),
    );
  }

  Widget _buildReactions() {
    final authState = ref.watch(authStateProvider);

    return Wrap(
      spacing: 8,
      children: widget.update.reactions!.entries.map((entry) {
        final emoji = entry.key;
        final reaction = entry.value;
        final hasUserReacted = authState.user?.id != null &&
            widget.update.hasUserReacted(emoji, authState.user!.id);

        return GestureDetector(
          onTap: () {
            // Handle reaction toggle
            ref
                .read(classUpdatesProvider(widget.update.classId).notifier)
                .toggleReaction(widget.update.id, emoji);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasUserReacted
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasUserReacted
                    ? AppTheme.primaryColor.withValues(alpha: 0.3)
                    : AppTheme.borderColor,
                width: hasUserReacted ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emoji,
                  style: TextStyle(
                    fontSize: 16,
                    shadows: hasUserReacted
                        ? [
                            Shadow(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${reaction.count}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        hasUserReacted ? FontWeight.w600 : FontWeight.w500,
                    color: hasUserReacted
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comments (${_comments.length})',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        if (_comments.isEmpty && !_isLoadingComments)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No comments yet. Be the first to comment!',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ...(_comments.map((comment) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ClassUpdateCommentCard(
                comment: comment,
                onReply: _replyToComment,
              ),
            ))),
        if (_isLoadingComments)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reply indicator
          if (_replyToCommentId != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.reply,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to $_replyToUsername',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

          // Comment input field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _submitComment,
                icon: Icon(
                  Icons.send,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getUpdateTypeColor(UpdateType type) {
    switch (type) {
      case UpdateType.announcement:
        return AppTheme.primaryColor.withValues(alpha: 0.1);
      case UpdateType.homework:
        return AppTheme.warningColor.withValues(alpha: 0.1);
      case UpdateType.reminder:
        return AppTheme.infoColor.withValues(alpha: 0.1);
      case UpdateType.event:
        return AppTheme.successColor.withValues(alpha: 0.1);
    }
  }
}
