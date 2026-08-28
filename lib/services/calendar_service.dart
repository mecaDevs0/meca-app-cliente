import 'dart:convert';

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/foundation.dart';

class CalendarService {
  static Future<bool> addBookingToCalendar({
    required Map<String, dynamic> booking,
    Map<String, dynamic>? bookingDetails,
  }) async {
    try {
      final merged = <String, dynamic>{...booking};
      if (bookingDetails != null) merged.addAll(bookingDetails);

      final serviceName = _extractString(merged, ['service_name'],
          nested: {'service': 'name'}, fallback: 'Serviço Automotivo');
      final workshopName = _extractString(merged, ['workshop_name'],
          nested: {'workshop': 'name'}, fallback: 'Oficina');

      final startDate = _parseStartDate(merged);
      if (startDate == null) return false;

      final durationMinutes = _parseDuration(merged);
      final endDate = startDate.add(Duration(minutes: durationMinutes));

      final location = _buildLocation(merged);
      final description = _buildDescription(merged, serviceName, workshopName);

      final event = Event(
        title: '🔧 $serviceName — $workshopName',
        description: description,
        location: location,
        startDate: startDate,
        endDate: endDate,
        iosParams: const IOSParams(reminder: Duration(hours: 1)),
        androidParams: const AndroidParams(emailInvites: []),
      );

      return await Add2Calendar.addEvent2Cal(event);
    } catch (e) {
      debugPrint('❌ [CalendarService] Erro ao adicionar evento: $e');
      return false;
    }
  }

  static String _extractString(
    Map<String, dynamic> data,
    List<String> keys, {
    Map<String, String>? nested,
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    if (nested != null) {
      for (final entry in nested.entries) {
        final obj = data[entry.key];
        if (obj is Map) {
          final value = obj[entry.value];
          if (value != null && value.toString().trim().isNotEmpty) {
            return value.toString().trim();
          }
        }
      }
    }
    return fallback;
  }

  static DateTime? _parseStartDate(Map<String, dynamic> data) {
    final appointmentDate =
        data['appointment_date'] ?? data['scheduled_date'];
    if (appointmentDate == null) return null;

    try {
      final parsed = DateTime.parse(appointmentDate.toString());
      if (parsed.hour == 0 && parsed.minute == 0) {
        final timeStr = data['scheduled_time']?.toString();
        if (timeStr != null && timeStr.contains(':')) {
          final parts = timeStr.split(':');
          return DateTime(
            parsed.year,
            parsed.month,
            parsed.day,
            int.tryParse(parts[0]) ?? 8,
            int.tryParse(parts[1]) ?? 0,
          );
        }
        return DateTime(parsed.year, parsed.month, parsed.day, 8, 0);
      }
      return parsed;
    } catch (e) {
      debugPrint('❌ [CalendarService] Erro ao parsear data: $e');
      return null;
    }
  }

  static int _parseDuration(Map<String, dynamic> data) {
    final raw = data['service_duration'] ?? data['duration'];
    if (raw == null) return 120;
    final minutes = int.tryParse(raw.toString());
    return (minutes != null && minutes > 0) ? minutes : 120;
  }

  static String _buildLocation(Map<String, dynamic> data) {
    var address = data['workshop_address'];
    if (address == null) return '';
    if (address is String) {
      final trimmed = address.trim();
      if (trimmed.isEmpty) return '';
      if (trimmed.startsWith('{')) {
        try {
          address = json.decode(trimmed);
        } catch (_) {
          return trimmed;
        }
      } else {
        return trimmed;
      }
    }
    if (address is Map) {
      final parts = <String>[
        if (address['street'] != null) address['street'].toString(),
        if (address['number'] != null) address['number'].toString(),
        if (address['neighborhood'] != null) address['neighborhood'].toString(),
        if (address['city'] != null) address['city'].toString(),
        if (address['state'] != null) address['state'].toString(),
      ];
      if (parts.isNotEmpty) return parts.join(', ');
    }
    return '';
  }

  static String _buildDescription(
    Map<String, dynamic> data,
    String serviceName,
    String workshopName,
  ) {
    final buf = StringBuffer();
    buf.writeln('📋 Serviço: $serviceName');
    buf.writeln('🏪 Oficina: $workshopName');

    final location = _buildLocation(data);
    if (location.isNotEmpty) {
      buf.writeln('📍 Endereço: $location');
    }

    final vehicleBrand = _extractString(data, ['vehicle_brand', 'brand']);
    final vehicleModel = _extractString(data, ['vehicle_model', 'model']);
    final vehiclePlate = _extractString(data, ['vehicle_plate', 'plate']);
    final vehicleStr = '$vehicleBrand $vehicleModel'.trim();
    if (vehicleStr.isNotEmpty || vehiclePlate.isNotEmpty) {
      final display = [
        if (vehicleStr.isNotEmpty) vehicleStr,
        if (vehiclePlate.isNotEmpty) vehiclePlate,
      ].join(' — ');
      buf.writeln('🚗 Veículo: $display');
    }

    final bookingId = data['id']?.toString();
    if (bookingId != null && bookingId.isNotEmpty) {
      buf.writeln('');
      buf.writeln('Abra no MECA: mecabr://booking/$bookingId');
    }

    buf.writeln('');
    buf.writeln('Agendado via app MECA — mecabr.com');

    return buf.toString();
  }
}
