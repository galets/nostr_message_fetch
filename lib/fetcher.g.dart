// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fetcher.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SecureMessage _$SecureMessageFromJson(Map<String, dynamic> json) =>
    SecureMessage(
      json['id'] as String,
      DateTime.parse(json['createdAt'] as String),
      json['from'] as String,
      json['text'] as String,
      json['isRead'] as bool? ?? false,
      json['isSeen'] as bool? ?? false,
    );

Map<String, dynamic> _$SecureMessageToJson(SecureMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'from': instance.from,
      'text': instance.text,
      'createdAt': instance.createdAt.toIso8601String(),
      'isRead': instance.isRead,
      'isSeen': instance.isSeen,
    };
