import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_update.dart';
import '../../../../shared/models/class_update_comment.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/services/class_updates_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../widgets/class_update_card.dart';
import 'create_update_page.dart';

class ClassUpdatesPage extends ConsumerStatefulWidget {
  final String classId;
  final String className;

  const ClassUpdatesPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  ConsumerState<ClassUpdatesPage> createState() => _ClassUpdatesPageState();
}

class _ClassUpdatesPageState extends ConsumerState<ClassUpdatesPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = ref.read(classUpdatesProvider(widget.classId));
      if (!state.isLoading && state.hasMore) {
        ref.read(classUpdatesProvider(widget.classId).notifier).loadUpdates();
      }
    }
  }

  void _showCreateUpdateDialog() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CreateUpdatePage(
          classId: widget.classId,
        ),
      ),
    );

    // Refresh updates if the form was submitted successfully
    if (result == true) {
      ref
          .read(classUpdatesProvider(widget.classId).notifier)
          .loadUpdates(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final updatesState = ref.watch(classUpdatesProvider(widget.classId));
    final canPost = authState.user?.userType == UserType.teacher;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.className),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (canPost)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showCreateUpdateDialog,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref
                  .read(classUpdatesProvider(widget.classId).notifier)
                  .loadUpdates(refresh: true);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref
              .read(classUpdatesProvider(widget.classId).notifier)
              .loadUpdates(refresh: true);
        },
        child: Column(
          children: [
            // Create post section for teachers
            if (canPost) ...[
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        '${authState.user?.firstName[0]}${authState.user?.lastName[0]}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showCreateUpdateDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Share an update with your class...',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Updates list
            Expanded(
              child: updatesState.isLoading && updatesState.updates.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : updatesState.updates.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: updatesState.updates.length +
                              (updatesState.isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == updatesState.updates.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            }

                            final update = updatesState.updates[index];
                            return ClassUpdateCard(
                              update: update,
                              onReaction: (emoji) {
                                ref
                                    .read(classUpdatesProvider(widget.classId)
                                        .notifier)
                                    .toggleReaction(update.id, emoji);
                              },
                              onComment: () {
                                _showCommentsBottomSheet(update);
                              },
                              onEdit: canPost &&
                                      update.authorId == authState.user?.id
                                  ? () => _showEditUpdateDialog(update)
                                  : null,
                              onDelete: canPost &&
                                      update.authorId == authState.user?.id
                                  ? () => _confirmDeleteUpdate(update)
                                  : null,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.announcement_outlined,
            size: 64,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No updates yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Teachers can share announcements, homework,\nand other important updates here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditUpdateDialog(ClassUpdate update) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CreateUpdatePage(
          classId: widget.classId,
          editingUpdate: update,
        ),
      ),
    );

    // Refresh updates if the form was submitted successfully
    if (result == true) {
      ref
          .read(classUpdatesProvider(widget.classId).notifier)
          .loadUpdates(refresh: true);
    }
  }

  void _confirmDeleteUpdate(ClassUpdate update) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Update'),
        content: const Text(
          'Are you sure you want to delete this update? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref
                    .read(classUpdatesProvider(widget.classId).notifier)
                    .deleteUpdate(update.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Update deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete update: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCommentsBottomSheet(ClassUpdate update) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => CommentsBottomSheet(
        update: update,
        classId: widget.classId,
      ),
    );

    // Refresh updates if a comment was posted
    if (result == true) {
      ref
          .read(classUpdatesProvider(widget.classId).notifier)
          .loadUpdates(refresh: true);
    }
  }
}

// Comments bottom sheet widget
class CommentsBottomSheet extends ConsumerStatefulWidget {
  final ClassUpdate update;
  final String classId;

  const CommentsBottomSheet({
    super.key,
    required this.update,
    required this.classId,
  });

  @override
  ConsumerState<CommentsBottomSheet> createState() =>
      _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends ConsumerState<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isPosting = false;
  bool _isLoading = true;
  List<ClassUpdateComment> _comments = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(classUpdatesServiceProvider);
      final comments = await service.getComments(widget.update.id);

      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isPosting = true);

    try {
      final service = ref.read(classUpdatesServiceProvider);
      await service.addComment(
        updateId: widget.update.id,
        content: _commentController.text.trim(),
      );

      _commentController.clear();
      _focusNode.unfocus();

      // Refresh comments list
      await _loadComments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment posted')),
        );

        // Close the bottom sheet and signal success
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post comment: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Comments',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${_comments.length}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Comments list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Failed to load comments',
                                style: TextStyle(color: AppTheme.errorColor),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _loadComments,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _comments.isEmpty
                          ? const Center(
                              child: Text(
                                'No comments yet.\nBe the first to comment!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _comments.length,
                              itemBuilder: (context, index) {
                                final comment = _comments[index];
                                return CommentWidget(comment: comment);
                              },
                            ),
            ),

            // Comment input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      '${authState.user?.firstName[0]}${authState.user?.lastName[0]}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppTheme.backgroundColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _postComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isPosting ? null : _postComment,
                    icon: _isPosting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// Individual comment widget
class CommentWidget extends StatelessWidget {
  final ClassUpdateComment comment;

  const CommentWidget({super.key, required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryColor,
            child: Text(
              comment.author != null &&
                      comment.author!.firstName.isNotEmpty &&
                      comment.author!.lastName.isNotEmpty
                  ? '${comment.author!.firstName[0]}${comment.author!.lastName[0]}'
                  : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.author != null
                      ? '${comment.author!.firstName} ${comment.author!.lastName}'
                      : 'Unknown User',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  timeago.format(comment.createdAt),
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
