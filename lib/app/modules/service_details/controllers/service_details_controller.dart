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

  bool get isLoading => _isLoading.value;
  Service? get serviceDetail => _serviceDetail.value;

  final HomeController homeController = Get.find();

  final PagingController<int, MechanicWorkshop> workshopsPagingController =
      PagingController(firstPageKey: 1);
  final _workshopsLimit = 30;

  final List<String> _serviceType = [''];

  late String? selectedServiceId;

  @override
  Future<void> onInit() async {
    workshopsPagingController.addPageRequestListener(getWorkshops);

    final service = Get.arguments as ServiceArgs;
    selectedServiceId = service.serviceId;
    _serviceType.clear();
    _serviceType.add(selectedServiceId ?? '');
    await getDetailedService();
    super.onInit();
  }

  Future<void> getDetailedService() async {
    if (selectedServiceId.isNullOrEmpty) {
      return;
    }

    _isLoading.value = true;
    _loadingMessage.value = 'Carregando detalhes do serviço...';
    await MegaRequestUtils.load(
      action: () async {
        final response =
            await _servicesProvider.onRequestService(selectedServiceId!);
        _serviceDetail.value = response;
      },
      onFinally: () => _isLoading.value = false,
    );

    workshopsPagingController.refresh();
  }

  Future<void> getWorkshops(int page) async {
    await MegaRequestUtils.load(
      action: () async {
        final response = await _servicesProvider.onRequestWorkshops(
          page: page,
          limit: _workshopsLimit,
          serviceType: _serviceType,
          latUser: homeController.userPosition?.latitude,
          longUser: homeController.userPosition?.longitude,
        );

        final isLastPage = response.length < _workshopsLimit;
        if (isLastPage) {
          workshopsPagingController.appendLastPage(response);
        } else {
          final nextPageKey = page + 1;
          workshopsPagingController.appendPage(response, nextPageKey);
        }
      },
    );
  }
}
