// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'week_day_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WeekDayModel _$WeekDayModelFromJson(Map<String, dynamic> json) => WeekDayModel(
      open: json['open'] as bool? ?? false,
      startTime: json['startTime'] as String? ?? '',
      closingTime: json['closingTime'] as String? ?? '',
      startOfBreak: json['startOfBreak'] as String? ?? '',
      endOfBreak: json['endOfBreak'] as String? ?? '',
    );

Map<String, dynamic> _$WeekDayModelToJson(WeekDayModel instance) =>
    <String, dynamic>{
      'open': instance.open,
      'startTime': instance.startTime,
      'closingTime': instance.closingTime,
      'startOfBreak': instance.startOfBreak,
      'endOfBreak': instance.endOfBreak,
    };
