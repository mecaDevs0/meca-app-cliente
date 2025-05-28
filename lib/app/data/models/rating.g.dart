// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rating.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Rating _$RatingFromJson(Map<String, dynamic> json) => Rating(
      id: json['id'] as String?,
      attendanceQuality: (json['attendanceQuality'] as num?)?.toInt(),
      serviceQuality: (json['serviceQuality'] as num?)?.toInt(),
      costBenefit: (json['costBenefit'] as num?)?.toInt(),
      observations: json['observations'] as String?,
      schedulingId: json['schedulingId'] as String?,
      profile: json['profile'] == null
          ? null
          : Profile.fromJson(json['profile'] as Map<String, dynamic>),
      workshopService: json['workshopService'] == null
          ? null
          : Service.fromJson(json['workshopService'] as Map<String, dynamic>),
      workshop: json['workshop'] == null
          ? null
          : MechanicWorkshop.fromJson(json['workshop'] as Map<String, dynamic>),
      vehicle: json['vehicle'] == null
          ? null
          : Vehicle.fromJson(json['vehicle'] as Map<String, dynamic>),
      ratingAverage: (json['ratingAverage'] as num?)?.toInt(),
      created: (json['created'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RatingToJson(Rating instance) => <String, dynamic>{
      'id': instance.id,
      'attendanceQuality': instance.attendanceQuality,
      'serviceQuality': instance.serviceQuality,
      'costBenefit': instance.costBenefit,
      'observations': instance.observations,
      'schedulingId': instance.schedulingId,
      'profile': instance.profile,
      'workshopService': instance.workshopService,
      'workshop': instance.workshop,
      'vehicle': instance.vehicle,
      'ratingAverage': instance.ratingAverage,
      'created': instance.created,
    };
