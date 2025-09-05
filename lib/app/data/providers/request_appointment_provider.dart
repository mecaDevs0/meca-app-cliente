

import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../core/app_urls.dart';
import '../models/scheduling/scheduling.dart';

class RequestAppointmentProvider {
  RequestAppointmentProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<Scheduling> onRegisterScheduling(Scheduling scheduling) async {
    try {
      final response = await _restClientDio.post(
        BaseUrls.scheduling,
        data: scheduling.toJson(),
      );
      return Scheduling.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final errorData = e.response?.data;
        if (errorData != null && errorData is Map<String, dynamic>) {
          final message = errorData['message'] as String?;
          if (message?.contains('Horário inválido') == true) {
            throw MegaResponse(message: '❌ Horário não disponível!\n\nPor favor, selecione um horário futuro que respeite o tempo mínimo de agendamento (geralmente 2 horas de antecedência).', statusCode: 400);
          } else if (message?.contains('Oficina não está habilitada') == true || 
                   message?.contains('agenda e serviços estão configurados') == true ||
                   message?.contains('estabelecimento não tem horários') == true) {
            throw MegaResponse(message: '❌ Oficina não habilitada!\n\nEsta oficina ainda não está configurada para receber agendamentos online. Entre em contato diretamente com a oficina ou tente novamente mais tarde.', statusCode: 400);
          } else if (message?.contains('data passada') == true) {
            throw MegaResponse(message: '❌ Data inválida!\n\nNão é possível agendar para uma data passada. Selecione uma data futura.', statusCode: 400);
          } else if (message?.contains('mínimo para agendamento') == true) {
            throw MegaResponse(message: '❌ Horário muito próximo!\n\nPor favor, agende com pelo menos 2 horas de antecedência para garantir disponibilidade.', statusCode: 400);
          } else if (message?.contains('veículo não encontrado') == true) {
            throw MegaResponse(message: '❌ Veículo não encontrado!\n\nVerifique se o veículo está cadastrado corretamente em seu perfil.', statusCode: 400);
          } else if (message?.contains('serviço não disponível') == true) {
            throw MegaResponse(message: '❌ Serviço indisponível!\n\nUm ou mais serviços selecionados não estão disponíveis neste estabelecimento.', statusCode: 400);
          } else if (message?.contains('Já existe um agendamento') == true) {
            throw MegaResponse(message: '❌ Agendamento duplicado!\n\nJá existe um agendamento para esta data e horário. Selecione outro horário.', statusCode: 400);
          } else if (message?.contains('estabelecimento fechado') == true || message?.contains('fora do horário') == true) {
            throw MegaResponse(message: '❌ Estabelecimento fechado!\n\nEste estabelecimento não atende no horário selecionado. Verifique os horários de funcionamento.', statusCode: 400);
          } else if (message?.contains('serviço indisponível') == true || message?.contains('serviço não oferecido') == true) {
            throw MegaResponse(message: '❌ Serviço indisponível!\n\nUm ou mais serviços selecionados não estão disponíveis neste estabelecimento.', statusCode: 400);
          } else if (message?.contains('veículo inválido') == true || message?.contains('veículo não autorizado') == true) {
            throw MegaResponse(message: '❌ Veículo inválido!\n\nO veículo selecionado não pode ser atendido neste estabelecimento.', statusCode: 400);
          } else if (message?.contains('usuário não autorizado') == true || message?.contains('permissão negada') == true) {
            throw MegaResponse(message: '❌ Acesso negado!\n\nVocê não tem permissão para realizar agendamentos neste estabelecimento.', statusCode: 400);
          } else if (message?.contains('limite de agendamentos') == true) {
            throw MegaResponse(message: '❌ Limite excedido!\n\nVocê atingiu o limite de agendamentos pendentes. Aguarde a conclusão de um serviço.', statusCode: 400);
          } else {
            throw MegaResponse(message: '❌ Erro no agendamento!\n\n${message ?? 'Verifique os dados e tente novamente.'}', statusCode: 400);
          }
        } else {
          throw MegaResponse(message: '❌ Erro no agendamento!\n\nVerifique os dados e tente novamente.', statusCode: 400);
        }
      } else if (e.response?.statusCode == 500) {
        throw MegaResponse(message: '❌ Erro interno do servidor!\n\nTente novamente em alguns minutos. Se o problema persistir, entre em contato com o suporte.', statusCode: 500);
      } else if (e.response?.statusCode == 503) {
        throw MegaResponse(message: '❌ Serviço indisponível!\n\nO sistema está temporariamente indisponível. Tente novamente em alguns minutos.', statusCode: 503);
      } else if (e.response?.statusCode == 429) {
        throw MegaResponse(message: '❌ Muitas tentativas!\n\nVocê fez muitas tentativas de agendamento. Aguarde alguns minutos e tente novamente.', statusCode: 429);
      } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.sendTimeout) {
        throw MegaResponse(message: '❌ Tempo limite excedido!\n\nA conexão demorou muito para responder. Verifique sua internet e tente novamente.', statusCode: 408);
      } else if (e.type == DioExceptionType.connectionError) {
        throw MegaResponse(message: '❌ Sem conexão!\n\nVerifique sua conexão com a internet e tente novamente.', statusCode: 0);
      } else if (e.type == DioExceptionType.badResponse) {
        throw MegaResponse(message: '❌ Erro de comunicação!\n\nHouve um problema na comunicação com o servidor. Tente novamente.', statusCode: e.response?.statusCode ?? 0);
      } else {
        throw MegaResponse(message: '❌ Erro inesperado!\n\nTente novamente ou entre em contato com o suporte técnico.', statusCode: e.response?.statusCode ?? 0);
      }
    } catch (e) {
      if (e is MegaResponse) {
        rethrow;
      } else {
        // Log do erro para debug
        print('[RequestAppointmentProvider] Erro inesperado: $e');
        throw MegaResponse(message: '❌ Erro inesperado!\n\nTente novamente ou entre em contato com o suporte técnico.', statusCode: 0);
      }
    }
  }
}
