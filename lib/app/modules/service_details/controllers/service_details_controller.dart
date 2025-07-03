import 'package:flutter/scheduler.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/args/service_args.dart';
import '../../../data/models/mechanic_workshop.dart';
import '../../../data/models/service.dart';
import '../../../data/providers/services_provider.dart';
import '../../home/controllers/home_controller.dart';

class ServiceDetailsController extends GetxController {
  ServiceDetailsController({required ServicesProvider servicesProvider})
      : _servicesProvider = servicesProvider;

  final ServicesProvider _servicesProvider;

  final _isLoading = RxBool(false);
  final _loadingMessage = RxString('');
  final _serviceDetail = Rx<Service?>(null);
  final _hasError = RxBool(false);
  final _errorMessage = RxString('');

  bool get isLoading => _isLoading.value;
  bool get hasError => _hasError.value;
  String get errorMessage => _errorMessage.value;
  Service? get serviceDetail => _serviceDetail.value;

  HomeController? _homeController;
  HomeController get homeController {
    _homeController ??= Get.find<HomeController>();
    return _homeController!;
  }

  final PagingController<int, MechanicWorkshop> workshopsPagingController =
      PagingController(firstPageKey: 1);
  final _workshopsLimit = 30;

  final List<String> _serviceType = [''];

  String? selectedServiceId;

  @override
  Future<void> onInit() async {
    super.onInit();

    // Inicializa os controllers com segurança
    try {
      workshopsPagingController.addPageRequestListener(_safeGetWorkshops);

      final service = Get.arguments as ServiceArgs;
      selectedServiceId = service.serviceId;

      if (selectedServiceId != null && selectedServiceId!.isNotEmpty) {
        _serviceType.clear();
        _serviceType.add(selectedServiceId ?? '');

        // Executa após a construção da tela para evitar erros de estado
        SchedulerBinding.instance.addPostFrameCallback((_) {
          getDetailedService();
        });
      } else {
        _hasError.value = true;
        _errorMessage.value = 'ID de serviço inválido';
      }
    } catch (e) {
      _hasError.value = true;
      _errorMessage.value = 'Erro ao inicializar: ${e.toString()}';
      debugPrint('Erro em ServiceDetailsController.onInit: ${e.toString()}');
    }
  }

  // Wrapper seguro para evitar erros de estado
  Future<void> _safeGetWorkshops(int page) async {
    try {
      await getWorkshops(page);
    } catch (e) {
      debugPrint('Erro ao buscar oficinas: ${e.toString()}');
      if (!workshopsPagingController.error) {
        workshopsPagingController.error = e;
      }
    }
  }

  Future<void> getDetailedService() async {
    if (selectedServiceId == null || selectedServiceId!.isEmpty) {
      _hasError.value = true;
      _errorMessage.value = 'ID de serviço não especificado';
      return;
    }

    _isLoading.value = true;
    _hasError.value = false;
    _loadingMessage.value = 'Carregando detalhes do serviço...';

    try {
      await MegaRequestUtils.load(
        action: () async {
          final response =
              await _servicesProvider.onRequestService(selectedServiceId!);

          if (response != null) {
            _serviceDetail.value = response;
          } else {
            _hasError.value = true;
            _errorMessage.value = 'Serviço não encontrado';
          }
        },
        onError: (error) {
          _hasError.value = true;
          _errorMessage.value = 'Erro ao buscar detalhes do serviço: $error';
          debugPrint('Erro em getDetailedService: $error');
        },
        onFinally: () => _isLoading.value = false,
      );
    } catch (e) {
      _isLoading.value = false;
      _hasError.value = true;
      _errorMessage.value = 'Erro inesperado: ${e.toString()}';
      debugPrint('Exceção em getDetailedService: ${e.toString()}');
    }

    // Atualiza a lista de oficinas de forma segura
    SchedulerBinding.instance.addPostFrameCallback((_) {
      workshopsPagingController.refresh();
    });
  }

  Future<void> getWorkshops(int page) async {
    if (_serviceType.isEmpty || _serviceType.first.isEmpty) {
      workshopsPagingController.appendLastPage([]);
      return;
    }

    try {
      await MegaRequestUtils.load(
        action: () async {
          // Verifica se temos acesso à localização do usuário
          final latUser = homeController.userPosition?.latitude;
          final longUser = homeController.userPosition?.longitude;

          final response = await _servicesProvider.onRequestWorkshops(
            page: page,
            limit: _workshopsLimit,
            serviceType: _serviceType,
            latUser: latUser,
            longUser: longUser,
          );

          if (response.isEmpty && page == 1) {
            workshopsPagingController.appendLastPage([]);
            return;
          }

          final isLastPage = response.length < _workshopsLimit;
          if (isLastPage) {
            workshopsPagingController.appendLastPage(response);
          } else {
            final nextPageKey = page + 1;
            workshopsPagingController.appendPage(response, nextPageKey);
          }
        },
        onError: (error) {
          workshopsPagingController.error = error;
          debugPrint('Erro em getWorkshops: $error');
        },
      );
    } catch (e) {
      workshopsPagingController.error = e;
      debugPrint('Exceção em getWorkshops: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    workshopsPagingController.dispose();
    super.dispose();
  }
}
