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

  // Configure Dio with auth headers
  void _configureDio() {
    final token = StorageService.getToken();
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
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
        debugPrint('Image picker cancelled by user');
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
      debugPrint('Error picking image: $e');
      // Check for permission-specific errors
      if (e.toString().contains('Permission') ||
          e.toString().contains('denied') ||
          e.toString().contains('authorization')) {
        debugPrint('Camera/Photo permission denied');
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
      if (kDebugMode) {
        print('Error picking multiple images: $e');
      }
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
      if (kDebugMode) {
        print('Error picking video: $e');
      }
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
          if (kDebugMode) {
            print('File ${file.name} exceeds size limit');
          }
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
      if (kDebugMode) {
        print('Error picking files: $e');
      }
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

      final response = await _dio.post(
        '${ApiConstants.baseUrl}/class-updates/upload-attachments',
        data: formData,
        onSendProgress: (sent, total) {
          final progress = sent / total;
          onProgress?.call(MediaUploadProgress(
            progress: progress,
            status: progress < 1.0 ? 'Uploading...' : 'Processing...',
          ));
        },
      );

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
      onProgress?.call(MediaUploadProgress(
        progress: 0.0,
        status: 'Failed',
        error: e.toString(),
      ));
      rethrow;
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

      final response = await _dio.post(
        '${ApiConstants.baseUrl}/uploads/file',
        data: formData,
        onSendProgress: (sent, total) {
          final progress = sent / total;
          onProgress?.call(MediaUploadProgress(
            progress: progress,
            status: progress < 1.0 ? 'Uploading...' : 'Processing...',
          ));
        },
      );

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
      onProgress?.call(MediaUploadProgress(
        progress: 0.0,
        status: 'Failed',
        error: e.toString(),
      ));
      rethrow;
    }
  }

  /// Delete attachment
  Future<void> deleteAttachment(String key) async {
    _configureDio();

    try {
      await _dio
          .delete('${ApiConstants.baseUrl}/class-updates/attachments/$key');
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting attachment: $e');
      }
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
}
