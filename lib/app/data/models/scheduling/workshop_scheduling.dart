import 'package:json_annotation/json_annotation.dart';

part 'workshop_scheduling.g.dart';

@JsonSerializable()
class WorkshopScheduling {
  WorkshopScheduling({
    this.id,
    this.fullName,
  });

  factory WorkshopScheduling.fromJson(Map<String, dynamic> json) =>
      _$WorkshopSchedulingFromJson(json);

  String? id;
  String? fullName;

  Map<String, dynamic> toJson() => _$WorkshopSchedulingToJson(this);
}
