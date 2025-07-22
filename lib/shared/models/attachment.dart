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

  factory Attachment.fromJson(Map<String, dynamic> json) =>
      _$AttachmentFromJson(json);
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
