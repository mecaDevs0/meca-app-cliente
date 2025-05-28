// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workshop_service.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkshopService _$WorkshopServiceFromJson(Map<String, dynamic> json) =>
    WorkshopService(
      id: json['id'] as String?,
      name: json['name'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      isApproved: json['isApproved'] as bool?,
    );

Map<String, dynamic> _$WorkshopServiceToJson(WorkshopService instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'price': instance.price,
      'isApproved': instance.isApproved,
    };
