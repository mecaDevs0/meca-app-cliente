// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filter_query_workshop.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FilterQueryWorkshop _$FilterQueryWorkshopFromJson(Map<String, dynamic> json) =>
    FilterQueryWorkshop(
      page: (json['page'] as num?)?.toInt(),
      limit: (json['limit'] as num?)?.toInt(),
      search: json['search'] as String?,
      serviceTypes: (json['serviceTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      priceRangeInitial: (json['priceRangeInitial'] as num?)?.toDouble(),
      priceRangeFinal: (json['priceRangeFinal'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toInt(),
      distance: (json['distance'] as num?)?.toInt(),
      latUser: (json['latUser'] as num?)?.toDouble(),
      longUser: (json['longUser'] as num?)?.toDouble(),
      dataBlocked: (json['dataBlocked'] as num?)?.toInt(),
      created: (json['created'] as num?)?.toInt(),
      workshopName: json['workshopName'] as String?,
    );

Map<String, dynamic> _$FilterQueryWorkshopToJson(
        FilterQueryWorkshop instance) =>
    <String, dynamic>{
      'page': instance.page,
      'limit': instance.limit,
      if (instance.search case final value?) 'search': value,
      if (instance.serviceTypes case final value?) 'serviceTypes': value,
      if (instance.priceRangeInitial case final value?)
        'priceRangeInitial': value,
      if (instance.priceRangeFinal case final value?) 'priceRangeFinal': value,
      if (instance.rating case final value?) 'rating': value,
      if (instance.distance case final value?) 'distance': value,
      if (instance.latUser case final value?) 'latUser': value,
      if (instance.longUser case final value?) 'longUser': value,
      'dataBlocked': instance.dataBlocked,
      if (instance.created case final value?) 'created': value,
      if (instance.workshopName case final value?) 'workshopName': value,
    };
