// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Config _$ConfigFromJson(Map<String, dynamic> json) => Config(
      privateKey: json['privateKey'] as String,
      relay: json['relay'] as String,
      senders: Map<String, String>.from(json['senders'] as Map),
    );

Map<String, dynamic> _$ConfigToJson(Config instance) => <String, dynamic>{
      'privateKey': instance.privateKey,
      'relay': instance.relay,
      'senders': instance.senders,
    };
