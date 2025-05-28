// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workshop_service.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkshopService _$WorkshopServiceFromJson(Map<String, dynamic> json) =>
    WorkshopService(
      id: json['id'] as String?,
      value: (json['value'] as num?)?.toDouble(),
      estimatedTime: (json['estimatedTime'] as num?)?.toDouble(),
      service: json['service'] == null
          ? null
          : Service.fromJson(json['service'] as Map<String, dynamic>),
      quickService: json['quickService'] as bool?,
      minTimeScheduling: (json['minTimeScheduling'] as num?)?.toDouble(),
      description: json['description'] as String?,
      photo: json['photo'] as String?,
      created: (json['created'] as num?)?.toInt(),
    );

Map<String, dynamic> _$WorkshopServiceToJson(WorkshopService instance) =>
    <String, dynamic>{
      'id': instance.id,
      'value': instance.value,
      'estimatedTime': instance.estimatedTime,
      'quickService': instance.quickService,
      'minTimeScheduling': instance.minTimeScheduling,
      'description': instance.description,
      'photo': instance.photo,
      'created': instance.created,
      'service': instance.service,
    };
