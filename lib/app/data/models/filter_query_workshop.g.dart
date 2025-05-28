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
      'search': instance.search,
      'serviceTypes': instance.serviceTypes,
      'priceRangeInitial': instance.priceRangeInitial,
      'priceRangeFinal': instance.priceRangeFinal,
      'rating': instance.rating,
      'distance': instance.distance,
      'latUser': instance.latUser,
      'longUser': instance.longUser,
      'dataBlocked': instance.dataBlocked,
      'created': instance.created,
      'workshopName': instance.workshopName,
    };
