import 'package:json_annotation/json_annotation.dart';

import '../../enums/days_of_week.dart';
import 'week_day_model.dart';

part 'agenda_model.g.dart';

@JsonSerializable()
class AgendaModel {
  AgendaModel({
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
    this.id,
  });

  factory AgendaModel.fromJson(Map<String, dynamic> json) {
    // CORREÇÃO: Tratamento seguro para valores null vindos da API
    // A API está retornando {monday: null, tuesday: null, ...} então criamos defaults
    final defaultDay = WeekDayModel(
      open: true,
      startTime: '08:00',
      closingTime: '18:00',
      startOfBreak: '12:00',
      endOfBreak: '13:00',
    );

    return AgendaModel(
      monday: json['monday'] != null 
          ? WeekDayModel.fromJson(json['monday'] as Map<String, dynamic>)
          : defaultDay,
      tuesday: json['tuesday'] != null 
          ? WeekDayModel.fromJson(json['tuesday'] as Map<String, dynamic>)
          : defaultDay,
      wednesday: json['wednesday'] != null 
          ? WeekDayModel.fromJson(json['wednesday'] as Map<String, dynamic>)
          : defaultDay,
      thursday: json['thursday'] != null 
          ? WeekDayModel.fromJson(json['thursday'] as Map<String, dynamic>)
          : defaultDay,
      friday: json['friday'] != null 
          ? WeekDayModel.fromJson(json['friday'] as Map<String, dynamic>)
          : defaultDay,
      saturday: json['saturday'] != null 
          ? WeekDayModel.fromJson(json['saturday'] as Map<String, dynamic>)
          : defaultDay.copyWith(open: false), // Sábado fechado por padrão
      sunday: json['sunday'] != null 
          ? WeekDayModel.fromJson(json['sunday'] as Map<String, dynamic>)
          : defaultDay.copyWith(open: false), // Domingo fechado por padrão
      id: json['id'] as String?,
    );
  }

  final WeekDayModel monday;
  final WeekDayModel tuesday;
  final WeekDayModel wednesday;
  final WeekDayModel thursday;
  final WeekDayModel friday;
  final WeekDayModel saturday;
  final WeekDayModel sunday;
  final String? id;

  Map<String, dynamic> toJson() => _$AgendaModelToJson(this);

  AgendaModel? copyWith(DaysOfWeek day, WeekDayModel changed) {
    switch (day) {
      case DaysOfWeek.monday:
        return AgendaModel(
          monday: changed,
          tuesday: tuesday,
          wednesday: wednesday,
          thursday: thursday,
          friday: friday,
          saturday: saturday,
          sunday: sunday,
          id: id,
        );
      case DaysOfWeek.tuesday:
        return AgendaModel(
          monday: monday,
          tuesday: changed,
          wednesday: wednesday,
          thursday: thursday,
          friday: friday,
          saturday: saturday,
          sunday: sunday,
          id: id,
        );
      case DaysOfWeek.wednesday:
        return AgendaModel(
          monday: monday,
          tuesday: tuesday,
          wednesday: changed,
          thursday: thursday,
          friday: friday,
          saturday: saturday,
          sunday: sunday,
          id: id,
        );
      case DaysOfWeek.thursday:
        return AgendaModel(
          monday: monday,
          tuesday: tuesday,
          wednesday: wednesday,
          thursday: changed,
          friday: friday,
          saturday: saturday,
          sunday: sunday,
          id: id,
        );
      case DaysOfWeek.friday:
        return AgendaModel(
          monday: monday,
          tuesday: tuesday,
          wednesday: wednesday,
          thursday: thursday,
          friday: changed,
          saturday: saturday,
          sunday: sunday,
          id: id,
        );
      case DaysOfWeek.saturday:
        return AgendaModel(
          monday: monday,
          tuesday: tuesday,
          wednesday: wednesday,
          thursday: thursday,
          friday: friday,
          saturday: changed,
          sunday: sunday,
          id: id,
        );
      case DaysOfWeek.sunday:
        return AgendaModel(
          monday: monday,
          tuesday: tuesday,
          wednesday: wednesday,
          thursday: thursday,
          friday: friday,
          saturday: saturday,
          sunday: changed,
          id: id,
        );
    }
  }

  AgendaModel toggleOpenStatus(List<DaysOfWeek> selectedDays) {
    return AgendaModel(
      monday: monday.copyWith(open: selectedDays.contains(DaysOfWeek.monday)),
      tuesday:
          tuesday.copyWith(open: selectedDays.contains(DaysOfWeek.tuesday)),
      wednesday:
          wednesday.copyWith(open: selectedDays.contains(DaysOfWeek.wednesday)),
      thursday:
          thursday.copyWith(open: selectedDays.contains(DaysOfWeek.thursday)),
      friday: friday.copyWith(open: selectedDays.contains(DaysOfWeek.friday)),
      saturday:
          saturday.copyWith(open: selectedDays.contains(DaysOfWeek.saturday)),
      sunday: sunday.copyWith(open: selectedDays.contains(DaysOfWeek.sunday)),
      id: id,
    );
  }

  static AgendaModel initial() {
    return AgendaModel(
      monday: WeekDayModel(
        open: false,
        startTime: '08:00',
        closingTime: '18:00',
        startOfBreak: '12:00',
        endOfBreak: '13:00',
      ),
      tuesday: WeekDayModel(
        open: false,
        startTime: '08:00',
        closingTime: '18:00',
        startOfBreak: '12:00',
        endOfBreak: '13:00',
      ),
      wednesday: WeekDayModel(
        open: false,
        startTime: '08:00',
        closingTime: '18:00',
        startOfBreak: '12:00',
        endOfBreak: '13:00',
      ),
      thursday: WeekDayModel(
        open: false,
        startTime: '08:00',
        closingTime: '18:00',
        startOfBreak: '12:00',
        endOfBreak: '13:00',
      ),
      friday: WeekDayModel(
        open: false,
        startTime: '08:00',
        closingTime: '18:00',
        startOfBreak: '12:00',
        endOfBreak: '13:00',
      ),
      saturday: WeekDayModel(
        open: false,
        startTime: '08:00',
        closingTime: '18:00',
        startOfBreak: '12:00',
        endOfBreak: '13:00',
      ),
      sunday: WeekDayModel(
        open: false,
        startTime: '08:00',
        closingTime: '18:00',
        startOfBreak: '12:00',
        endOfBreak: '13:00',
      ),
      id: null,
    );
  }
}
