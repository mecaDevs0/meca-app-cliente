import 'package:json_annotation/json_annotation.dart';

import 'workshop_agenda_model.dart';

part 'workshop_schedule_model.g.dart';

@JsonSerializable()
class WorkshopScheduleModel {
  WorkshopScheduleModel({
    required this.date,
    required this.available,
    required this.dayOfWeek,
    required this.hours,
    required this.workshopAgenda,
  });

  factory WorkshopScheduleModel.fromJson(Map<String, dynamic> json) {
    return _$WorkshopScheduleModelFromJson(json);
  }

  final DateTime date;
  final bool available;
  final int dayOfWeek;
  final List<String> hours;
  final List<WorkshopAgendaModel> workshopAgenda;

  Map<String, dynamic> toJson() => _$WorkshopScheduleModelToJson(this);

  WorkshopScheduleModel copyWith({
    DateTime? date,
    bool? available,
    int? dayOfWeek,
    List<String>? hours,
    List<WorkshopAgendaModel>? workshopAgenda,
  }) {
    return WorkshopScheduleModel(
      date: date ?? this.date,
      available: available ?? this.available,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      hours: hours ?? this.hours,
      workshopAgenda: workshopAgenda ?? this.workshopAgenda,
    );
  }
}
