import 'package:json_annotation/json_annotation.dart';

part 'mechanic_workshop.g.dart';

@JsonSerializable()
class MechanicWorkshop {
  MechanicWorkshop({
    this.id,
    this.fullName,
    this.companyName,
    this.phone,
    this.cnpj,
    this.zipCode,
    this.streetAddress,
    this.number,
    this.cityName,
    this.cityId,
    this.stateName,
    this.stateUf,
    this.stateId,
    this.neighborhood,
    this.complement,
    this.latitude,
    this.longitude,
    this.openingHours,
    this.photo,
    this.meiCard,
    this.email,
    this.password,
    this.rating,
    this.distance,
    this.reason,
  });

  factory MechanicWorkshop.fromJson(Map<String, dynamic> json) =>
      _$MechanicWorkshopFromJson(json);

  MechanicWorkshop.empty() {
    fullName = '';
    companyName = '';
    phone = '';
    cnpj = '';
    zipCode = '';
    streetAddress = '';
    number = '';
    cityName = '';
    cityId = '';
    stateName = '';
    stateUf = '';
    stateId = '';
    neighborhood = '';
    complement = '';
    latitude = 0;
    longitude = 0;
    openingHours = '';
    phone = '';
    meiCard = '';
    email = '';
    password = '';
    rating = 0;
    distance = 0;
    reason = '';
  }

  String? id;
  String? fullName;
  String? companyName;
  String? phone;
  String? cnpj;
  String? zipCode;
  String? streetAddress;
  String? number;
  String? cityName;
  String? cityId;
  String? stateName;
  String? stateUf;
  String? stateId;
  String? neighborhood;
  String? complement;
  double? latitude;
  double? longitude;
  String? openingHours;
  String? photo;
  String? meiCard;
  String? email;
  String? password;
  int? rating;
  int? distance;
  String? reason;

  Map<String, dynamic> toJson() => _$MechanicWorkshopToJson(this);
}
