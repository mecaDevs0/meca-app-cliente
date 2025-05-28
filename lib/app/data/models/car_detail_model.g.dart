// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car_detail_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CarDetailModel _$CarDetailModelFromJson(Map<String, dynamic> json) =>
    CarDetailModel(
      plate: json['plate'] as String? ?? '',
      manufacturer: json['manufacturer'] as String? ?? '',
      model: json['model'] as String? ?? '',
      color: json['color'] as String? ?? '',
      year: json['year'] as String? ?? '',
    );

Map<String, dynamic> _$CarDetailModelToJson(CarDetailModel instance) =>
    <String, dynamic>{
      'plate': instance.plate,
      'manufacturer': instance.manufacturer,
      'model': instance.model,
      'color': instance.color,
      'year': instance.year,
    };
