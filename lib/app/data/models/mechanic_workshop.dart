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
    this.workshopAgendaValid,
    this.workshopServicesValid,
    this.dataBankValid,
    this.status,
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

  @JsonKey(name: '_id')
  String? id;
  
  @JsonKey(name: 'FullName')
  String? fullName;
  
  @JsonKey(name: 'CompanyName')
  String? companyName;
  
  @JsonKey(name: 'Phone')
  String? phone;
  
  @JsonKey(name: 'Cnpj')
  String? cnpj;
  
  @JsonKey(name: 'ZipCode')
  String? zipCode;
  
  @JsonKey(name: 'StreetAddress')
  String? streetAddress;
  
  @JsonKey(name: 'Number')
  String? number;
  
  @JsonKey(name: 'CityName')
  String? cityName;
  
  @JsonKey(name: 'CityId')
  String? cityId;
  
  @JsonKey(name: 'StateName')
  String? stateName;
  
  @JsonKey(name: 'StateUf')
  String? stateUf;
  
  @JsonKey(name: 'StateId')
  String? stateId;
  
  @JsonKey(name: 'Neighborhood')
  String? neighborhood;
  
  @JsonKey(name: 'Complement')
  String? complement;
  
  @JsonKey(name: 'Latitude')
  double? latitude;
  
  @JsonKey(name: 'Longitude')
  double? longitude;
  
  @JsonKey(name: 'OpeningHours')
  String? openingHours;
  
  @JsonKey(name: 'Photo')
  String? photo;
  
  @JsonKey(name: 'MeiCard')
  String? meiCard;
  
  @JsonKey(name: 'Email')
  String? email;
  
  @JsonKey(name: 'Password')
  String? password;
  
  @JsonKey(name: 'Rating')
  int? rating;
  
  @JsonKey(name: 'Distance')
  int? distance;
  
  @JsonKey(name: 'Reason')
  String? reason;

  @JsonKey(name: 'AccountableName')
  String? accountableName;

  // CORREÇÃO CRÍTICA: Propriedades de validação que a API retorna
  // mas que não estavam sendo capturadas pelo modelo
  @JsonKey(name: 'workshopAgendaValid')
  bool? workshopAgendaValid;
  
  @JsonKey(name: 'workshopServicesValid') 
  bool? workshopServicesValid;
  
  @JsonKey(name: 'dataBankValid')
  bool? dataBankValid;
  
  @JsonKey(name: 'status')
  int? status;

  Map<String, dynamic> toJson() => _$MechanicWorkshopToJson(this);
}
