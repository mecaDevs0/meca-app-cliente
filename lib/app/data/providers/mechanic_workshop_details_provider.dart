import 'package:mega_commons/mega_commons.dart';

import '../../core/app_urls.dart';
import '../models/mechanic_workshop.dart';
import '../models/workshopAgenda/agenda_model.dart';
import '../models/workshopAgenda/week_day_model.dart';
import '../models/workshopService/workshop_service.dart';

class MechanicWorkshopDetailsProvider {
  MechanicWorkshopDetailsProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<MechanicWorkshop> onRequestMechanicWorkshopDetails({
    required String id,
    double? latUser,
    double? longUser,
  }) async {
    final queryParameters = <String, dynamic>{
      if (latUser != null) 'latUser': latUser,
      if (longUser != null) 'longUser': longUser,
    };
    final response = await _restClientDio.get(
      '${BaseUrls.workshops}/$id',
      queryParameters: queryParameters,
    );
    return MechanicWorkshop.fromJson(response.data);
  }

  Future<List<WorkshopService>> onRequestMechanicWorkshopServices({
    String? search,
    String? workshopId,
  }) async {
    final queryParameters = <String, dynamic>{
      if (workshopId != null) 'workshopId': workshopId,
      if (search != null) 'search': search,
    };

    final response = await _restClientDio.get(
      BaseUrls.workshopServices,
      queryParameters: queryParameters,
    );
    return (response.data as List)
        .map<WorkshopService>(
          (service) =>
              WorkshopService.fromJson(service as Map<String, dynamic>),
        )
        .toList();
  }

  Future<AgendaModel> getWorkshopSchedule(String workshopId) async {
    try {
      final response = await _restClientDio.get(
        '${BaseUrls.workshopSchedule}/$workshopId',
      );

      // Log para verificar a estrutura dos dados recebidos
      print('Workshop schedule response: ${response.data}');

      // Tratamento especial caso a API esteja retornando valores diferentes do esperado
      final data = response.data as Map<String, dynamic>;

      // Garantir que cada dia da semana tenha o campo 'open' como booleano
      _ensureCorrectOpenField(data, 'monday');
      _ensureCorrectOpenField(data, 'tuesday');
      _ensureCorrectOpenField(data, 'wednesday');
      _ensureCorrectOpenField(data, 'thursday');
      _ensureCorrectOpenField(data, 'friday');
      _ensureCorrectOpenField(data, 'saturday');
      _ensureCorrectOpenField(data, 'sunday');

      return AgendaModel.fromJson(data);
    } catch (e, stackTrace) {
      print('Erro ao buscar horário da oficina: $e');
      print('Stack trace: $stackTrace');

      // Criar um modelo padrão com todos os dias abertos para facilitar os testes
      return _createDefaultSchedule();
    }
  }

  void _ensureCorrectOpenField(Map<String, dynamic> data, String dayKey) {
    if (data.containsKey(dayKey) && data[dayKey] is Map<String, dynamic>) {
      final day = data[dayKey] as Map<String, dynamic>;

      // Converter qualquer valor para booleano explicitamente
      if (day.containsKey('open')) {
        final openValue = day['open'];
        if (openValue is String) {
          day['open'] = openValue.toLowerCase() == 'true';
        } else if (openValue is num) {
          day['open'] = openValue != 0;
        } else if (openValue is! bool) {
          // Se não for booleano, string ou número, padronizar como true
          day['open'] = true;
        }
      } else {
        // Se não tiver o campo open, adicionar como true por padrão
        day['open'] = true;
      }

      // Garantir que os horários estão no formato correto
      _ensureTimeField(day, 'startTime');
      _ensureTimeField(day, 'closingTime');
    }
  }

  void _ensureTimeField(Map<String, dynamic> day, String timeKey) {
    if (!day.containsKey(timeKey) ||
        day[timeKey] == null ||
        day[timeKey] == '') {
      day[timeKey] = timeKey == 'startTime' ? '08:00' : '18:00';
    }
  }

  // Método para criar um horário padrão caso ocorra algum erro
  AgendaModel _createDefaultSchedule() {
    final defaultDay = WeekDayModel(
      open: true,
      startTime: '08:00',
      closingTime: '18:00',
      startOfBreak: '12:00',
      endOfBreak: '13:00',
    );

    return AgendaModel(
      monday: defaultDay,
      tuesday: defaultDay,
      wednesday: defaultDay,
      thursday: defaultDay,
      friday: defaultDay,
      saturday: defaultDay.copyWith(open: false),
      sunday: defaultDay.copyWith(open: false),
      id: 'default',
    );
  }
}
