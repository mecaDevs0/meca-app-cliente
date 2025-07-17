
import 'dart:developer';

import 'package:mega_commons/mega_commons.dart';

import '../../core/app_urls.dart';
import '../models/scheduling/scheduling.dart';

class RequestAppointmentProvider {
  RequestAppointmentProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<Scheduling> onRegisterScheduling(Scheduling scheduling) async {
    log('Iniciando registro de agendamento');

    try {
      // Garantir que os dados do agendamento sejam válidos
      if (scheduling.workshop?.id == null ||
          scheduling.vehicle?.id == null ||
          scheduling.workshopServices == null ||
          (scheduling.workshopServices?.isEmpty ?? true)) {
        throw Exception('Dados de agendamento incompletos');
      }

      // Adiciona parâmetro para indicar que o período de pausa não é obrigatório
      Map<String, dynamic> data = scheduling.toJson();
      data['skipBreakTime'] = true; // Indica que o período de pausa não é necessário

      // Remover parâmetros que podem estar causando problemas
      if (data.containsKey('profileId')) {
        data.remove('profileId');
      }
      if (data.containsKey('dataBlocked')) {
        data.remove('dataBlocked');
      }

      // Garantir que os IDs estejam no formato correto
      if (data['workshopId'] != null) {
        data['workshopId'] = data['workshopId'].toString();
      }

      // Log dos dados que serão enviados
      log('Enviando dados de agendamento: ${data.toString()}');

      final response = await _restClientDio.post(
        BaseUrls.scheduling,
        data: data,
      );

      log('Resposta do agendamento recebida: ${response.statusCode}');
      return Scheduling.fromJson(response.data);
    } catch (e) {
      log('Erro durante o registro do agendamento: $e');

      // Se o erro contiver informações específicas sobre o formato de ID, tentamos uma abordagem alternativa
      if (e.toString().contains('id inválido') || e.toString().contains('400 Bad Request')) {
        log('Tentando abordagem alternativa para o registro de agendamento');

        try {
          // Criando um objeto JSON simplificado com apenas os campos essenciais
          final Map<String, dynamic> simplifiedData = {
            'workshopId': scheduling.workshop?.id,
            'vehicleId': scheduling.vehicle?.id,
            'date': scheduling.date,
            'observations': scheduling.observations ?? '',
            'serviceIds': scheduling.workshopServices?.map((ws) => ws.service?.id).whereType<String>().toList() ?? [],
            'skipBreakTime': true,
          };

          log('Tentando com dados simplificados: $simplifiedData');

          final response = await _restClientDio.post(
            BaseUrls.scheduling,
            data: simplifiedData,
          );

          return Scheduling.fromJson(response.data);
        } catch (fallbackError) {
          log('Falha também na abordagem alternativa: $fallbackError');
          rethrow;
        }
      }

      // Se não for um erro de formato de ID, propaga o erro original
      rethrow;
    }
  }

  // Método para buscar horários disponíveis para uma data específica
  Future<List<String>> getAvailableHours({
    required String workshopId,
    required DateTime date,
    required String profileId,
  }) async {
    log('Buscando horários disponíveis para oficina: $workshopId, data: ${date.toIso8601String()}');

    try {
      // Validando o formato do workshopId antes de realizar a requisição
      if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(workshopId)) {
        log('Formato de workshopId inválido: $workshopId');
        return [];
      }

      // Validando o formato do profileId
      if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(profileId)) {
        log('Formato de profileId inválido: $profileId');
        return [];
      }

      // Formatando a data corretamente
      final formattedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final params = {
        'workshopId': workshopId,
        'date': formattedDate,
        'profileId': profileId,
      };

      log('Parâmetros da requisição: $params');

      final response = await _restClientDio.get(
        '${BaseUrls.scheduling}/availability',
        queryParameters: params,
      );

      if (response.statusCode == 200 && response.data != null) {
        log('Horários disponíveis recebidos: ${response.data}');
        if (response.data is List) {
          return List<String>.from(response.data);
        }
        return [];
      } else {
        log('Erro ao buscar horários: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      log('Erro ao buscar horários disponíveis: $e');
      return [];
    }
  }

  // Método para buscar datas disponíveis para agendamento
  Future<List<DateTime>> getAvailableDates({
    required String workshopId,
    required List<String> workshopHours,
  }) async {
    log('Buscando datas disponíveis para oficina: $workshopId');

    try {
      // Validando o formato do workshopId
      if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(workshopId)) {
        log('Formato de workshopId inválido: $workshopId');
        return _generateDatesFromHours(workshopHours);
      }

      final params = {
        'workshopId': workshopId,
      };

      log('Parâmetros da requisição: $params');

      final response = await _restClientDio.get(
        '${BaseUrls.scheduling}/available-dates',
        queryParameters: params,
      );

      if (response.statusCode == 200 && response.data != null) {
        log('Datas disponíveis recebidas: ${response.data}');
        
        final List<DateTime> dates = [];
        if (response.data is List) {
          for (final dynamic dateItem in response.data) {
            try {
              if (dateItem is String) {
                dates.add(DateTime.parse(dateItem));
              }
            } catch (parseError) {
              log('Erro ao converter data: $parseError');
            }
          }
        }

        if (dates.isNotEmpty) {
          dates.sort((a, b) => a.compareTo(b));
          log('Datas disponíveis carregadas: ${dates.length}');
          return dates;
        }
      }

      log('Gerando datas a partir do horário de funcionamento como fallback.');
      return _generateDatesFromHours(workshopHours);
    } catch (e) {
      log('Erro ao buscar datas disponíveis: $e');
      return _generateDatesFromHours(workshopHours);
    }
  }

  List<DateTime> _generateDatesFromHours(List<String>? workshopHours) {
    if (workshopHours == null || workshopHours.isEmpty) {
      log('Horários de funcionamento não fornecidos. Usando horários padrão.');
      workshopHours = ['09:00-18:00']; // Horário padrão de funcionamento
    }

    final List<DateTime> generatedDates = [];
    final now = DateTime.now();

    for (int i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));
      for (final hour in workshopHours) {
        try {
          final timeRange = hour.split('-');
          if (timeRange.length == 2) {
            final startTime = timeRange[0].split(':');
            final endTime = timeRange[1].split(':');

            final startHour = int.parse(startTime[0]);
            final startMinute = int.parse(startTime[1]);
            final endHour = int.parse(endTime[0]);
            final endMinute = int.parse(endTime[1]);

            // Gerar horários dentro do intervalo
            DateTime current = DateTime(date.year, date.month, date.day, startHour, startMinute);
            final endDateTime = DateTime(date.year, date.month, date.day, endHour, endMinute);

            while (current.isBefore(endDateTime) || current.isAtSameMomentAs(endDateTime)) {
              generatedDates.add(current);
              current = current.add(Duration(minutes: 30)); // Incrementa de 30 em 30 minutos
            }
          } else {
            log('Formato de horário inválido: $hour');
          }
        } catch (e) {
          log('Erro ao gerar data a partir do horário: $hour. Erro: $e');
        }
      }
    }

    return generatedDates;
  }

  List<String> _generateFallbackHours() {
    log('Gerando horários de fallback padrão.');
    final List<String> fallbackHours = [];
    for (int hour = 9; hour < 18; hour++) {
      fallbackHours.add('${hour.toString().padLeft(2, '0')}:00');
      fallbackHours.add('${hour.toString().padLeft(2, '0')}:30');
    }
    return fallbackHours;
  }
}
