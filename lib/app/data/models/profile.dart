import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mega_commons/shared/data/mega_data_cache.dart';

part 'profile.g.dart';

@JsonSerializable()
@HiveType(typeId: 0)
class Profile {
  Profile({
    this.id,
    this.fullName,
    this.email,
    this.typeProvider,
    this.photo,
    this.login,
    this.cpf,
    this.phone,
    this.password,
    this.zipCode,
    this.stateName,
    this.stateUf,
    this.stateId,
    this.complement,
    this.streetAddress,
    this.number,
    this.neighborhood,
    this.cityId,
    this.cityName,
    this.externalId,
  });

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);

  Profile.empty() {
    fullName = '';
    phone = '';
    zipCode = '';
    streetAddress = '';
    photo = '';
    email = '';
    password = '';
    cpf = '';
    typeProvider = 0;
    number = '';
    neighborhood = '';
    stateId = '';
    stateUf = '';
    stateName = '';
    complement = '';
    cityId = '';
    cityName = '';
    externalId = '';
  }

  Profile copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? zipCode,
    String? streetAddress,
    String? photo,
    String? email,
    String? password,
    String? cpf,
    int? typeProvider,
    String? number,
    String? neighborhood,
    String? stateId,
    String? stateName,
    String? stateUf,
    String? complement,
    String? cityId,
    String? cityName,
    String? externalId,
  }) {
    return Profile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      zipCode: zipCode ?? this.zipCode,
      streetAddress: streetAddress ?? this.streetAddress,
      photo: photo ?? this.photo,
      email: email ?? this.email,
      password: password ?? this.password,
      cpf: cpf ?? this.cpf,
      number: number ?? this.number,
      neighborhood: neighborhood ?? this.neighborhood,
      typeProvider: typeProvider ?? this.typeProvider,
      stateId: stateId ?? this.stateId,
      stateName: stateName ?? this.stateName,
      stateUf: stateUf ?? this.stateUf,
      complement: complement ?? this.complement,
      cityId: cityId ?? this.cityId,
      cityName: cityName ?? this.cityName,
      externalId: externalId ?? this.externalId,
    );
  }

  @HiveField(0)
  String? fullName;

  @HiveField(1)
  String? email;

  @HiveField(2)
  int? typeProvider;

  @HiveField(3)
  String? photo;

  @JsonKey(includeIfNull: false)
  @HiveField(4)
  String? login;

  @JsonKey(includeIfNull: false)
  @HiveField(5)
  String? cpf;

  @HiveField(6)
  String? phone;

  @JsonKey(includeIfNull: false)
  @HiveField(7)
  String? password;

  @HiveField(8)
  String? zipCode;

  @JsonKey(includeIfNull: false)
  @HiveField(9)
  String? streetAddress;

  @HiveField(10)
  String? number;

  @HiveField(11)
  String? neighborhood;

  @HiveField(12)
  String? id;

  @JsonKey(includeIfNull: false)
  @HiveField(13)
  String? stateUf;

  @JsonKey(includeIfNull: false)
  @HiveField(14)
  String? stateId;

  @JsonKey(includeIfNull: false)
  @HiveField(15)
  String? stateName;

  @JsonKey(includeIfNull: false)
  @HiveField(16)
  String? complement;

  @JsonKey(includeIfNull: false)
  @HiveField(17)
  String? cityId;

  @JsonKey(includeIfNull: false)
  @HiveField(18)
  String? cityName;

  @JsonKey(includeIfNull: false)
  @HiveField(19)
  String? externalId;

  static const String _key = 'profile';
  static Box<Profile> get cacheBox => MegaDataCache.box<Profile>();

  Future<void> save() async {
    await cacheBox.put(_key, this);
  }

  Future<void> remove() async {
    await cacheBox.delete(_key);
  }

  static Profile fromCache() {
    return cacheBox.get(_key) ?? Profile.empty();
  }

  Map<String, dynamic> toJson() => _$ProfileToJson(this);
}
