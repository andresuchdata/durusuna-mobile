import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_update.dart';
import '../../../../shared/models/class_update_comment.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/services/class_updates_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/widgets/reactions_widget.dart';
import '../widgets/class_update_card.dart';
import '../widgets/class_update_comment_card.dart';
import 'create_update_page.dart';

// Helper class to represent comments with embedded replies
class CommentDisplayItem {
  final ClassUpdateComment comment;
  final List<ClassUpdateComment> embeddedReplies;

  CommentDisplayItem({
    required this.comment,
    required this.embeddedReplies,
  });
}

class ClassUpdatesPage extends ConsumerStatefulWidget {
  final String classId;
  final String className;
  final String? highlightUpdateId;
  final bool scrollToUpdate;

  const ClassUpdatesPage({
    super.key,
    required this.classId,
    required this.className,
    this.highlightUpdateId,
    this.scrollToUpdate = false,
  });

  @override
  ConsumerState<ClassUpdatesPage> createState() => _ClassUpdatesPageState();
}

class _ClassUpdatesPageState extends ConsumerState<ClassUpdatesPage> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _updateKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Handle update highlighting and scrolling if requested
    if (widget.highlightUpdateId != null && widget.scrollToUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToHighlightedUpdate();
      });
    }
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

    // Listen for errors and show error feedback
    ref.listen<ClassUpdatesState>(
      classUpdatesProvider(widget.classId),
      (previous, next) {
        // Show error message if there's a new error
        if (next.error != null &&
            (previous?.error != next.error) &&
            next.error!.contains('pin')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.error!),
              duration: const Duration(seconds: 3),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          // Clear the error after showing it
          ref.read(classUpdatesProvider(widget.classId).notifier).clearError();
        }
      },
    );

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
                      color: Colors.black.withValues(alpha: 0.05),
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
                              key: widget.highlightUpdateId == update.id
                                  ? _getUpdateKey(update.id)
                                  : null,
                              update: update,
                              currentUserId: authState.user?.id,
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
                              onPin: canPost ? () => _togglePin(update) : null,
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
          const Icon(
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

  void _togglePin(ClassUpdate update) {
    // Determine the new pin status (what it will become)
    final willBePinned = !update.isPinned;

    // Trigger optimistic update (UI updates immediately)
    ref
        .read(classUpdatesProvider(widget.classId).notifier)
        .togglePin(update.id);

    // Show immediate optimistic feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          willBePinned ? 'Update pinned' : 'Update unpinned',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.successColor,
      ),
    );
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

  void _showCommentsBottomSheet(ClassUpdate update) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => CommentsBottomSheet(
        update: update,
        classId: widget.classId,
        onCommentPosted: () {
          // Refresh the main feed when comments are posted
          ref
              .read(classUpdatesProvider(widget.classId).notifier)
              .loadUpdates(refresh: true);
        },
      ),
    );
  }

  /// Scroll to and highlight a specific update
  void _scrollToHighlightedUpdate() {
    if (widget.highlightUpdateId == null) return;

    // Wait for updates to load, then scroll to the highlighted update
    Future.delayed(const Duration(milliseconds: 1000), () {
      final updateKey = _updateKeys[widget.highlightUpdateId];
      if (updateKey?.currentContext != null) {
        Scrollable.ensureVisible(
          updateKey!.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );

        // Add highlighting animation
        _highlightUpdate(widget.highlightUpdateId!);
      }
    });
  }

  /// Highlight a specific update with animation
  void _highlightUpdate(String updateId) {
    // This would typically involve updating the update's visual state
    // For now, we'll just log it - the UI highlighting would be handled in ClassUpdateCard
    debugPrint('Highlighting update: $updateId');
  }

  /// Get or create a GlobalKey for an update
  GlobalKey _getUpdateKey(String updateId) {
    return _updateKeys.putIfAbsent(updateId, () => GlobalKey());
  }
}

// Comments bottom sheet widget
class CommentsBottomSheet extends ConsumerStatefulWidget {
  final ClassUpdate update;
  final String classId;
  final VoidCallback? onCommentPosted;

  const CommentsBottomSheet({
    super.key,
    required this.update,
    required this.classId,
    this.onCommentPosted,
  });

  @override
  ConsumerState<CommentsBottomSheet> createState() =>
      _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends ConsumerState<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isPosting = false;
  bool _isLoading = true;
  List<ClassUpdateComment> _comments = [];
  String? _error;

  // Reply state management
  ClassUpdateComment? _replyingToComment;
  int _replyDepth = 0;
  String? _mentionText;

  // Cache organized comments to avoid recalculating on every build
  List<CommentDisplayItem>? _organizedComments;

  // Track optimistic comments (temp IDs that haven't been confirmed by server)
  final Set<String> _optimisticCommentIds = {};

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
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
          _organizedComments = null; // Clear cache to force refresh
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

    final content = _commentController.text.trim();
    final replyToId = _replyingToComment?.id;
    final isReply = replyToId != null;

    // Create optimistic comment immediately
    final optimisticComment = _createOptimisticComment(content, replyToId);

    // Add optimistic comment to local list immediately (no await)
    setState(() {
      _comments.add(optimisticComment);
      _optimisticCommentIds.add(optimisticComment.id);
      _organizedComments = null; // Clear cache to refresh display
      _isPosting = true;
    });

    // Clear UI state immediately for better UX
    _commentController.clear();
    _cancelReply();

    // Scroll to show new comment
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      // Send to server in background
      final service = ref.read(classUpdatesServiceProvider);
      final serverComment = await service.addComment(
        updateId: widget.update.id,
        content: content,
        replyToId: replyToId,
      );

      if (mounted) {
        // Replace optimistic comment with server response
        setState(() {
          final index =
              _comments.indexWhere((c) => c.id == optimisticComment.id);
          if (index != -1) {
            _comments[index] = serverComment;
          }
          _optimisticCommentIds.remove(optimisticComment.id);
          _organizedComments = null; // Clear cache
          _isPosting = false;
        });

        // Success feedback (brief)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isReply ? 'Reply posted' : 'Comment posted'),
            duration: const Duration(seconds: 1),
            backgroundColor: AppTheme.successColor,
          ),
        );

        // Keep focus for continued conversation
        _focusNode.requestFocus();

        // Scroll to the newly added reply (after server confirmation)
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            );
          }
        });

        // Notify parent to refresh main feed
        widget.onCommentPosted?.call();
      }
    } catch (e) {
      if (mounted) {
        // Remove optimistic comment on error
        setState(() {
          _comments.removeWhere((c) => c.id == optimisticComment.id);
          _optimisticCommentIds.remove(optimisticComment.id);
          _organizedComments = null; // Clear cache
          _isPosting = false;
        });

        // Show error feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post comment. Tap to retry.'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                // Restore the content and retry
                _commentController.text = content;
                if (isReply) {
                  // Find the comment we were replying to and restore reply state
                  final parentComment = _comments.firstWhere(
                    (c) => c.id == replyToId,
                    orElse: () => optimisticComment.replyTo!,
                  );
                  _replyToComment(parentComment);
                }
                _postComment();
              },
            ),
          ),
        );
      }
    }
  }

  void _handleCommentReaction(ClassUpdateComment comment, String emoji) async {
    // Skip reactions on optimistic comments (not yet confirmed by server)
    if (_optimisticCommentIds.contains(comment.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for comment to be posted'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // Get current user ID for optimistic update
    final currentUser =
        ref.read(authServiceProvider).getCurrentUserFromStorage();
    if (currentUser == null) return;
    final currentUserId = currentUser.id;

    // Find comment in current state
    final commentIndex = _comments.indexWhere((c) => c.id == comment.id);
    if (commentIndex == -1) return;

    // Store original comment for potential rollback
    final originalComment = _comments[commentIndex];

    // Optimistic update: Update UI immediately
    final updatedComment =
        _updateCommentReaction(originalComment, emoji, currentUserId);

    // Update local state optimistically
    setState(() {
      _comments[commentIndex] = updatedComment;
      _organizedComments =
          null; // Clear cache to force refresh with new reaction
    });

    try {
      final service = ref.read(classUpdatesServiceProvider);
      await service.toggleCommentReaction(
        commentId: comment.id,
        emoji: emoji,
      );

      // Success - show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reacted with $emoji'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // Rollback optimistic update on failure
      if (mounted) {
        setState(() {
          _comments[commentIndex] = originalComment;
          _organizedComments =
              null; // Clear cache to force refresh with rollback
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add reaction: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  ClassUpdateComment _updateCommentReaction(
      ClassUpdateComment comment, String emoji, String currentUserId) {
    final reactions = Map<String, dynamic>.from(comment.reactions ?? {});

    if (reactions.containsKey(emoji)) {
      final reactionData = reactions[emoji];

      // Handle different reaction data formats
      if (reactionData is Map<String, dynamic>) {
        final users = List<String>.from(reactionData['users'] ?? []);

        if (users.contains(currentUserId)) {
          // Remove user's reaction
          users.remove(currentUserId);
          if (users.isEmpty) {
            reactions.remove(emoji);
          } else {
            reactions[emoji] = {
              'count': users.length,
              'users': users,
            };
          }
        } else {
          // Add user's reaction
          users.add(currentUserId);
          reactions[emoji] = {
            'count': users.length,
            'users': users,
          };
        }
      } else {
        // Legacy format - convert to new format
        reactions[emoji] = {
          'count': 1,
          'users': [currentUserId],
        };
      }
    } else {
      // Add new reaction
      reactions[emoji] = {
        'count': 1,
        'users': [currentUserId],
      };
    }

    final updatedComment = comment.copyWith(reactions: reactions);
    return updatedComment;
  }

  void _showCommentReactionPicker(ClassUpdateComment comment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        child: ReactionPicker(
          onEmojiSelected: (emoji) {
            _handleCommentReaction(comment, emoji);
          },
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  // Helper method to organize comments with embedded replies
  List<CommentDisplayItem> _organizeCommentsWithReplies() {
    // Return cached result if available
    if (_organizedComments != null) {
      return _organizedComments!;
    }

    final organized = <CommentDisplayItem>[];
    final Map<String, List<ClassUpdateComment>> repliesMap = {};

    // Group ALL replies by their root parent (traverse up reply chains)
    for (final comment in _comments) {
      if (comment.replyToId != null) {
        String rootParentId = _findRootParent(comment, _comments);
        repliesMap.putIfAbsent(rootParentId, () => []).add(comment);
      }
    }

    // Find all top-level comments (no parent) and create display items
    // Backend now sorts these newest-first, so maintain that order
    final topLevelComments =
        _comments.where((comment) => comment.replyToId == null).toList();

    for (final parentComment in topLevelComments) {
      // Get all replies for this parent (including nested ones flattened)
      final allReplies = repliesMap[parentComment.id] ?? [];

      // Sort replies by creation time
      allReplies.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Create display item with parent comment and embedded replies
      organized.add(CommentDisplayItem(
        comment: parentComment,
        embeddedReplies: allReplies,
      ));
    }

    // Cache the result
    _organizedComments = organized;
    return organized;
  }

  // Find the root parent of a comment (traverse up the reply chain)
  String _findRootParent(
      ClassUpdateComment comment, List<ClassUpdateComment> allComments) {
    if (comment.replyToId == null) return comment.id;

    final parent = allComments.firstWhere(
      (c) => c.id == comment.replyToId,
      orElse: () => comment, // Fallback if parent not found
    );

    if (parent.replyToId == null) {
      return parent.id; // This is the root
    } else {
      return _findRootParent(parent, allComments); // Continue traversing up
    }
  }

  // Build a comment with its embedded replies
  Widget _buildCommentWithReplies(
      CommentDisplayItem displayItem, String? currentUserId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Parent comment
        ClassUpdateCommentCard(
          comment: displayItem.comment,
          currentUserId: currentUserId,
          level: 0, // Parent is always level 0
          isOptimistic: _optimisticCommentIds.contains(displayItem.comment.id),
          onReactionTap: (comment, emoji) =>
              _handleCommentReaction(comment, emoji),
          onAddReaction: (comment) => _showCommentReactionPicker(comment),
          onReply: (comment) => _replyToComment(comment),
          onEdit: currentUserId == displayItem.comment.authorId
              ? (comment) => _editComment(comment)
              : null,
          onDelete: currentUserId == displayItem.comment.authorId
              ? (comment) => _deleteComment(comment)
              : null,
        ),

        // Embedded replies with indentation
        if (displayItem.embeddedReplies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 20), // Indent replies
            child: Column(
              children: displayItem.embeddedReplies.map((reply) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClassUpdateCommentCard(
                    comment: reply,
                    currentUserId: currentUserId,
                    level: 1, // All replies are level 1 (max indentation)
                    isOptimistic: _optimisticCommentIds.contains(reply.id),
                    onReactionTap: (comment, emoji) =>
                        _handleCommentReaction(comment, emoji),
                    onAddReaction: (comment) =>
                        _showCommentReactionPicker(comment),
                    onReply: (comment) => _replyToComment(comment),
                    onEdit: currentUserId == reply.authorId
                        ? (comment) => _editComment(comment)
                        : null,
                    onDelete: currentUserId == reply.authorId
                        ? (comment) => _deleteComment(comment)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: 12), // Space between comment groups
      ],
    );
  }

  void _replyToComment(ClassUpdateComment comment) {
    // Find the root parent comment (level 0) to reply to
    ClassUpdateComment parentComment = comment;
    while (parentComment.replyTo != null) {
      parentComment = parentComment.replyTo!;
    }

    final authorName = comment.author?.displayName ?? 'User';

    setState(() {
      _replyingToComment = parentComment; // Always reply to the root parent
      _replyDepth = 1; // Always level 1 (max depth)

      // Always use @mention for replies to show context
      _mentionText = '@$authorName ';
      _commentController.text = _mentionText!;
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length),
      );
    });

    _focusNode.requestFocus();

    // Show visual feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Replying to $authorName'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _cancelReply() {
    setState(() {
      _replyingToComment = null;
      _replyDepth = 0;
      _mentionText = null;
    });
    _commentController.clear();
  }

  // Helper method to create an optimistic comment
  ClassUpdateComment _createOptimisticComment(
      String content, String? replyToId) {
    final currentUser = ref.read(authStateProvider).user;
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    return ClassUpdateComment(
      id: tempId,
      classUpdateId: widget.update.id,
      authorId: currentUser?.id ?? '',
      content: content,
      replyToId: replyToId,
      reactions: {},
      isEdited: false,
      editedAt: null,
      isDeleted: false,
      deletedAt: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      author: currentUser,
      replyTo: _replyingToComment,
      replies: null,
      repliesCount: null,
    );
  }

  void _editComment(ClassUpdateComment comment) {
    // TODO: Implement edit functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit comment functionality coming soon'),
      ),
    );
  }

  void _deleteComment(ClassUpdateComment comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // TODO: Implement actual delete API call
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Delete comment functionality coming soon'),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
        return Padding(
          // Add keyboard padding to push content up when keyboard appears
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount:
                                    _organizeCommentsWithReplies().length,
                                itemBuilder: (context, index) {
                                  final organizedComments =
                                      _organizeCommentsWithReplies();
                                  final displayItem = organizedComments[index];
                                  final currentUserId =
                                      ref.read(authStateProvider).user?.id;

                                  return _buildCommentWithReplies(
                                    displayItem,
                                    currentUserId,
                                  );
                                },
                              ),
              ),

              // Reply indicator (shown when replying)
              if (_replyingToComment != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    color: AppTheme.backgroundColor,
                    border:
                        Border(top: BorderSide(color: AppTheme.borderColor)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.reply,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Replying to ${_replyingToComment!.author?.displayName ?? "User"}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: _cancelReply,
                        icon: const Icon(Icons.close, size: 16),
                        color: AppTheme.textSecondary,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),

              // Comment input area
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppTheme.borderColor)),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // User avatar
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppTheme.primaryColor,
                          backgroundImage:
                              authState.user?.avatarUrl?.isNotEmpty == true
                                  ? NetworkImage(authState.user!.avatarUrl!)
                                  : null,
                          child: authState.user?.avatarUrl?.isEmpty != false
                              ? Text(
                                  authState.user?.firstName.isNotEmpty == true
                                      ? authState.user!.firstName[0]
                                          .toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            focusNode: _focusNode,
                            decoration: InputDecoration(
                              hintText: _replyingToComment != null
                                  ? 'Write your reply with @mention...'
                                  : 'Write a comment...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
