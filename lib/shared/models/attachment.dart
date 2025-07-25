import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'attachment.g.dart';

@JsonSerializable()
class Attachment {
  final String id;
  final String fileName;
  final String originalName;
  final String mimeType;
  final int size;
  final String url;
  final String key;
  final String fileType;
  final bool isImage;
  final bool isVideo;
  final bool isAudio;
  final bool isDocument;
  final String sizeFormatted;
  final String uploadedBy;
  final DateTime uploadedAt;
  final Map<String, dynamic>? metadata;

  const Attachment({
    required this.id,
    required this.fileName,
    required this.originalName,
    required this.mimeType,
    required this.size,
    required this.url,
    required this.key,
    required this.fileType,
    this.isImage = false,
    this.isVideo = false,
    this.isAudio = false,
    this.isDocument = false,
    required this.sizeFormatted,
    required this.uploadedBy,
    required this.uploadedAt,
    this.metadata,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    try {
      // Safely parse JSON with null checks and defaults
      return Attachment(
        id: json['id']?.toString() ?? '',
        fileName:
            json['fileName']?.toString() ?? json['filename']?.toString() ?? '',
        originalName: json['originalName']?.toString() ??
            json['original_name']?.toString() ??
            '',
        mimeType: json['mimeType']?.toString() ??
            json['mime_type']?.toString() ??
            'application/octet-stream',
        size: json['size'] is int
            ? json['size']
            : int.tryParse(json['size']?.toString() ?? '0') ?? 0,
        url: json['url']?.toString() ?? '',
        key: json['key']?.toString() ?? '',
        fileType: json['fileType']?.toString() ??
            json['file_type']?.toString() ??
            'other',
        isImage: json['isImage'] == true || json['is_image'] == true,
        isVideo: json['isVideo'] == true || json['is_video'] == true,
        isAudio: json['isAudio'] == true || json['is_audio'] == true,
        isDocument: json['isDocument'] == true || json['is_document'] == true,
        sizeFormatted: json['sizeFormatted']?.toString() ??
            json['size_formatted']?.toString() ??
            '0 B',
        uploadedBy: json['uploadedBy']?.toString() ??
            json['uploaded_by']?.toString() ??
            '',
        uploadedAt: json['uploadedAt'] != null
            ? DateTime.tryParse(json['uploadedAt'].toString()) ?? DateTime.now()
            : json['uploaded_at'] != null
                ? DateTime.tryParse(json['uploaded_at'].toString()) ??
                    DateTime.now()
                : DateTime.now(),
        metadata:
            json['metadata'] is Map<String, dynamic> ? json['metadata'] : null,
      );
    } catch (e) {
      debugPrint('Error parsing attachment JSON: $e');
      // Return a minimal valid attachment object
      return Attachment(
        id: json['id']?.toString() ?? 'unknown',
        fileName: json['fileName']?.toString() ?? 'unknown',
        originalName: json['originalName']?.toString() ?? 'unknown',
        mimeType: 'application/octet-stream',
        size: 0,
        url: '',
        key: '',
        fileType: 'other',
        sizeFormatted: '0 B',
        uploadedBy: '',
        uploadedAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() => _$AttachmentToJson(this);

  /// Get a human-readable description of the file type
  String get fileTypeDescription {
    switch (fileType) {
      case 'image':
        return 'Image';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Audio';
      case 'document':
        return 'Document';
      default:
        return 'File';
    }
  }

  /// Get file extension from the original name
  String get fileExtension {
    final parts = originalName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  /// Get properly formatted file size with fallback calculation
  String get sizeFormattedWithFallback {
    // If we have a valid sizeFormatted field and it's not "0 B", use it
    if (sizeFormatted.isNotEmpty &&
        sizeFormatted != '0 B' &&
        !sizeFormatted.startsWith('0.0')) {
      return sizeFormatted;
    }

    // Otherwise, calculate it from the size field
    if (size <= 0) return '0 B';

    const List<String> suffixes = ['B', 'KB', 'MB', 'GB'];
    int suffixIndex = 0;
    double fileSize = size.toDouble();

    while (fileSize >= 1024 && suffixIndex < suffixes.length - 1) {
      fileSize /= 1024;
      suffixIndex++;
    }

    return '${fileSize.toStringAsFixed(fileSize < 10 ? 1 : 0)} ${suffixes[suffixIndex]}';
  }

  /// Check if this is a media file (image or video)
  bool get isMedia => isImage || isVideo;

  /// Get thumbnail URL if available
  String? get thumbnailUrl {
    if (metadata != null && metadata!.containsKey('thumbnailUrl')) {
      return metadata!['thumbnailUrl'] as String?;
    }
    return isImage ? url : null; // For images, use the main URL as thumbnail
  }

  /// Get display name (truncated if too long)
  String getDisplayName({int maxLength = 30}) {
    if (originalName.length <= maxLength) return originalName;
    final extension = fileExtension;
    final nameWithoutExt =
        originalName.substring(0, originalName.lastIndexOf('.'));
    final truncated =
        nameWithoutExt.substring(0, maxLength - extension.length - 4);
    return '$truncated...$extension';
  }

  /// Create a copy with updated properties
  Attachment copyWith({
    String? id,
    String? fileName,
    String? originalName,
    String? mimeType,
    int? size,
    String? url,
    String? key,
    String? fileType,
    bool? isImage,
    bool? isVideo,
    bool? isAudio,
    bool? isDocument,
    String? sizeFormatted,
    String? uploadedBy,
    DateTime? uploadedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Attachment(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      originalName: originalName ?? this.originalName,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      url: url ?? this.url,
      key: key ?? this.key,
      fileType: fileType ?? this.fileType,
      isImage: isImage ?? this.isImage,
      isVideo: isVideo ?? this.isVideo,
      isAudio: isAudio ?? this.isAudio,
      isDocument: isDocument ?? this.isDocument,
      sizeFormatted: sizeFormatted ?? this.sizeFormatted,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Attachment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Attachment(id: $id, fileName: $fileName, fileType: $fileType)';
}
