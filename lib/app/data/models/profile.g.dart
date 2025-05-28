// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProfileAdapter extends TypeAdapter<Profile> {
  @override
  final int typeId = 0;

  @override
  Profile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Profile(
      id: fields[12] as String?,
      fullName: fields[0] as String?,
      email: fields[1] as String?,
      typeProvider: fields[2] as int?,
      photo: fields[3] as String?,
      login: fields[4] as String?,
      cpf: fields[5] as String?,
      phone: fields[6] as String?,
      password: fields[7] as String?,
      zipCode: fields[8] as String?,
      stateName: fields[15] as String?,
      stateUf: fields[13] as String?,
      stateId: fields[14] as String?,
      complement: fields[16] as String?,
      streetAddress: fields[9] as String?,
      number: fields[10] as String?,
      neighborhood: fields[11] as String?,
      cityId: fields[17] as String?,
      cityName: fields[18] as String?,
      externalId: fields[19] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Profile obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.fullName)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.typeProvider)
      ..writeByte(3)
      ..write(obj.photo)
      ..writeByte(4)
      ..write(obj.login)
      ..writeByte(5)
      ..write(obj.cpf)
      ..writeByte(6)
      ..write(obj.phone)
      ..writeByte(7)
      ..write(obj.password)
      ..writeByte(8)
      ..write(obj.zipCode)
      ..writeByte(9)
      ..write(obj.streetAddress)
      ..writeByte(10)
      ..write(obj.number)
      ..writeByte(11)
      ..write(obj.neighborhood)
      ..writeByte(12)
      ..write(obj.id)
      ..writeByte(13)
      ..write(obj.stateUf)
      ..writeByte(14)
      ..write(obj.stateId)
      ..writeByte(15)
      ..write(obj.stateName)
      ..writeByte(16)
      ..write(obj.complement)
      ..writeByte(17)
      ..write(obj.cityId)
      ..writeByte(18)
      ..write(obj.cityName)
      ..writeByte(19)
      ..write(obj.externalId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Profile _$ProfileFromJson(Map<String, dynamic> json) => Profile(
      id: json['id'] as String?,
      fullName: json['fullName'] as String?,
      email: json['email'] as String?,
      typeProvider: (json['typeProvider'] as num?)?.toInt(),
      photo: json['photo'] as String?,
      login: json['login'] as String?,
      cpf: json['cpf'] as String?,
      phone: json['phone'] as String?,
      password: json['password'] as String?,
      zipCode: json['zipCode'] as String?,
      stateName: json['stateName'] as String?,
      stateUf: json['stateUf'] as String?,
      stateId: json['stateId'] as String?,
      complement: json['complement'] as String?,
      streetAddress: json['streetAddress'] as String?,
      number: json['number'] as String?,
      neighborhood: json['neighborhood'] as String?,
      cityId: json['cityId'] as String?,
      cityName: json['cityName'] as String?,
      externalId: json['externalId'] as String?,
    );

Map<String, dynamic> _$ProfileToJson(Profile instance) => <String, dynamic>{
      'fullName': instance.fullName,
      'email': instance.email,
      'typeProvider': instance.typeProvider,
      'photo': instance.photo,
      if (instance.login case final value?) 'login': value,
      if (instance.cpf case final value?) 'cpf': value,
      'phone': instance.phone,
      if (instance.password case final value?) 'password': value,
      'zipCode': instance.zipCode,
      if (instance.streetAddress case final value?) 'streetAddress': value,
      'number': instance.number,
      'neighborhood': instance.neighborhood,
      'id': instance.id,
      if (instance.stateUf case final value?) 'stateUf': value,
      if (instance.stateId case final value?) 'stateId': value,
      if (instance.stateName case final value?) 'stateName': value,
      if (instance.complement case final value?) 'complement': value,
      if (instance.cityId case final value?) 'cityId': value,
      if (instance.cityName case final value?) 'cityName': value,
      if (instance.externalId case final value?) 'externalId': value,
    };
