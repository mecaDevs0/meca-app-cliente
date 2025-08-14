// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mechanic_workshop.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MechanicWorkshop _$MechanicWorkshopFromJson(Map<String, dynamic> json) =>
    MechanicWorkshop(
      id: json['_id'] as String?,
      fullName: json['FullName'] as String?,
      companyName: json['CompanyName'] as String?,
      phone: json['Phone'] as String?,
      cnpj: json['Cnpj'] as String?,
      zipCode: json['ZipCode'] as String?,
      streetAddress: json['StreetAddress'] as String?,
      number: json['Number'] as String?,
      cityName: json['CityName'] as String?,
      cityId: json['CityId'] as String?,
      stateName: json['StateName'] as String?,
      stateUf: json['StateUf'] as String?,
      stateId: json['StateId'] as String?,
      neighborhood: json['Neighborhood'] as String?,
      complement: json['Complement'] as String?,
      latitude: (json['Latitude'] as num?)?.toDouble(),
      longitude: (json['Longitude'] as num?)?.toDouble(),
      openingHours: json['OpeningHours'] as String?,
      photo: json['Photo'] as String?,
      meiCard: json['MeiCard'] as String?,
      email: json['Email'] as String?,
      password: json['Password'] as String?,
      rating: (json['Rating'] as num?)?.toInt(),
      distance: (json['Distance'] as num?)?.toInt(),
      reason: json['Reason'] as String?,
    )..accountableName = json['AccountableName'] as String?;

Map<String, dynamic> _$MechanicWorkshopToJson(MechanicWorkshop instance) =>
    <String, dynamic>{
      '_id': instance.id,
      'FullName': instance.fullName,
      'CompanyName': instance.companyName,
      'Phone': instance.phone,
      'Cnpj': instance.cnpj,
      'ZipCode': instance.zipCode,
      'StreetAddress': instance.streetAddress,
      'Number': instance.number,
      'CityName': instance.cityName,
      'CityId': instance.cityId,
      'StateName': instance.stateName,
      'StateUf': instance.stateUf,
      'StateId': instance.stateId,
      'Neighborhood': instance.neighborhood,
      'Complement': instance.complement,
      'Latitude': instance.latitude,
      'Longitude': instance.longitude,
      'OpeningHours': instance.openingHours,
      'Photo': instance.photo,
      'MeiCard': instance.meiCard,
      'Email': instance.email,
      'Password': instance.password,
      'Rating': instance.rating,
      'Distance': instance.distance,
      'Reason': instance.reason,
      'AccountableName': instance.accountableName,
    };
