
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

  Map<String, dynamic> toJson() {
    final json = _$SchedulingToJson(this);
    
    // Garantir que IDs sejam strings
    if (json['workshop'] != null && json['workshop']['id'] != null) {
      json['workshop']['id'] = json['workshop']['id'].toString();
    }
    
    if (json['vehicle'] != null && json['vehicle']['id'] != null) {
      json['vehicle']['id'] = json['vehicle']['id'].toString();
    }
    
    // Garantir que workshopServices tenham IDs como string
    if (json['workshopServices'] != null && json['workshopServices'] is List) {
      for (var service in json['workshopServices']) {
        if (service is Map && service['service'] != null && service['service']['id'] != null) {
          service['service']['id'] = service['service']['id'].toString();
        }
      }
    }
    
    return json;
  }
}
