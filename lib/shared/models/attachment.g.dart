// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Attachment _$AttachmentFromJson(Map<String, dynamic> json) => Attachment(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      originalName: json['originalName'] as String,
      mimeType: json['mimeType'] as String,
      size: (json['size'] as num).toInt(),
      url: json['url'] as String,
      key: json['key'] as String,
      fileType: json['fileType'] as String,
      isImage: json['isImage'] as bool? ?? false,
      isVideo: json['isVideo'] as bool? ?? false,
      isAudio: json['isAudio'] as bool? ?? false,
      isDocument: json['isDocument'] as bool? ?? false,
      sizeFormatted: json['sizeFormatted'] as String,
      uploadedBy: json['uploadedBy'] as String,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$AttachmentToJson(Attachment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fileName': instance.fileName,
      'originalName': instance.originalName,
      'mimeType': instance.mimeType,
      'size': instance.size,
      'url': instance.url,
      'key': instance.key,
      'fileType': instance.fileType,
      'isImage': instance.isImage,
      'isVideo': instance.isVideo,
      'isAudio': instance.isAudio,
      'isDocument': instance.isDocument,
      'sizeFormatted': instance.sizeFormatted,
      'uploadedBy': instance.uploadedBy,
      'uploadedAt': instance.uploadedAt.toIso8601String(),
      'metadata': instance.metadata,
    };
