import 'package:json_annotation/json_annotation.dart';

import '../workshopService/workshop_service.dart';
import 'vehicle_scheduling.dart';
import 'workshop_scheduling.dart';

part 'scheduling.g.dart';

@JsonSerializable()
class Scheduling {
  Scheduling({
    this.workshopServices,
    this.vehicle,
    this.observations,
    this.date,
    this.status,
    this.workshop,
  });

  factory Scheduling.fromJson(Map<String, dynamic> json) =>
      _$SchedulingFromJson(json);

  List<WorkshopService>? workshopServices;
  VehicleScheduling? vehicle;
  String? observations;
  int? date;
  int? status;
  WorkshopScheduling? workshop;

  Map<String, dynamic> toJson() => _$SchedulingToJson(this);
}
