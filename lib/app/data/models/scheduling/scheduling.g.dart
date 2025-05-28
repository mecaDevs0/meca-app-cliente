// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduling.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Scheduling _$SchedulingFromJson(Map<String, dynamic> json) => Scheduling(
      workshopServices: (json['workshopServices'] as List<dynamic>?)
          ?.map((e) => WorkshopService.fromJson(e as Map<String, dynamic>))
          .toList(),
      vehicle: json['vehicle'] == null
          ? null
          : VehicleScheduling.fromJson(json['vehicle'] as Map<String, dynamic>),
      observations: json['observations'] as String?,
      date: (json['date'] as num?)?.toInt(),
      status: (json['status'] as num?)?.toInt(),
      workshop: json['workshop'] == null
          ? null
          : WorkshopScheduling.fromJson(
              json['workshop'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SchedulingToJson(Scheduling instance) =>
    <String, dynamic>{
      'workshopServices': instance.workshopServices,
      'vehicle': instance.vehicle,
      'observations': instance.observations,
      'date': instance.date,
      'status': instance.status,
      'workshop': instance.workshop,
    };
