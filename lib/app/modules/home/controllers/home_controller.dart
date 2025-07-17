import 'dart:developer' as console;

import 'package:flutter/foundation.dart'; // Import adicionado para debugPrint
import 'package:flutter/scheduler.dart';
import 'package:mega_commons/shared/models/abbreviation.dart';
import 'package:mega_commons/shared/models/auth_token.dart';
import 'package:mega_commons/shared/utils/mega_one_signal_config.dart';
import 'package:mega_commons/shared/utils/mega_request_utils.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_payment/mega_payment.dart';

import '../../../../.env.dart';
import '../../../core/core.dart';
import '../../../core/utils/auth_helper.dart';
import '../../../data/models/mechanic_workshop.dart';
import '../../../data/models/service.dart';
import '../../../data/providers/home_provider.dart';
import '../../../data/providers/user_profile_provider.dart';
import '../../app_filter/controllers/filter_controller.dart';

class HomeController extends GetxController {
  HomeController({
    required HomeProvider homeProvider,
    required UserProfileProvider profileProvider,
    required FilterController filterController,
  })  : _homeProvider = homeProvider,
        _profileProvider = profileProvider,
        _filterController = filterController;

  final HomeProvider _homeProvider;
  final UserProfileProvider _profileProvider;
  final FilterController _filterController;

  final hasRequestPermission = RxBool(false);
  final _isGettingLocation = RxBool(true);

  bool get isGettingLocation => _isGettingLocation.value;
  int get rating => _filterController.rating;
  double get distance => _filterController.distance;
  List<Service> get services => _filterController.selectedCategories;
  List<Service> get availableCategories =>
      _filterController.availableCategories;

  final PagingController<int, Service> servicesPagingController =
      PagingController(firstPageKey: 1);
  final _servicesLimit = 30;

  final PagingController<int, MechanicWorkshop> workshopsPagingController =
      PagingController(firstPageKey: 1);
  final _workshopsLimit = 30;

  Position? userPosition;

  @override
  Future<void> onInit() async {
    workshopsPagingController.addPageRequestListener(getWorkshops);
    servicesPagingController.addPageRequestListener(getServices);

    // Verifica e atualiza o status do usu��rio para corrigir problemas de persistência do modo visitante
    await refreshUserStatus();

    if (!AuthHelper.isGuest) {
      console.log('User is logged in, fetching profile info and registering device ID');
      await getProfileInfo();
      await registerDeviceID();
    }

    await _checkPermission();
    _setupStripeConfig();
    super.onInit();
  }

  /// Configuração da Stripe
  /// [pk_live] e [sk_live] são as chaves de produção
  /// [pk_test] e [sk_test] são as chaves de teste
  ///
  /// As chaves de produção devem ser usadas apenas em produção
  Future<void> _setupStripeConfig() async {
    final pk = Env.abbreviation == Abbreviation.development ? pk_test : pk_live;
    final sk = Env.abbreviation == Abbreviation.development ? sk_test : sk_live;

    await StripeConfig.init(
      publishableKey: pk,
      secretKey: sk,
      merchantIdentifier: 'merchant.meca.stripe',
      urlScheme: 'flutterstripe',
      merchantDisplayName: 'Meca Pagamentos',
    );
  }

  Future<void> _checkPermission() async {
    _isGettingLocation.value = true;
    final permission = await Permission.location.status;
    hasRequestPermission.value = permission.isGranted;

    await _getLocation();
    _isGettingLocation.value = false;
  }

  Future<void> requestPermission() async {
    _isGettingLocation.value = true;

    final status = await Permission.location.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      final newStatus = await Permission.location.request();
      hasRequestPermission.value = newStatus.isGranted;
    } else {
      hasRequestPermission.value = status.isGranted;
    }

    if (hasRequestPermission.value) {
      await _getLocation();
    }

    _isGettingLocation.value = false;
  }

  Future<void> _getLocation() async {
    if (hasRequestPermission.value) {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10), // Adicionando timeout para não travar a UI
        );
        userPosition = position;
        console.log('Localização obtida com sucesso: ${position.latitude}, ${position.longitude}', name: 'HomeController');
      } catch (e) {
        console.log('Erro ao obter localização: $e. Tentando obter última posição conhecida...', name: 'HomeController');

        // Tenta obter a última posição conhecida como fallback
        try {
          final lastPosition = await Geolocator.getLastKnownPosition();
          if (lastPosition != null) {
            userPosition = lastPosition;
            console.log('Última localização conhecida obtida: ${lastPosition.latitude}, ${lastPosition.longitude}', name: 'HomeController');
          } else {
            console.log('Nenhuma localização disponível. Distâncias podem ser imprecisas.', name: 'HomeController');
          }
        } catch (e2) {
          console.log('Erro ao obter última localização conhecida: $e2', name: 'HomeController');
        }
      } finally {
        // Sempre atualiza a lista de oficinas, mesmo sem localização
        workshopsPagingController.refresh();
        servicesPagingController.refresh();
      }
    } else {
      // Mesmo sem permissão, atualiza a lista (mostrarão distância 0)
      workshopsPagingController.refresh();
      servicesPagingController.refresh();
    }
  }

  Future<void> getWorkshops(int page) async {
    // Utilizando SchedulerBinding para garantir que a atualização de estado ocorra após o build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _isGettingLocation.value = true;
    });

    // Verifica se é usuário visitante
    if (AuthHelper.isGuest) {
      // Para visitantes, retorna uma lista vazia ou dados mockados
      workshopsPagingController.appendLastPage([]);
      // Utilizando SchedulerBinding para garantir que a atualização de estado ocorra após o build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _isGettingLocation.value = false;
      });
      return;
    }

    // Se a localização não estiver disponível e a permissão for concedida, tenta obtê-la novamente
    // e AGUARDA que a operação seja concluída
    if (userPosition == null && hasRequestPermission.value) {
      console.log('Localização não disponível. Tentando obter novamente...', name: 'HomeController');
      try {
        userPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        console.log('Localização obtida com sucesso durante getWorkshops: ${userPosition!.latitude}, ${userPosition!.longitude}', name: 'HomeController');
      } catch (e) {
        console.log('Erro ao obter localização durante getWorkshops: $e', name: 'HomeController');
        // Continua com a execução para mostrar oficinas mesmo sem localização
      }
    }

    // Adiciona logs de debug para verificar as coordenadas antes da chamada da API
    debugPrint('Coordenadas do usuário antes de chamar API: Lat=${userPosition?.latitude}, Long=${userPosition?.longitude}');

    await MegaRequestUtils.load(
      action: () async {
        try {
          // Garantimos que a localização foi obtida antes de chamar a API
          final response = await _homeProvider.onRequestWorkshops(
            latUser: userPosition?.latitude,
            longUser: userPosition?.longitude,
            page: page,
            limit: _workshopsLimit,
            rating: rating > 0 ? rating : null,
            distance: distance > 50 ? 50 : distance.toInt(),
            serviceType: services.map((service) => service.id!).toList(),
            search: _filterController.searchQuery,
          );

          // Se a resposta está vazia, mas a posição do usuário é nula, isso pode indicar
          // que o backend não conseguiu calcular as distâncias
          if (response.isEmpty && page == 1 && userPosition == null) {
            console.log('Lista de oficinas vazia. Posição do usuário é nula, o que pode ser a causa.', name: 'HomeController');
          }

          // Verifica se a lista de oficinas está vazia
          if (response.isEmpty && page == 1) {
            // Mesmo sem oficinas, precisa marcar a lista como vazia para mostrar a mensagem
            workshopsPagingController.appendLastPage([]);
            return;
          }

          // Verifica se as oficinas têm distância zero e alerta sobre o problema
          if (response.isNotEmpty && response.every((workshop) => workshop.distance == 0)) {
            console.log('Todas as oficinas estão com distância zero. Posição do usuário: ${userPosition?.latitude}, ${userPosition?.longitude}', name: 'HomeController');
          }

          // Adiciona logs para cada oficina para verificar o cálculo da distância
          for (final workshop in response) {
            debugPrint('Oficina ${workshop.fullName}: Lat=${workshop.latitude}, Long=${workshop.longitude}, Distância=${workshop.distance}km');

            // Se a oficina tem coordenadas e o usuário também, mas a distância é 0, recalcula
            if (userPosition != null &&
                workshop.latitude != null &&
                workshop.longitude != null &&
                workshop.distance == 0) {
              // Recalcula a distância localmente
              final distanceInMeters = Geolocator.distanceBetween(
                userPosition!.latitude,
                userPosition!.longitude,
                workshop.latitude!,
                workshop.longitude!
              );

              // Converte para km e atribui ao modelo
              workshop.distance = (distanceInMeters / 1000).round();
              debugPrint('Distância recalculada para ${workshop.fullName}: ${workshop.distance}km');
            }
          }

          // Filtra localmente para garantir que só oficinas até 50km sejam exibidas
          final filtered = response.where((workshop) => workshop.distance != null && workshop.distance! <= 50).toList();
          final isLastPage = filtered.length < _workshopsLimit;
          if (isLastPage) {
            workshopsPagingController.appendLastPage(filtered);
          } else {
            final nextPageKey = page + 1;
            workshopsPagingController.appendPage(filtered, nextPageKey);
          }
        } catch (e) {
          workshopsPagingController.error = e;
          console.log('Erro ao buscar oficinas: $e', name: 'HomeController');
        }
      },
      onError: (_) {
        // Garantir que o estado de carregamento seja finalizado mesmo em caso de erro
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _isGettingLocation.value = false;
        });
      },
      onFinally: () {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _isGettingLocation.value = false;
        });
      },
    );
  }

  Future<void> getServices(int page) async {
    if (AuthHelper.isGuest) {
      servicesPagingController.appendLastPage([]);
      return;
    }
    await MegaRequestUtils.load(
      action: () async {
        final response = await _homeProvider.onRequestServices(
          page: page,
          limit: _servicesLimit,
        );

        _filterController.updateAvailableCategories(response);

        final isLastPage = response.length < _servicesLimit;
        if (isLastPage) {
          servicesPagingController.appendLastPage(response);
        } else {
          final nextPageKey = page + 1;
          servicesPagingController.appendPage(response, nextPageKey);
        }
      },
    );
  }

  Future<void> getProfileInfo() async {
    await MegaRequestUtils.load(
      action: () async {
        final profileInfo = await _profileProvider.getProfileInfo();
        await profileInfo.save();
      },
    );
  }

  Future<void> registerDeviceID() async {
    await MegaRequestUtils.load(
      action: () async {
        final String? deviceId = MegaOneSignalConfig.fromCache();
        if (deviceId != null) {
          await _profileProvider.onRegisterUnregister(
            deviceId: deviceId,
            isRegister: true,
          );
        }
      },
    );
  }

  // Método para atualizar o status do usuário com base no token de autenticação
  Future<void> refreshUserStatus() async {
    final token = AuthToken.fromCache();
    if (token != null) {
      // Se há um token válido, mas o sistema ainda considera como visitante,
      // atualiza o status para usuário logado
      if (AuthHelper.isGuest) {
        console.log('Token found but user marked as guest. Updating status...', name: 'HomeController');
        AuthHelper.setLoggedIn();
      }
    } else {
      // Se não há token e o usuário não está marcado como visitante,
      // define como visitante para evitar erros
      if (!AuthHelper.isGuest && !AuthHelper.isLoggedIn) {
        console.log('No token found and user not marked as guest. Setting as guest...', name: 'HomeController');
        await AuthHelper.setGuest();
      }
    }
  }

  void updateFilters({
    String? searchQuery,
    List<Service>? selectedCategories,
    double? priceRangeInitial,
    double? priceRangeFinal,
    int? rating,
    double? distance,
  }) {
    _filterController.updateFilters(
      searchQuery: searchQuery,
      selectedCategories: selectedCategories,
      rating: rating,
      distance: distance,
    );
    workshopsPagingController.refresh();
  }

  @override
  void onClose() {
    _filterController.clearFilters();
    super.onClose();
  }
}
