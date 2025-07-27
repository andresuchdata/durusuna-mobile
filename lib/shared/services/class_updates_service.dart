import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/class_update.dart';
import '../models/class_update_comment.dart';
import '../../core/constants/api_constants.dart';
import '../../core/storage/storage_service.dart';
import 'api_service.dart';

class ClassUpdatesService {
  final ApiService _apiService;

  ClassUpdatesService(this._apiService);

  /// Get class updates for a specific class
  Future<List<ClassUpdate>> getClassUpdates(
    String classId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiService.get(
        ApiConstants.getClassUpdates(classId),
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final updates = (data['updates'] as List)
            .map((json) => ClassUpdate.fromJson(json))
            .toList();
        return updates;
      } else {
        throw ApiException(
          message: 'Failed to get class updates',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to get class updates: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Create a new class update
  Future<ClassUpdate> createClassUpdate({
    required String classId,
    String? title,
    required String content,
    required UpdateType updateType,
    List<Map<String, dynamic>>? attachments,
  }) async {
    try {
      final data = {
        'class_id': classId,
        'content': content,
        'update_type': updateType.name,
        if (title != null) 'title': title,
        if (attachments != null) 'attachments': attachments,
      };

      final response = await _apiService.post(
        ApiConstants.createClassUpdate(classId),
        data: data,
      );

      if (response.statusCode == 201) {
        final updateData = response.data['update'] as Map<String, dynamic>;
        return ClassUpdate.fromJson(updateData);
      } else {
        throw ApiException(
          message: 'Failed to create class update',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to create class update: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Update an existing class update
  Future<ClassUpdate> updateClassUpdate({
    required String updateId,
    String? title,
    String? content,
    UpdateType? updateType,
    List<Map<String, dynamic>>? attachments,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (content != null) data['content'] = content;
      if (updateType != null) data['update_type'] = updateType.name;
      if (attachments != null) data['attachments'] = attachments;

      final response = await _apiService.put(
        ApiConstants.updateClassUpdate(updateId),
        data: data,
      );

      if (response.statusCode == 200) {
        final updateData = response.data['update'] as Map<String, dynamic>;
        return ClassUpdate.fromJson(updateData);
      } else {
        throw ApiException(
          message: 'Failed to update class update',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to update class update: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Delete a class update
  Future<void> deleteClassUpdate(String updateId) async {
    try {
      final response = await _apiService.delete(
        ApiConstants.deleteClassUpdate(updateId),
      );

      if (response.statusCode != 200) {
        throw ApiException(
          message: 'Failed to delete class update',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to delete class update: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Get comments for a class update
  Future<List<ClassUpdateComment>> getComments(
    String updateId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _apiService.get(
        ApiConstants.getComments(updateId),
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final comments = (data['comments'] as List)
            .map((json) => ClassUpdateComment.fromJson(json))
            .toList();
        return comments;
      } else {
        throw ApiException(
          message: 'Failed to get comments',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to get comments: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Add a comment to a class update
  Future<ClassUpdateComment> addComment({
    required String updateId,
    required String content,
    String? replyToId,
  }) async {
    try {
      final data = {
        'content': content,
        if (replyToId != null) 'reply_to_id': replyToId,
      };

      final response = await _apiService.post(
        ApiConstants.addComment(updateId),
        data: data,
      );

      if (response.statusCode == 201) {
        final commentData = response.data['comment'] as Map<String, dynamic>;
        return ClassUpdateComment.fromJson(commentData);
      } else {
        throw ApiException(
          message: 'Failed to add comment',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to add comment: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Update a comment
  Future<ClassUpdateComment> updateComment({
    required String commentId,
    required String content,
  }) async {
    try {
      final response = await _apiService.put(
        ApiConstants.updateComment(commentId),
        data: {'content': content},
      );

      if (response.statusCode == 200) {
        final commentData = response.data['comment'] as Map<String, dynamic>;
        return ClassUpdateComment.fromJson(commentData);
      } else {
        throw ApiException(
          message: 'Failed to update comment',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to update comment: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Delete a comment
  Future<void> deleteComment(String commentId) async {
    try {
      final response = await _apiService.delete(
        ApiConstants.deleteComment(commentId),
      );

      if (response.statusCode != 200) {
        throw ApiException(
          message: 'Failed to delete comment',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to delete comment: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Upload attachments for class updates
  Future<List<Map<String, dynamic>>> uploadAttachments(
    List<String> filePaths,
  ) async {
    try {
      // This would typically use FormData for file uploads
      // Implementation depends on how you handle file uploads in your app
      final response = await _apiService.post(
        ApiConstants.uploadAttachments,
        data: {
          'files': filePaths
        }, // Simplified - actual implementation would use FormData
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['attachments'] ?? []);
      } else {
        throw ApiException(
          message: 'Failed to upload attachments',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to upload attachments: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Delete an attachment
  Future<void> deleteAttachment(String key) async {
    try {
      final response = await _apiService.delete(
        ApiConstants.deleteAttachment(key),
      );

      if (response.statusCode != 200) {
        throw ApiException(
          message: 'Failed to delete attachment',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to delete attachment: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Toggle reaction on a class update
  Future<void> toggleReaction({
    required String updateId,
    required String emoji,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.addReaction(updateId),
        data: {'emoji': emoji},
      );

      if (response.statusCode != 200) {
        throw ApiException(
          message: 'Failed to toggle reaction',
          statusCode: response.statusCode ?? 0,
        );
      } else {}
      // Success - no need to return anything, optimistic update is already applied
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to toggle reaction: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Pin/unpin a class update
  Future<ClassUpdate> togglePin(String updateId, bool isPinned) async {
    try {
      final response = await _apiService.put(
        ApiConstants.pinClassUpdate(updateId),
        data: {'is_pinned': isPinned},
      );

      if (response.statusCode == 200) {
        final updateData = response.data['update'] as Map<String, dynamic>;
        return ClassUpdate.fromJson(updateData);
      } else {
        throw ApiException(
          message: 'Failed to toggle pin',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to toggle pin: ${e.toString()}',
        statusCode: 0,
      );
    }
  }
}

// Provider for ClassUpdatesService
final classUpdatesServiceProvider = Provider<ClassUpdatesService>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return ClassUpdatesService(apiService);
});

// Class updates state provider
final classUpdatesProvider = StateNotifierProvider.family<ClassUpdatesNotifier,
    ClassUpdatesState, String>(
  (ref, classId) {
    final service = ref.read(classUpdatesServiceProvider);
    return ClassUpdatesNotifier(service, classId);
  },
);

class ClassUpdatesState {
  final List<ClassUpdate> updates;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentPage;

  ClassUpdatesState({
    this.updates = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 1,
  });

  ClassUpdatesState copyWith({
    List<ClassUpdate>? updates,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentPage,
  }) {
    return ClassUpdatesState(
      updates: updates ?? this.updates,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class ClassUpdatesNotifier extends StateNotifier<ClassUpdatesState> {
  final ClassUpdatesService _service;
  final String _classId;

  ClassUpdatesNotifier(this._service, this._classId)
      : super(ClassUpdatesState()) {
    loadUpdates();
  }

  Future<void> loadUpdates({bool refresh = false}) async {
    if (refresh) {
      state = ClassUpdatesState(isLoading: true);
    } else if (state.isLoading) {
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final updates = await _service.getClassUpdates(
        _classId,
        page: refresh ? 1 : state.currentPage,
      );

      if (refresh) {
        state = state.copyWith(
          updates: updates,
          isLoading: false,
          hasMore: updates.length == 20,
          currentPage: 1,
        );
      } else {
        state = state.copyWith(
          updates: [...state.updates, ...updates],
          isLoading: false,
          hasMore: updates.length == 20,
          currentPage: state.currentPage + 1,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> createUpdate({
    String? title,
    required String content,
    required UpdateType updateType,
    List<Map<String, dynamic>>? attachments,
  }) async {
    try {
      final newUpdate = await _service.createClassUpdate(
        classId: _classId,
        title: title,
        content: content,
        updateType: updateType,
        attachments: attachments,
      );

      state = state.copyWith(
        updates: [newUpdate, ...state.updates],
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateUpdate(ClassUpdate update) async {
    try {
      final updatedUpdate = await _service.updateClassUpdate(
        updateId: update.id,
        title: update.title,
        content: update.content,
        updateType: update.updateType,
        attachments: update.attachments,
      );

      final index = state.updates.indexWhere((u) => u.id == update.id);
      if (index != -1) {
        final newUpdates = [...state.updates];
        newUpdates[index] = updatedUpdate;
        state = state.copyWith(updates: newUpdates);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteUpdate(String updateId) async {
    try {
      await _service.deleteClassUpdate(updateId);
      state = state.copyWith(
        updates: state.updates.where((u) => u.id != updateId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> toggleReaction(String updateId, String emoji) async {
    // Find the update to potentially revert changes
    final index = state.updates.indexWhere((u) => u.id == updateId);
    if (index == -1) return;

    final originalUpdate = state.updates[index];

    // Get current user ID synchronously for immediate optimistic update
    final currentUserId = _getCurrentUserIdSync();
    if (currentUserId == null) return;

    try {
      // Optimistic update: Update UI immediately
      final optimisticReactions =
          Map<String, Reaction>.from(originalUpdate.reactions ?? {});

      if (optimisticReactions.containsKey(emoji)) {
        final reactionData = optimisticReactions[emoji]!;
        final userIds = List<String>.from(reactionData.users);

        if (userIds.contains(currentUserId)) {
          // Remove user's reaction
          userIds.remove(currentUserId);
          if (userIds.isEmpty) {
            optimisticReactions.remove(emoji);
          } else {
            optimisticReactions[emoji] = Reaction(
              count: userIds.length,
              users: userIds,
            );
          }
        } else {
          // Add user's reaction
          userIds.add(currentUserId);
          optimisticReactions[emoji] = Reaction(
            count: userIds.length,
            users: userIds,
          );
        }
      } else {
        // Add new reaction - this should make it appear in the UI
        optimisticReactions[emoji] = Reaction(
          count: 1,
          users: [currentUserId],
        );
      }

      // Update state optimistically (immediate UI feedback)
      final optimisticUpdate =
          originalUpdate.copyWith(reactions: optimisticReactions);

      final newUpdates = [...state.updates];
      newUpdates[index] = optimisticUpdate;

      // Ensure UI rebuilds by creating a new state object
      state = state.copyWith(updates: newUpdates);

      // Call the API to persist the change (but don't overwrite optimistic update)
      await _service.toggleReaction(updateId: updateId, emoji: emoji);

      // Keep the optimistic update since it's already correct
      // The server response only contains reaction data, not the full update
    } catch (e) {
      // Revert to original state on error
      final revertedUpdates = [...state.updates];
      revertedUpdates[index] = originalUpdate;
      state = state.copyWith(
        updates: revertedUpdates,
        error: 'Failed to update reaction: ${e.toString()}',
      );
    }
  }

  String? _getCurrentUserIdSync() {
    try {
      final userData = StorageService.getUser();
      if (userData != null) {
        return userData['id']?.toString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}
