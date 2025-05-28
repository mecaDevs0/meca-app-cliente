import 'package:mega_commons/shared/models/abbreviation.dart';
import 'package:mega_commons/shared/utils/mega_one_signal_config.dart';
import 'package:mega_commons/shared/utils/mega_request_utils.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_payment/mega_payment.dart';

import '../../../../.env.dart';
import '../../../core/core.dart';
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
    await getProfileInfo();
    registerDeviceID();
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
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      userPosition = position;
      workshopsPagingController.refresh();
      servicesPagingController.refresh();
    }
  }

  Future<void> getWorkshops(int page) async {
    await MegaRequestUtils.load(
      action: () async {
        final response = await _homeProvider.onRequestWorkshops(
          page: page,
          limit: _workshopsLimit,
          search: _filterController.searchQuery.isNotEmpty
              ? _filterController.searchQuery
              : null,
          serviceType: _filterController.selectedCategories.isNotEmpty
              ? _filterController.selectedCategories
                  .map((category) => category.id ?? '')
                  .toList()
              : null,
          rating:
              _filterController.rating > 0 ? _filterController.rating : null,
          distance: _filterController.distance.toInt(),
          latUser: userPosition?.latitude,
          longUser: userPosition?.longitude,
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

  Future<void> getServices(int page) async {
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
