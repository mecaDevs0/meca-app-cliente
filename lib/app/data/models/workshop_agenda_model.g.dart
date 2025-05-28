// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workshop_agenda_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkshopAgendaModel _$WorkshopAgendaModelFromJson(Map<String, dynamic> json) =>
    WorkshopAgendaModel(
      available: json['available'] as bool,
      hour: json['hour'] as String,
      profile: json['profile'] == null
          ? null
          : Profile.fromJson(json['profile'] as Map<String, dynamic>),
      vehicle: json['vehicle'] == null
          ? null
          : Vehicle.fromJson(json['vehicle'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$WorkshopAgendaModelToJson(
        WorkshopAgendaModel instance) =>
    <String, dynamic>{
      'available': instance.available,
      'hour': instance.hour,
      'profile': instance.profile,
      'vehicle': instance.vehicle,
    };
