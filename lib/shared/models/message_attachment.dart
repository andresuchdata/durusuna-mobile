import 'package:json_annotation/json_annotation.dart';

part 'message_attachment.g.dart';

@JsonSerializable()
class MessageAttachment {
  final String id;
  @JsonKey(name: 'message_id')
  final String messageId;
  @JsonKey(name: 'file_name')
  final String fileName;
  @JsonKey(name: 'file_type')
  final String fileType;
  @JsonKey(name: 'file_size')
  final int fileSize;
  @JsonKey(name: 'file_url')
  final String fileUrl;
  @JsonKey(name: 'thumbnail_url')
  final String? thumbnailUrl;
  final int? duration;
  final Map<String, dynamic>? metadata;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  MessageAttachment({
    required this.id,
    required this.messageId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.fileUrl,
    this.thumbnailUrl,
    this.duration,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) => 
      _$MessageAttachmentFromJson(json);
  Map<String, dynamic> toJson() => _$MessageAttachmentToJson(this);

  bool get isImage => fileType.startsWith('image/');
  bool get isVideo => fileType.startsWith('video/');
  bool get isAudio => fileType.startsWith('audio/');
  bool get isDocument => !isImage && !isVideo && !isAudio;

  String get fileExtension {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  MessageAttachment copyWith({
    String? id,
    String? messageId,
    String? fileName,
    String? fileType,
    int? fileSize,
    String? fileUrl,
    String? thumbnailUrl,
    int? duration,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MessageAttachment(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      fileUrl: fileUrl ?? this.fileUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageAttachment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MessageAttachment(id: $id, fileName: $fileName, fileType: $fileType)';
} 