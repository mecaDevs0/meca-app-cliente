// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Vehicle _$VehicleFromJson(Map<String, dynamic> json) => Vehicle(
      id: json['id'] as String?,
      plate: json['plate'] as String?,
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
      km: (json['km'] as num?)?.toInt(),
      color: json['color'] as String?,
      year: json['year'] as String?,
      lastRevisionDate: (json['lastRevisionDate'] as num?)?.toInt(),
      profile: json['profile'] == null
          ? null
          : Profile.fromJson(json['profile'] as Map<String, dynamic>),
      dataBlocked: (json['dataBlocked'] as num?)?.toInt(),
    );

Map<String, dynamic> _$VehicleToJson(Vehicle instance) => <String, dynamic>{
      if (instance.id case final value?) 'id': value,
      if (instance.plate case final value?) 'plate': value,
      if (instance.manufacturer case final value?) 'manufacturer': value,
      if (instance.model case final value?) 'model': value,
      if (instance.km case final value?) 'km': value,
      if (instance.color case final value?) 'color': value,
      if (instance.year case final value?) 'year': value,
      if (instance.lastRevisionDate case final value?)
        'lastRevisionDate': value,
      if (instance.profile case final value?) 'profile': value,
      if (instance.dataBlocked case final value?) 'dataBlocked': value,
    };
