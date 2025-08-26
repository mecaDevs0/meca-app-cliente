import 'package:json_annotation/json_annotation.dart';

part 'mechanic_workshop.g.dart';

@JsonSerializable()
class MechanicWorkshop {
  @JsonKey(name: 'id')
  String? id;
  
  @JsonKey(name: 'fullName')
  String? fullName;
  
  @JsonKey(name: 'birthDate')
  String? birthDate;
  
  @JsonKey(name: 'companyName')
  String? companyName;
  
  @JsonKey(name: 'fileDocument')
  String? fileDocument;
  
  @JsonKey(name: 'cpf')
  String? cpf;
  
  @JsonKey(name: 'email')
  String? email;
  
  @JsonKey(name: 'phone')
  String? phone;
  
  @JsonKey(name: 'cnpj')
  String? cnpj;
  
  @JsonKey(name: 'zipCode')
  String? zipCode;
  
  @JsonKey(name: 'streetAddress')
  String? streetAddress;
  
  @JsonKey(name: 'number')
  String? number;
  
  @JsonKey(name: 'cityName')
  String? cityName;
  
  @JsonKey(name: 'cityId')
  String? cityId;
  
  @JsonKey(name: 'stateName')
  String? stateName;
  
  @JsonKey(name: 'stateUf')
  String? stateUf;
  
  @JsonKey(name: 'stateId')
  String? stateId;
  
  @JsonKey(name: 'neighborhood')
  String? neighborhood;
  
  @JsonKey(name: 'complement')
  String? complement;
  
  @JsonKey(name: 'latitude')
  double? latitude;
  
  @JsonKey(name: 'longitude')
  double? longitude;
  
  @JsonKey(name: 'openingHours')
  String? openingHours;
  
  @JsonKey(name: 'photo')
  String? photo;
  
  @JsonKey(name: 'meiCard')
  String? meiCard;
  
  @JsonKey(name: 'password')
  String? password;
  
  @JsonKey(name: 'rating')
  double? rating;
  
  @JsonKey(name: 'distance')
  double? distance;
  
  @JsonKey(name: 'reason')
  String? reason;
  
  @JsonKey(name: 'accountableName')
  String? accountableName;
  
  @JsonKey(name: 'accountableCpf')
  String? accountableCpf;
  
  @JsonKey(name: 'accountablePhone')
  String? accountablePhone;
  
  @JsonKey(name: 'accountableEmail')
  String? accountableEmail;
  
  @JsonKey(name: 'status')
  int? status;
  
  @JsonKey(name: 'blocked')
  bool? blocked;
  
  @JsonKey(name: 'dataBankValid')
  bool? dataBankValid;
  
  @JsonKey(name: 'workshopAgendaValid')
  bool? workshopAgendaValid;
  
  @JsonKey(name: 'workshopServicesValid')
  bool? workshopServicesValid;
  
  @JsonKey(name: 'requirements')
  List<dynamic>? requirements;
  
  @JsonKey(name: 'created')
  int? created;
  
  @JsonKey(name: 'updated')
  int? updated;

  MechanicWorkshop({
    this.id,
    this.fullName,
    this.birthDate,
    this.companyName,
    this.fileDocument,
    this.cpf,
    this.email,
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
    this.password,
    this.rating,
    this.distance,
    this.reason,
    this.accountableName,
    this.accountableCpf,
    this.accountablePhone,
    this.accountableEmail,
    this.status,
    this.blocked,
    this.dataBankValid,
    this.workshopAgendaValid,
    this.workshopServicesValid,
    this.requirements,
    this.created,
    this.updated,
  });

  MechanicWorkshop.empty() {
    fullName = '';
    birthDate = '';
    companyName = '';
    fileDocument = '';
    cpf = '';
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
    photo = '';
    meiCard = '';
    email = '';
    password = '';
    rating = 0;
    distance = 0.0;
    reason = '';
    accountableName = '';
    accountableCpf = '';
    accountablePhone = '';
    accountableEmail = '';
    status = 0;
    blocked = false;
    dataBankValid = false;
    workshopAgendaValid = false;
    workshopServicesValid = false;
    requirements = [];
    created = 0;
    updated = 0;
  }

  factory MechanicWorkshop.fromJson(Map<String, dynamic> json) => _$MechanicWorkshopFromJson(json);
  Map<String, dynamic> toJson() => _$MechanicWorkshopToJson(this);
}
