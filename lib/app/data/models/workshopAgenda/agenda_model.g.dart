// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agenda_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgendaModel _$AgendaModelFromJson(Map<String, dynamic> json) => AgendaModel(
      monday: WeekDayModel.fromJson(json['monday'] as Map<String, dynamic>),
      tuesday: WeekDayModel.fromJson(json['tuesday'] as Map<String, dynamic>),
      wednesday:
          WeekDayModel.fromJson(json['wednesday'] as Map<String, dynamic>),
      thursday: WeekDayModel.fromJson(json['thursday'] as Map<String, dynamic>),
      friday: WeekDayModel.fromJson(json['friday'] as Map<String, dynamic>),
      saturday: WeekDayModel.fromJson(json['saturday'] as Map<String, dynamic>),
      sunday: WeekDayModel.fromJson(json['sunday'] as Map<String, dynamic>),
      id: json['id'] as String?,
    );

Map<String, dynamic> _$AgendaModelToJson(AgendaModel instance) =>
    <String, dynamic>{
      'monday': instance.monday,
      'tuesday': instance.tuesday,
      'wednesday': instance.wednesday,
      'thursday': instance.thursday,
      'friday': instance.friday,
      'saturday': instance.saturday,
      'sunday': instance.sunday,
      'id': instance.id,
    };
