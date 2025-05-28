import 'package:json_annotation/json_annotation.dart';

import 'profile.dart';
import 'vehicle.dart';

part 'workshop_agenda_model.g.dart';

@JsonSerializable()
class WorkshopAgendaModel {
  WorkshopAgendaModel({
    required this.available,
    required this.hour,
    this.profile,
    this.vehicle,
  });

  factory WorkshopAgendaModel.fromJson(Map<String, dynamic> json) {
    return _$WorkshopAgendaModelFromJson(json);
  }

  final bool available;
  final String hour;
  final Profile? profile;
  final Vehicle? vehicle;

  Map<String, dynamic> toJson() => _$WorkshopAgendaModelToJson(this);

  WorkshopAgendaModel copyWith({
    bool? available,
    String? hour,
    Profile? profile,
    Vehicle? vehicle,
  }) {
    return WorkshopAgendaModel(
      available: available ?? this.available,
      hour: hour ?? this.hour,
      profile: profile ?? this.profile,
      vehicle: vehicle ?? this.vehicle,
    );
  }
}
