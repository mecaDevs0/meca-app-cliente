// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Service _$ServiceFromJson(Map<String, dynamic> json) => Service(
      id: json['id'] as String?,
      name: json['name'] as String?,
      quickService: json['quickService'] as bool?,
      minTimeWorkshopAgenda: (json['minTimeScheduling'] as num?)?.toDouble(),
      description: json['description'] as String?,
      photo: json['photo'] as String?,
    );

Map<String, dynamic> _$ServiceToJson(Service instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'quickService': instance.quickService,
      'minTimeScheduling': instance.minTimeWorkshopAgenda,
      'description': instance.description,
      'photo': instance.photo,
    };
