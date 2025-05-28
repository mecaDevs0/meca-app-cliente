import 'package:json_annotation/json_annotation.dart';

part 'week_day_model.g.dart';

@JsonSerializable()
class WeekDayModel {
  WeekDayModel({
    required this.open,
    required this.startTime,
    required this.closingTime,
    required this.startOfBreak,
    required this.endOfBreak,
  });

  factory WeekDayModel.fromJson(Map<String, dynamic> json) {
    return _$WeekDayModelFromJson(json);
  }

  @JsonKey(defaultValue: false)
  final bool open;
  @JsonKey(defaultValue: '')
  final String startTime;
  @JsonKey(defaultValue: '')
  final String closingTime;
  @JsonKey(defaultValue: '')
  final String startOfBreak;
  @JsonKey(defaultValue: '')
  final String endOfBreak;

  Map<String, dynamic> toJson() => _$WeekDayModelToJson(this);

  WeekDayModel copyWith({
    bool? open,
    String? startTime,
    String? closingTime,
    String? startOfBreak,
    String? endOfBreak,
  }) {
    return WeekDayModel(
      open: open ?? this.open,
      startTime: startTime ?? this.startTime,
      closingTime: closingTime ?? this.closingTime,
      startOfBreak: startOfBreak ?? this.startOfBreak,
      endOfBreak: endOfBreak ?? this.endOfBreak,
    );
  }
}
