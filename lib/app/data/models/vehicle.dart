import 'package:json_annotation/json_annotation.dart';

import 'profile.dart';

part 'vehicle.g.dart';

@JsonSerializable(includeIfNull: false)
class Vehicle {
  Vehicle({
    this.id,
    this.plate,
    this.manufacturer,
    this.model,
    this.km,
    this.color,
    this.year,
    this.lastRevisionDate,
    this.profile,
    this.dataBlocked,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) =>
      _$VehicleFromJson(json);

  Vehicle.empty() {
    plate = '';
    manufacturer = '';
    model = '';
    km = 0;
    color = '';
    year = '';
    lastRevisionDate = 0;
    profile = Profile.empty();
    dataBlocked = 0;
  }

  String? id;
  String? plate;
  String? manufacturer;
  String? model;
  int? km;
  String? color;
  String? year;
  int? lastRevisionDate;
  Profile? profile;
  int? dataBlocked;

  Map<String, dynamic> toJson() => _$VehicleToJson(this);
}
