// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mechanic_workshop.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MechanicWorkshop _$MechanicWorkshopFromJson(Map<String, dynamic> json) =>
    MechanicWorkshop(
      id: json['id'] as String?,
      fullName: json['fullName'] as String?,
      companyName: json['companyName'] as String?,
      phone: json['phone'] as String?,
      cnpj: json['cnpj'] as String?,
      zipCode: json['zipCode'] as String?,
      streetAddress: json['streetAddress'] as String?,
      number: json['number'] as String?,
      cityName: json['cityName'] as String?,
      cityId: json['cityId'] as String?,
      stateName: json['stateName'] as String?,
      stateUf: json['stateUf'] as String?,
      stateId: json['stateId'] as String?,
      neighborhood: json['neighborhood'] as String?,
      complement: json['complement'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      openingHours: json['openingHours'] as String?,
      photo: json['photo'] as String?,
      meiCard: json['meiCard'] as String?,
      email: json['email'] as String?,
      password: json['password'] as String?,
      rating: (json['rating'] as num?)?.toInt(),
      distance: (json['distance'] as num?)?.toInt(),
      reason: json['reason'] as String?,
    );

Map<String, dynamic> _$MechanicWorkshopToJson(MechanicWorkshop instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fullName': instance.fullName,
      'companyName': instance.companyName,
      'phone': instance.phone,
      'cnpj': instance.cnpj,
      'zipCode': instance.zipCode,
      'streetAddress': instance.streetAddress,
      'number': instance.number,
      'cityName': instance.cityName,
      'cityId': instance.cityId,
      'stateName': instance.stateName,
      'stateUf': instance.stateUf,
      'stateId': instance.stateId,
      'neighborhood': instance.neighborhood,
      'complement': instance.complement,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'openingHours': instance.openingHours,
      'photo': instance.photo,
      'meiCard': instance.meiCard,
      'email': instance.email,
      'password': instance.password,
      'rating': instance.rating,
      'distance': instance.distance,
      'reason': instance.reason,
    };
