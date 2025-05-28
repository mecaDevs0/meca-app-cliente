import 'package:json_annotation/json_annotation.dart';

part 'vehicle_scheduling.g.dart';

@JsonSerializable()
class VehicleScheduling {
  VehicleScheduling({
    this.id,
    this.plate,
  });

  factory VehicleScheduling.fromJson(Map<String, dynamic> json) =>
      _$VehicleSchedulingFromJson(json);

  String? id;
  String? plate;

  Map<String, dynamic> toJson() => _$VehicleSchedulingToJson(this);
}
