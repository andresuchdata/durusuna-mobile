import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import '../../core/constants/api_constants.dart';
import '../models/attachment.dart';
import '../../core/storage/storage_service.dart';

enum MediaType { image, video, audio, document, other }

class MediaPickerResult {
  final String? path;
  final String name;
  final int size;
  final String? mimeType;
  final Uint8List? bytes;
  final MediaType type;

  MediaPickerResult({
    this.path,
    required this.name,
    required this.size,
    this.mimeType,
    this.bytes,
    required this.type,
  });
}

class MediaUploadProgress {
  final double progress;
  final String status;
  final String? error;

  MediaUploadProgress({
    required this.progress,
    required this.status,
    this.error,
  });

  bool get isCompleted => progress >= 1.0 && error == null;
  bool get hasError => error != null;
}

class MediaService {
  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;
  MediaService._internal();

  final ImagePicker _imagePicker = ImagePicker();
  final Dio _dio = Dio();

  // Configure Dio with auth headers and optimized settings for Sevalla
  void _configureDio() {
    final token = StorageService.getToken();
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }

    // Optimize timeouts for Sevalla storage uploads
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.sendTimeout =
        const Duration(minutes: 5); // Longer for large files

    // Enable persistent connections for better performance
    _dio.options.persistentConnection = true;
  }

  /// Pick single image from camera or gallery
  Future<MediaPickerResult?> pickImage({
    ImageSource source = ImageSource.gallery,
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
      );

      if (image == null) {
        return null;
      }

      final bytes = await image.readAsBytes();
      final mimeType = lookupMimeType(image.path) ?? 'image/jpeg';

      return MediaPickerResult(
        path: image.path,
        name: path.basename(image.path),
        size: bytes.length,
        mimeType: mimeType,
        bytes: bytes,
        type: MediaType.image,
      );
    } catch (e) {
      // Check for permission-specific errors
      if (e.toString().contains('Permission') ||
          e.toString().contains('denied') ||
          e.toString().contains('authorization')) {
        // Camera/Photo permission denied
      }
      return null;
    }
  }

  /// Pick multiple images
  Future<List<MediaPickerResult>> pickMultipleImages({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    int limit = 5,
  }) async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
        limit: limit,
      );

      final List<MediaPickerResult> results = [];

      for (final image in images) {
        final bytes = await image.readAsBytes();
        final mimeType = lookupMimeType(image.path) ?? 'image/jpeg';

        results.add(MediaPickerResult(
          path: image.path,
          name: path.basename(image.path),
          size: bytes.length,
          mimeType: mimeType,
          bytes: bytes,
          type: MediaType.image,
        ));
      }

      return results;
    } catch (e) {
      return [];
    }
  }

  /// Pick video
  Future<MediaPickerResult?> pickVideo({
    ImageSource source = ImageSource.gallery,
    Duration? maxDuration,
  }) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: source,
        maxDuration: maxDuration,
      );

      if (video == null) return null;

      final bytes = await video.readAsBytes();
      final mimeType = lookupMimeType(video.path) ?? 'video/mp4';

      return MediaPickerResult(
        path: video.path,
        name: path.basename(video.path),
        size: bytes.length,
        mimeType: mimeType,
        bytes: bytes,
        type: MediaType.video,
      );
    } catch (e) {
      return null;
    }
  }

  /// Pick files (documents, audio, etc.)
  Future<List<MediaPickerResult>> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = true,
    int? fileSizeLimit,
  }) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        withData: true, // Load file data for upload
      );

      if (result == null || result.files.isEmpty) return [];

      final List<MediaPickerResult> mediaResults = [];

      for (final file in result.files) {
        if (file.bytes == null && file.path == null) continue;

        // Check file size limit
        if (fileSizeLimit != null && file.size > fileSizeLimit) {
          continue;
        }

        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes == null) continue;

        final mimeType =
            lookupMimeType(file.name) ?? 'application/octet-stream';
        final mediaType = _getMediaTypeFromMime(mimeType);

        mediaResults.add(MediaPickerResult(
          path: file.path,
          name: file.name,
          size: file.size,
          mimeType: mimeType,
          bytes: bytes,
          type: mediaType,
        ));
      }

      return mediaResults;
    } catch (e) {
      return [];
    }
  }

  /// Upload files to class updates
  Future<List<Attachment>> uploadClassUpdateAttachments({
    required List<MediaPickerResult> files,
    required String classId,
    Function(MediaUploadProgress)? onProgress,
  }) async {
    _configureDio();

    try {
      final formData = FormData();

      // Add class_id
      formData.fields.add(MapEntry('class_id', classId));

      // Add files
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final multipartFile = MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
          contentType:
              DioMediaType.parse(file.mimeType ?? 'application/octet-stream'),
        );
        formData.files.add(MapEntry('attachments', multipartFile));
      }

      final response = await _retryUpload(() => _dio.post(
            '${ApiConstants.baseUrl}/class-updates/upload-attachments',
            data: formData,
            onSendProgress: (sent, total) {
              final progress = sent / total;
              onProgress?.call(MediaUploadProgress(
                progress: progress,
                status: progress < 1.0 ? 'Uploading...' : 'Processing...',
              ));
            },
          ));

      if (response.statusCode == 200) {
        final data = response.data;
        final attachments = (data['attachments'] as List)
            .map((json) => Attachment.fromJson(json))
            .toList();

        onProgress?.call(MediaUploadProgress(
          progress: 1.0,
          status: 'Completed',
        ));

        return attachments;
      } else {
        throw Exception('Upload failed: ${response.statusMessage}');
      }
    } catch (e) {
      // Enhanced error handling for Sevalla storage
      String userFriendlyMessage = _getUploadErrorMessage(e.toString());

      onProgress?.call(MediaUploadProgress(
        progress: 0.0,
        status: 'Failed',
        error: userFriendlyMessage,
      ));

      throw Exception(userFriendlyMessage);
    }
  }

  /// Upload single file
  Future<Map<String, dynamic>> uploadSingleFile({
    required MediaPickerResult file,
    String folder = 'general',
    bool processImage = true,
    Function(MediaUploadProgress)? onProgress,
  }) async {
    _configureDio();

    try {
      final formData = FormData();

      formData.fields.add(MapEntry('folder', folder));
      formData.fields.add(MapEntry('processImage', processImage.toString()));

      final multipartFile = MultipartFile.fromBytes(
        file.bytes!,
        filename: file.name,
        contentType:
            DioMediaType.parse(file.mimeType ?? 'application/octet-stream'),
      );
      formData.files.add(MapEntry('file', multipartFile));

      final response = await _retryUpload(() => _dio.post(
            '${ApiConstants.baseUrl}/uploads/file',
            data: formData,
            onSendProgress: (sent, total) {
              final progress = sent / total;
              onProgress?.call(MediaUploadProgress(
                progress: progress,
                status: progress < 1.0 ? 'Uploading...' : 'Processing...',
              ));
            },
          ));

      if (response.statusCode == 200) {
        onProgress?.call(MediaUploadProgress(
          progress: 1.0,
          status: 'Completed',
        ));
        return response.data['file'];
      } else {
        throw Exception('Upload failed: ${response.statusMessage}');
      }
    } catch (e) {
      // Enhanced error handling for Sevalla storage
      String userFriendlyMessage = _getUploadErrorMessage(e.toString());

      onProgress?.call(MediaUploadProgress(
        progress: 0.0,
        status: 'Failed',
        error: userFriendlyMessage,
      ));

      throw Exception(userFriendlyMessage);
    }
  }

  /// Delete attachment
  Future<void> deleteAttachment(String key) async {
    _configureDio();

    try {
      await _dio
          .delete('${ApiConstants.baseUrl}/class-updates/attachments/$key');
    } catch (e) {
      rethrow;
    }
  }

  /// Show media picker options
  Future<List<MediaPickerResult>?> showMediaPicker({
    required bool allowImages,
    required bool allowVideos,
    required bool allowDocuments,
    bool allowMultiple = true,
    int? fileSizeLimit,
  }) async {
    final List<MediaPickerResult> results = [];

    // For now, we'll pick images first, then files
    // In a real app, you'd show a bottom sheet with options

    if (allowImages) {
      if (allowMultiple) {
        final images = await pickMultipleImages(limit: 5);
        results.addAll(images);
      } else {
        final image = await pickImage();
        if (image != null) results.add(image);
      }
    }

    if (allowDocuments && results.length < 5) {
      final files = await pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
        allowMultiple: allowMultiple && results.isEmpty,
        fileSizeLimit: fileSizeLimit,
      );
      results.addAll(files);
    }

    return results.isEmpty ? null : results;
  }

  /// Get media type from MIME type
  MediaType _getMediaTypeFromMime(String mimeType) {
    if (mimeType.startsWith('image/')) return MediaType.image;
    if (mimeType.startsWith('video/')) return MediaType.video;
    if (mimeType.startsWith('audio/')) return MediaType.audio;
    if (mimeType.contains('pdf') ||
        mimeType.contains('document') ||
        mimeType.contains('text')) {
      return MediaType.document;
    }
    return MediaType.other;
  }

  /// Format file size
  String formatFileSize(int bytes) {
    if (bytes == 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(size < 10 ? 1 : 0)} ${suffixes[i]}';
  }

  /// Validate file size and type
  bool validateFile(
    MediaPickerResult file, {
    int? maxSize,
    List<String>? allowedTypes,
  }) {
    if (maxSize != null && file.size > maxSize) {
      return false;
    }

    if (allowedTypes != null && file.mimeType != null) {
      return allowedTypes.any((type) => file.mimeType!.startsWith(type));
    }

    return true;
  }

  /// Validate file for Sevalla storage with specific limits
  Map<String, dynamic> validateForSevalla(MediaPickerResult file) {
    const int maxImageSize = 5 * 1024 * 1024; // 5MB
    const int maxVideoSize = 50 * 1024 * 1024; // 50MB
    const int maxDocumentSize = 5 * 1024 * 1024; // 5MB

    final allowedTypes = [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
      'video/mp4',
      'video/quicktime',
      'video/x-msvideo',
      'video/avi',
      'video/webm',
      'audio/mpeg',
      'audio/wav',
      'audio/mp4',
      'audio/aac',
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'text/plain',
    ];

    // Check file type
    if (file.mimeType != null && !allowedTypes.contains(file.mimeType)) {
      return {
        'isValid': false,
        'error':
            'File type ${file.mimeType} is not supported. Please choose an image, video, audio, or document file.'
      };
    }

    // Check file size based on type
    int sizeLimit = maxDocumentSize;
    if (file.mimeType?.startsWith('image/') == true) {
      sizeLimit = maxImageSize;
    } else if (file.mimeType?.startsWith('video/') == true) {
      sizeLimit = maxVideoSize;
    }

    if (file.size > sizeLimit) {
      final sizeLimitFormatted = formatFileSize(sizeLimit);
      final fileSizeFormatted = formatFileSize(file.size);
      return {
        'isValid': false,
        'error':
            'File size $fileSizeFormatted exceeds the limit of $sizeLimitFormatted for this file type.'
      };
    }

    return {'isValid': true};
  }

  /// Retry upload with exponential backoff
  Future<T> _retryUpload<T>(
    Future<T> Function() uploadFunction, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        return await uploadFunction();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          rethrow;
        }

        // Check if error is retryable
        final errorString = e.toString();
        if (errorString.contains('timeout') ||
            errorString.contains('NetworkingError') ||
            errorString.contains('SocketException') ||
            errorString.contains('500')) {
          // Wait with exponential backoff
          final delay = Duration(
            milliseconds:
                (initialDelay.inMilliseconds * (1 << attempt)).toInt(),
          );
          await Future.delayed(delay);
        } else {
          // Non-retryable error, fail immediately
          rethrow;
        }
      }
    }
    throw Exception('Upload failed after $maxRetries attempts');
  }

  /// Get user-friendly error message for upload failures
  String _getUploadErrorMessage(String error) {
    // Map backend Sevalla errors to user-friendly messages
    if (error.contains('Network connection failed')) {
      return 'Network connection issue. Please check your internet and try again.';
    } else if (error.contains('Storage authentication failed')) {
      return 'Storage service temporarily unavailable. Please try again later.';
    } else if (error.contains('Storage bucket not found')) {
      return 'Storage service configuration error. Please contact support.';
    } else if (error.contains('Access denied to storage')) {
      return 'Permission denied. Please check your account permissions.';
    } else if (error.contains('File is too large')) {
      return 'File is too large. Please choose a smaller file (max 5MB for most files, 50MB for videos).';
    } else if (error.contains('File not found')) {
      return 'File not found. It may have been deleted or moved.';
    } else if (error.contains('Invalid file type')) {
      return 'File type not supported. Please choose an image, video, or document file.';
    } else if (error.contains('timeout') ||
        error.contains('TimeoutException')) {
      return 'Upload timed out. Please check your connection and try again.';
    } else if (error.contains('No internet connection') ||
        error.contains('SocketException')) {
      return 'No internet connection. Please check your network and try again.';
    } else if (error.contains('500') ||
        error.contains('Internal Server Error')) {
      return 'Server error. Please try again in a few moments.';
    } else if (error.contains('413') || error.contains('Payload Too Large')) {
      return 'File is too large for upload. Please choose a smaller file.';
    } else if (error.contains('401') || error.contains('Unauthorized')) {
      return 'Authentication expired. Please log in again.';
    } else if (error.contains('403') || error.contains('Forbidden')) {
      return 'You don\'t have permission to upload files here.';
    }

    // Default error message
    return 'Upload failed. Please try again or contact support if the problem persists.';
  }
}
