import 'dart:developer' as console;

import 'package:flutter/foundation.dart'; // Import adicionado para debugPrint
import 'package:flutter/scheduler.dart';
import 'package:mega_commons/shared/models/abbreviation.dart';
import 'package:mega_commons/shared/models/auth_token.dart';
import 'package:mega_commons/shared/utils/mega_request_utils.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_payment/mega_payment.dart';

import '../../../../.env.dart';
import '../../../core/core.dart';
import '../../../core/utils/auth_helper.dart';
import '../../../data/models/mechanic_workshop.dart';
import '../../../data/models/service.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/providers/home_provider.dart';
import '../../../data/providers/user_profile_provider.dart';
import '../../../data/providers/core_provider.dart';
import '../../app_filter/controllers/filter_controller.dart';
import '../../../services/notification_service.dart';

class HomeController extends GetxController {
  HomeController({
    required HomeProvider homeProvider,
    required UserProfileProvider profileProvider,
    required FilterController filterController,
    required CoreProvider coreProvider,
  })  : _homeProvider = homeProvider,
        _profileProvider = profileProvider,
        _filterController = filterController,
        _coreProvider = coreProvider;

  final HomeProvider _homeProvider;
  final UserProfileProvider _profileProvider;
  final FilterController _filterController;
  final CoreProvider _coreProvider;

  final hasRequestPermission = RxBool(false);
  final _isGettingLocation = RxBool(true);
  final _vehicles = RxList<Vehicle>.empty();

  bool get isGettingLocation => _isGettingLocation.value;
  int get rating => _filterController.rating;
  double get distance => _filterController.distance;
  List<Service> get services => _filterController.selectedCategories;
  List<Service> get availableCategories =>
      _filterController.availableCategories;
  List<Vehicle> get vehicles => _vehicles.toList();

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
      await loadUserVehicles();
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
        // Sempre atualiza a lista de estabelecimentos, mesmo sem localização
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

    // Removida a verificação de usuário visitante - agora todos podem acessar as APIs
    // O token anônimo será usado automaticamente pelo AuthInterceptor

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
        // Continua com a execução para mostrar estabelecimentos mesmo sem localização
      }
    }

    // Adiciona logs de debug para verificar as coordenadas antes da chamada da API
    debugPrint('Coordenadas do usuário antes de chamar API: Lat=${userPosition?.latitude}, Long=${userPosition?.longitude}');

    await MegaRequestUtils.load(
      action: () async {
        try {
          // Garantimos que a localização foi obtida antes de chamar a API
          // Só passar serviceType se houver serviços selecionados
          final serviceTypes = services.isNotEmpty 
              ? services.map((service) => service.id!).toList()
              : null;
              
          print('🔧 [HomeController] Fazendo requisição para workshops...');
          print('🔧 [HomeController] Parâmetros: latUser=${userPosition?.latitude}, longUser=${userPosition?.longitude}, page=$page, limit=$_workshopsLimit');
          
          final response = await _homeProvider.onRequestWorkshops(
            latUser: userPosition?.latitude,
            longUser: userPosition?.longitude,
            page: page,
            limit: _workshopsLimit,
            rating: rating > 0 ? rating : null,
            distance: distance > 50 ? 50 : distance.toInt(),
            serviceType: serviceTypes,
            search: _filterController.searchQuery,
          );
          
          print('🔧 [HomeController] Resposta recebida: ${response.length} workshops');
          for (int i = 0; i < response.length; i++) {
            final workshop = response[i];
            print('🔧 [HomeController] Workshop ${i + 1}: ID=${workshop.id}, CompanyName="${workshop.companyName}", FullName="${workshop.fullName}", Photo="${workshop.photo}"');
          }

          // Se a resposta está vazia, mas a posição do usuário é nula, isso pode indicar
          // que o backend não conseguiu calcular as distâncias
          if (response.isEmpty && page == 1 && userPosition == null) {
            console.log('Lista de estabelecimentos vazia. Posição do usuário é nula, o que pode ser a causa.', name: 'HomeController');
          }

                      // Verifica se a lista de estabelecimentos está vazia
          if (response.isEmpty && page == 1) {
                          // Mesmo sem estabelecimentos, precisa marcar a lista como vazia para mostrar a mensagem
            workshopsPagingController.appendLastPage([]);
            return;
          }

                      // Verifica se os estabelecimentos têm distância zero e alerta sobre o problema
          if (response.isNotEmpty && response.every((workshop) => (workshop.distance ?? 0) == 0)) {
            debugPrint('🔧 [HomeController] Todos os workshops têm distância 0, recalculando...');
            
            for (final workshop in response) {
              if (workshop.latitude != null && workshop.longitude != null) {
                final distanceInMeters = Geolocator.distanceBetween(
                  userPosition!.latitude,
                  userPosition!.longitude,
                  workshop.latitude!,
                  workshop.longitude!,
                );
                
                debugPrint('Estabelecimento ${workshop.fullName}: Lat=${workshop.latitude}, Long=${workshop.longitude}, Distância=${workshop.distance}km');
                
                if (distanceInMeters > 0) {
                  workshop.distance = distanceInMeters / 1000;
                  debugPrint('  Distância real calculada: ${workshop.distance}km');
                } else {
                  workshop.distance = 0;
                }
              }
            }
          }
          
          // Filtra localmente para garantir que só estabelecimentos até a distância escolhida sejam exibidos
          final maxDistance = distance > 50 ? 50 : distance;
          final filtered = response.where((workshop) => (workshop.distance ?? 0) <= maxDistance).toList();
          final isLastPage = filtered.length < _workshopsLimit;
          if (isLastPage) {
            workshopsPagingController.appendLastPage(filtered);
          } else {
            final nextPageKey = page + 1;
            workshopsPagingController.appendPage(filtered, nextPageKey);
          }
        } catch (e) {
          workshopsPagingController.error = e;
          console.log('Erro ao buscar estabelecimentos: $e', name: 'HomeController');
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
    // Removida a verificação de usuário visitante - agora todos podem acessar as APIs
    // O token anônimo será usado automaticamente pelo AuthInterceptor
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
        // Usar o NotificationService para registrar o dispositivo
        final notificationService = Get.find<NotificationService>();
        await notificationService.forceRegisterDevice();
      },
    );
  }

  Future<void> loadUserVehicles() async {
    if (!AuthHelper.isGuest) {
      await MegaRequestUtils.load(
        action: () async {
          final vehicles = await _coreProvider.onRequestVehicles(limit: 0);
          _vehicles.assignAll(vehicles);
        },
      );
    }
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
    // Garante que a distância nunca seja menor que 1km nem maior que 50km
    double filteredDistance = (distance ?? _filterController.distance);
    if (filteredDistance < 1) filteredDistance = 1;
    if (filteredDistance > 50) filteredDistance = 50;
    _filterController.updateFilters(
      searchQuery: searchQuery,
      selectedCategories: selectedCategories,
      rating: rating,
      distance: filteredDistance,
    );
    // Adiciona um pequeno atraso para garantir que o estado do filtro seja atualizado antes do refresh
    Future.delayed(const Duration(milliseconds: 100), () {
      workshopsPagingController.refresh();
    });
  }

  @override
  void onClose() {
    _filterController.clearFilters();
    super.onClose();
  }
}
