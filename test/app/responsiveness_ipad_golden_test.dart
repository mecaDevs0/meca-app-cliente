import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:meca_cliente/app/core/app_colors.dart';
import 'package:meca_cliente/app/data/models/mechanic_workshop.dart';
import 'package:meca_cliente/app/modules/home/views/home_view.dart';
import 'package:meca_cliente/app/modules/home/controllers/home_controller.dart';
import 'package:meca_cliente/app/modules/mechanic_workshop_details/views/mechanic_workshop_details_view.dart';
import 'package:meca_cliente/app/modules/mechanic_workshop_details/controllers/mechanic_workshop_details_controller.dart';
import 'package:meca_cliente/app/data/models/workshopAgenda/agenda_model.dart';
import 'package:meca_cliente/app/data/models/workshopAgenda/week_day_model.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:meca_cliente/app/modules/home/views/widgets/mechanic_workshops/card/mechanic_workshop_card.dart';

// Mocks
class MockHomeController extends GetxController with Mock implements HomeController {
  final _isGettingLocation = false.obs;
  final workshopsPagingController = PagingController<int, MechanicWorkshop>(firstPageKey: 0);
  final _services = <String>[].obs;
  final _rating = 0.obs;
  final _distance = 0.0.obs;
  final _hasRequestPermission = true.obs;
  final _availableCategories = <Map<String, dynamic>>[].obs;

  @override
  bool get isGettingLocation => _isGettingLocation.value;

  @override
  List<String> get services => _services;

  @override
  int get rating => _rating.value;

  @override
  double get distance => _distance.value;

  @override
  RxBool get hasRequestPermission => _hasRequestPermission;

  @override
  List<Map<String, dynamic>> get availableCategories => _availableCategories;

  @override
  void updateFilters({String? searchQuery, List<String>? selectedCategories, int? rating, double? distance}) {}

  @override
  void requestPermission() {}
}

class MockMechanicWorkshopDetailsController extends GetxController with Mock implements MechanicWorkshopDetailsController {
  final _isLoading = false.obs;
  MechanicWorkshop? _workshopDetails;
  String _workshopId = '1';
  AgendaModel? _workshopSchedule;

  @override
  bool get isLoading => _isLoading.value;

  @override
  MechanicWorkshop? get workshopDetails => _workshopDetails;

  @override
  String get workshopId => _workshopId;

  @override
  AgendaModel? get workshopSchedule => _workshopSchedule;

  MockMechanicWorkshopDetailsController() {
    _workshopDetails = MechanicWorkshop(
      id: '1',
      fullName: 'Oficina Mecânica Exemplo',
      companyName: 'Oficina Mecânica Exemplo Ltda',
      streetAddress: 'Av. das Nações',
      number: '1000',
      neighborhood: 'Centro',
      distance: 3.5,
      rating: 4,
      reason: 'Somos uma oficina especializada em manutenção geral de veículos.',
      cityName: 'São Paulo',
      latitude: -23.550520,
      longitude: -46.633308,
    );

    _workshopSchedule = AgendaModel(
      monday: WeekDayModel(open: true, startTime: '08:00', closingTime: '18:00'),
      tuesday: WeekDayModel(open: true, startTime: '08:00', closingTime: '18:00'),
      wednesday: WeekDayModel(open: true, startTime: '08:00', closingTime: '18:00'),
      thursday: WeekDayModel(open: true, startTime: '08:00', closingTime: '18:00'),
      friday: WeekDayModel(open: true, startTime: '08:00', closingTime: '18:00'),
      saturday: WeekDayModel(open: true, startTime: '08:00', closingTime: '12:00'),
      sunday: WeekDayModel(open: false, startTime: '', closingTime: ''),
    );
  }
}

class MockGetMaterialApp extends StatelessWidget {
  final Widget child;

  const MockGetMaterialApp({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: child,
      theme: ThemeData(
        primaryColor: AppColors.primaryColor,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: AppColors.primaryColor,
          secondary: AppColors.secondaryColor,
        ),
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    // Inicializar golden_toolkit
    await loadAppFonts();
  });

  group('Testes de Responsividade para iPad', () {
    // Configurações de tamanhos de dispositivos para testes
    final iPadMiniDevice = Device(
      name: 'iPad Mini',
      size: const Size(1024, 768), // iPad Mini em landscape
    );

    final iPadProDevice = Device(
      name: 'iPad Pro',
      size: const Size(1366, 1024), // iPad Pro 12.9" em landscape
    );

    final phoneDevice = Device(
      name: 'iPhone',
      size: const Size(375, 812), // iPhone X
    );

    testGoldens('HomeView deve exibir layout adaptativo em diferentes dispositivos',
    (WidgetTester tester) async {
      // Configurar controlador mock
      final controller = MockHomeController();

      // Adicionar oficinas de exemplo ao controller
      final workshopList = List.generate(
        6,
        (i) => MechanicWorkshop(
          id: '$i',
          fullName: 'Oficina $i',
          companyName: 'Oficina Exemplo $i',
          streetAddress: 'Av. Principal, $i',
          distance: (i + 1) * 1.5,
          rating: (i % 5) + 1,
        )
      );
      controller.workshopsPagingController.appendLastPage(workshopList);

      // Registrar o controller no GetX
      Get.put<HomeController>(controller);

      // Criar builder para testar a HomeView em diferentes dispositivos
      final builder = DeviceBuilder()
        ..overrideDevicesForAllScenarios(devices: [
          phoneDevice,
          iPadMiniDevice,
          iPadProDevice,
        ])
        ..addScenario(
          widget: MockGetMaterialApp(
            child: const HomeView(),
          ),
          name: 'home_view',
        );

      // Executar teste para todos os dispositivos configurados
      await tester.pumpDeviceBuilder(builder);

      // Comparar com imagens de referência
      await screenMatchesGolden(tester, 'home_view_responsive');
    });

    testGoldens('MechanicWorkshopDetailsView deve exibir layout adaptativo em diferentes dispositivos',
    (WidgetTester tester) async {
      // Configurar controlador mock
      final controller = MockMechanicWorkshopDetailsController();

      // Registrar o controller no GetX
      Get.put<MechanicWorkshopDetailsController>(controller);

      // Criar builder para testar a tela de detalhes em diferentes dispositivos
      final builder = DeviceBuilder()
        ..overrideDevicesForAllScenarios(devices: [
          phoneDevice,
          iPadMiniDevice,
          iPadProDevice,
        ])
        ..addScenario(
          widget: MockGetMaterialApp(
            child: const MechanicWorkshopDetailsView(),
          ),
          name: 'workshop_details_view',
        );

      // Executar teste para todos os dispositivos configurados
      await tester.pumpDeviceBuilder(builder);

      // Comparar com imagens de referência
      await screenMatchesGolden(tester, 'workshop_details_responsive');
    });

    testGoldens('MechanicWorkshopCard deve adaptar seu layout em diferentes dispositivos',
    (WidgetTester tester) async {
      // Criar um workshop de exemplo
      final workshop = MechanicWorkshop(
        id: '1',
        fullName: 'Oficina Mecânica Central',
        companyName: 'Oficina Central Ltda',
        streetAddress: 'Av. Paulista, 1000',
        distance: 2.5,
        rating: 4,
      );

      // Função helper para criar widget de card
      Widget buildCard(bool isTablet) {
        return Center(
          child: Container(
            width: isTablet ? 600 : 350,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: MechanicWorkshopCard(
              mechanicWorkshop: workshop,
              onTap: () {},
              isTablet: isTablet,
            ),
          ),
        );
      }

      // Criar builder para testar o card em diferentes dispositivos
      final builder = DeviceBuilder()
        ..addScenario(
          widget: MockGetMaterialApp(
            child: buildCard(false), // Versão mobile
          ),
          name: 'card_mobile',
        )
        ..addScenario(
          widget: MockGetMaterialApp(
            child: buildCard(true), // Versão tablet
          ),
          name: 'card_tablet',
        );

      // Executar teste para os dois cenários
      await tester.pumpDeviceBuilder(builder);

      // Comparar com imagens de referência
      await screenMatchesGolden(tester, 'workshop_card_responsive');
    });
  });
}

// Execute os testes com: flutter test --update-goldens test/app/responsiveness_ipad_golden_test.dart
