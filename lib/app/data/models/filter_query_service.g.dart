// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filter_query_service.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FilterQueryService _$FilterQueryServiceFromJson(Map<String, dynamic> json) =>
    FilterQueryService(
      page: (json['page'] as num?)?.toInt(),
      limit: (json['limit'] as num?)?.toInt(),
      name: json['name'] as String?,
      serviceTypes: (json['serviceTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      rating: (json['rating'] as num?)?.toInt(),
      distance: (json['distance'] as num?)?.toInt(),
      latUser: (json['latUser'] as num?)?.toDouble(),
      longUser: (json['longUser'] as num?)?.toDouble(),
      dataBlocked: (json['dataBlocked'] as num?)?.toInt(),
      created: (json['created'] as num?)?.toInt(),
    );

Map<String, dynamic> _$FilterQueryServiceToJson(FilterQueryService instance) =>
    <String, dynamic>{
      'page': instance.page,
      'limit': instance.limit,
      'name': instance.name,
      'serviceTypes': instance.serviceTypes,
      if (instance.rating case final value?) 'rating': value,
      if (instance.distance case final value?) 'distance': value,
      if (instance.latUser case final value?) 'latUser': value,
      if (instance.longUser case final value?) 'longUser': value,
      'dataBlocked': instance.dataBlocked,
      if (instance.created case final value?) 'created': value,
    };
