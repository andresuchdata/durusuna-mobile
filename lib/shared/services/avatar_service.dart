import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/api_constants.dart';
import 'media_service.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../models/user.dart';

class AvatarUploadResult {
  final String url;
  final String key;
  final String fileName;

  AvatarUploadResult({
    required this.url,
    required this.key,
    required this.fileName,
  });
}

class AvatarService {
  static final AvatarService _instance = AvatarService._internal();
  factory AvatarService() => _instance;
  AvatarService._internal();

  final MediaService _mediaService = MediaService();
  final ApiService _apiService = ApiService();
  late final AuthService _authService = AuthService(_apiService);

  /// Pick an image for avatar from camera or gallery
  Future<MediaPickerResult?> pickAvatarImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    return await _mediaService.pickImage(
      source: source,
      maxWidth: 800, // Reasonable size for avatars
      maxHeight: 800,
      imageQuality: 85, // Good quality while keeping file size manageable
    );
  }

  /// Upload avatar image to storage
  Future<AvatarUploadResult> uploadAvatar({
    required MediaPickerResult imageResult,
    String folder = 'avatars',
    Function(MediaUploadProgress)? onProgress,
  }) async {
    try {
      // Upload to storage service
      final uploadResult = await _mediaService.uploadSingleFile(
        file: imageResult,
        folder: folder,
        processImage: true, // Enable image processing for avatars
        onProgress: onProgress,
      );

      return AvatarUploadResult(
        url: uploadResult['url'],
        key: uploadResult['key'],
        fileName: uploadResult['fileName'],
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading avatar: $e');
      }
      rethrow;
    }
  }

  /// Update user avatar (currently logged in user)
  Future<User> updateUserAvatar({
    required String avatarUrl,
  }) async {
    try {
      // Use AuthService to update profile with new avatar URL
      final updatedUser = await _authService.updateProfile(
        avatarUrl: avatarUrl,
      );

      return updatedUser;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating user avatar: $e');
      }
      rethrow;
    }
  }

  /// Complete avatar change process: pick, upload, and update profile
  Future<User> changeUserAvatar({
    ImageSource source = ImageSource.gallery,
    Function(MediaUploadProgress)? onProgress,
  }) async {
    try {
      // Step 1: Pick image
      onProgress?.call(MediaUploadProgress(
        progress: 0.1,
        status: 'Selecting image...',
      ));

      final imageResult = await pickAvatarImage(source: source);
      if (imageResult == null) {
        throw Exception('No image selected');
      }

      // Step 2: Upload image
      onProgress?.call(MediaUploadProgress(
        progress: 0.2,
        status: 'Uploading avatar...',
      ));

      final uploadResult = await uploadAvatar(
        imageResult: imageResult,
        onProgress: (uploadProgress) {
          // Map upload progress to 20-80% of total progress
          final mappedProgress = 0.2 + (uploadProgress.progress * 0.6);
          onProgress?.call(MediaUploadProgress(
            progress: mappedProgress,
            status: uploadProgress.status,
            error: uploadProgress.error,
          ));
        },
      );

      // Step 3: Update user profile
      onProgress?.call(MediaUploadProgress(
        progress: 0.9,
        status: 'Updating profile...',
      ));

      final updatedUser = await updateUserAvatar(
        avatarUrl: uploadResult.url,
      );

      onProgress?.call(MediaUploadProgress(
        progress: 1.0,
        status: 'Avatar updated successfully!',
      ));

      return updatedUser;
    } catch (e) {
      onProgress?.call(MediaUploadProgress(
        progress: 0.0,
        status: 'Failed to update avatar',
        error: e.toString(),
      ));
      rethrow;
    }
  }

  /// Remove user avatar (set to null)
  Future<User> removeUserAvatar() async {
    try {
      final updatedUser = await _authService.updateProfile(
        avatarUrl: '', // Empty string to remove avatar
      );

      return updatedUser;
    } catch (e) {
      if (kDebugMode) {
        print('Error removing user avatar: $e');
      }
      rethrow;
    }
  }

  /// Update avatar for any entity via generic API call
  /// This can be used for class avatars, group avatars, etc.
  Future<void> updateEntityAvatar({
    required String entityType, // 'user', 'class', 'group', etc.
    required String entityId,
    required String avatarUrl,
  }) async {
    try {
      await _apiService.put(
        '/${entityType}s/$entityId/avatar',
        data: {'avatar_url': avatarUrl},
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error updating $entityType avatar: $e');
      }
      rethrow;
    }
  }

  /// Complete avatar change for any entity
  Future<void> changeEntityAvatar({
    required String entityType,
    required String entityId,
    ImageSource source = ImageSource.gallery,
    Function(MediaUploadProgress)? onProgress,
  }) async {
    try {
      // Step 1: Pick image
      onProgress?.call(MediaUploadProgress(
        progress: 0.1,
        status: 'Selecting image...',
      ));

      final imageResult = await pickAvatarImage(source: source);
      if (imageResult == null) {
        throw Exception('No image selected');
      }

      // Step 2: Upload image
      onProgress?.call(MediaUploadProgress(
        progress: 0.2,
        status: 'Uploading avatar...',
      ));

      final uploadResult = await uploadAvatar(
        imageResult: imageResult,
        folder: '${entityType}s/avatars', // e.g., 'classes/avatars'
        onProgress: (uploadProgress) {
          final mappedProgress = 0.2 + (uploadProgress.progress * 0.6);
          onProgress?.call(MediaUploadProgress(
            progress: mappedProgress,
            status: uploadProgress.status,
            error: uploadProgress.error,
          ));
        },
      );

      // Step 3: Update entity
      onProgress?.call(MediaUploadProgress(
        progress: 0.9,
        status: 'Updating ${entityType}...',
      ));

      await updateEntityAvatar(
        entityType: entityType,
        entityId: entityId,
        avatarUrl: uploadResult.url,
      );

      onProgress?.call(MediaUploadProgress(
        progress: 1.0,
        status: 'Avatar updated successfully!',
      ));
    } catch (e) {
      onProgress?.call(MediaUploadProgress(
        progress: 0.0,
        status: 'Failed to update avatar',
        error: e.toString(),
      ));
      rethrow;
    }
  }
}
