import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_update_comment.dart';
import 'class_update_comment_card.dart';

// Helper class to represent comments with embedded replies
class CommentDisplayItem {
  final ClassUpdateComment comment;
  final List<ClassUpdateComment> embeddedReplies;

  CommentDisplayItem({
    required this.comment,
    required this.embeddedReplies,
  });
}

enum CommentDisplayMode {
  nested, // Show comments with nested replies (for bottom sheet)
  flat, // Show comments in flat list (for detail page)
}

class CommentList extends StatelessWidget {
  final List<ClassUpdateComment> comments;
  final CommentDisplayMode displayMode;
  final String? currentUserId;
  final bool isLoading;
  final String? error;
  final Set<String> optimisticCommentIds;

  // Callbacks
  final Function(ClassUpdateComment, String)? onReactionTap;
  final Function(ClassUpdateComment)? onAddReaction;
  final Function(ClassUpdateComment)? onReply;
  final Function(ClassUpdateComment)? onEdit;
  final Function(ClassUpdateComment)? onDelete;
  final VoidCallback? onRetry;
  final ScrollController? scrollController;

  const CommentList({
    super.key,
    required this.comments,
    required this.displayMode,
    this.currentUserId,
    this.isLoading = false,
    this.error,
    this.optimisticCommentIds = const {},
    this.onReactionTap,
    this.onAddReaction,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onRetry,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && comments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Failed to load comments',
              style: TextStyle(color: AppTheme.errorColor),
            ),
            const SizedBox(height: 8),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
          ],
        ),
      );
    }

    if (comments.isEmpty) {
      return const Center(
        child: Text(
          'No comments yet.\nBe the first to comment!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    switch (displayMode) {
      case CommentDisplayMode.nested:
        return _buildNestedComments();
      case CommentDisplayMode.flat:
        return _buildFlatComments();
    }
  }

  Widget _buildNestedComments() {
    final organizedComments = _organizeCommentsWithReplies();

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: organizedComments.length,
      itemBuilder: (context, index) {
        final displayItem = organizedComments[index];
        return _buildCommentWithReplies(displayItem);
      },
    );
  }

  Widget _buildFlatComments() {
    // If no scroll controller is provided, render as Column for embedding in other scrollable widgets
    if (scrollController == null) {
      return Column(
        children: comments.map((comment) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ClassUpdateCommentCard(
              comment: comment,
              currentUserId: currentUserId,
              onReply: onReply,
              onEdit: currentUserId == comment.authorId ? onEdit : null,
              onDelete: currentUserId == comment.authorId ? onDelete : null,
              onReactionTap: onReactionTap,
              onAddReaction: onAddReaction,
              showReplies: false, // Flat mode doesn't show nested replies
              level: 0,
              isOptimistic: optimisticCommentIds.contains(comment.id),
            ),
          );
        }).toList(),
      );
    }

    // Otherwise use ListView for independent scrolling
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ClassUpdateCommentCard(
            comment: comment,
            currentUserId: currentUserId,
            onReply: onReply,
            onEdit: currentUserId == comment.authorId ? onEdit : null,
            onDelete: currentUserId == comment.authorId ? onDelete : null,
            onReactionTap: onReactionTap,
            onAddReaction: onAddReaction,
            showReplies: false, // Flat mode doesn't show nested replies
            level: 0,
            isOptimistic: optimisticCommentIds.contains(comment.id),
          ),
        );
      },
    );
  }

  // Helper method to organize comments with embedded replies (for nested mode)
  List<CommentDisplayItem> _organizeCommentsWithReplies() {
    final organized = <CommentDisplayItem>[];
    final Map<String, List<ClassUpdateComment>> repliesMap = {};

    // Group ALL replies by their root parent (traverse up reply chains)
    for (final comment in comments) {
      if (comment.replyToId != null) {
        String rootParentId = _findRootParent(comment, comments);
        repliesMap.putIfAbsent(rootParentId, () => []).add(comment);
      }
    }

    // Find all top-level comments (no parent) and create display items
    // Backend now sorts these newest-first, so maintain that order
    final topLevelComments =
        comments.where((comment) => comment.replyToId == null).toList();

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

  // Build a comment with its embedded replies (for nested mode)
  Widget _buildCommentWithReplies(CommentDisplayItem displayItem) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Parent comment
        ClassUpdateCommentCard(
          comment: displayItem.comment,
          currentUserId: currentUserId,
          level: 0, // Parent is always level 0
          isOptimistic: optimisticCommentIds.contains(displayItem.comment.id),
          onReactionTap: onReactionTap,
          onAddReaction: onAddReaction,
          onReply: onReply,
          onEdit: currentUserId == displayItem.comment.authorId ? onEdit : null,
          onDelete:
              currentUserId == displayItem.comment.authorId ? onDelete : null,
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
                    isOptimistic: optimisticCommentIds.contains(reply.id),
                    onReactionTap: onReactionTap,
                    onAddReaction: onAddReaction,
                    onReply: onReply,
                    onEdit: currentUserId == reply.authorId ? onEdit : null,
                    onDelete: currentUserId == reply.authorId ? onDelete : null,
                  ),
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: 12), // Space between comment groups
      ],
    );
  }
}
