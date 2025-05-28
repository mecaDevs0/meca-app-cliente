// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationModel _$NotificationModelFromJson(Map<String, dynamic> json) =>
    NotificationModel(
      id: json['id'] as String?,
      title: json['title'] as String?,
      content: json['content'] as String?,
      dateRead: (json['dateRead'] as num?)?.toInt(),
      workshop: json['workshop'] == null
          ? null
          : MechanicWorkshop.fromJson(json['workshop'] as Map<String, dynamic>),
      profile: json['profile'] == null
          ? null
          : Profile.fromJson(json['profile'] as Map<String, dynamic>),
      created: (json['created'] as num?)?.toInt(),
    );

Map<String, dynamic> _$NotificationModelToJson(NotificationModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'content': instance.content,
      'dateRead': instance.dateRead,
      'workshop': instance.workshop,
      'profile': instance.profile,
      'created': instance.created,
    };
