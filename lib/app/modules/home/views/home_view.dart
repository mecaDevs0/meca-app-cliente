import 'dart:developer' as console;

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_images.dart';
import '../../../core/args/workshop_args.dart';
import '../../../core/modals/app_bottom_sheet.dart';
import '../../../core/utils/auth_helper.dart';
import '../../../core/utils/guest_access_helper.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../../../core/widgets/app_filter_bottom_sheet.dart';
import '../../../data/models/mechanic_workshop.dart';
import '../../../routes/app_pages.dart';
import '../../app_filter/view/app_filter.dart';
import '../controllers/home_controller.dart';
import 'widgets/mechanic_workshops/card/mechanic_workshop_card.dart';
import 'widgets/search_bar.dart';
import 'widgets/services/services_list.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends MegaState<HomeView, HomeController> {
  final _searchController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    // Verificando se o usuário possui um token válido e atualizando o status de visitante
    final token = AuthToken.fromCache();
    if (token != null && AuthHelper.isGuest) {
      // Se há um token válido mas o usuário ainda está marcado como visitante,
      // atualiza o status imediatamente
      AuthHelper.setLoggedIn();
      print('Token encontrado mas usuário estava marcado como visitante. Status atualizado.');
    }

    print('isGuest no HomeView: ${AuthHelper.isGuest}');
    ever(controller.hasRequestPermission, (bool hasPermission) {
      if (!hasPermission) {
        AppBottomSheet.showLocationBottomSheet(
          context,
          onRequestPermission: controller.requestPermission,
        );
      }
    });

// Timer para forçar logout do visitante após alguns segundos
    if (AuthHelper.isGuest) {
      Future.delayed(const Duration(minutes: 10), () {
        if (mounted && AuthHelper.isGuest) {
          AuthHelper.logout();
          Get.offAllNamed(Routes.login);
        }
      });
    }

    super.initState();
  }

  void _applyFilters(FilterParams filter) {
    controller.updateFilters(
      searchQuery: _searchController.text,
      selectedCategories: filter.services,
      rating: filter.rating,
      distance: filter.distance,
    );
    controller.workshopsPagingController.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBarCustom(
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
          child: SvgPicture.asset(AppImages.homeLogo),
        ),
        backgroundColor: AppColors.primaryColor,
        actions: [
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: IconButton(
              icon: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SvgPicture.asset(AppImages.icNotifications),
              ),
              iconSize: 44,
              splashRadius: 24,
              onPressed: () {
                if (AuthHelper.isGuest) {
                  console.log('Usuário visitante tentando acessar notificações');
                  Get.offAllNamed(Routes.login);
                } else {
                  Get.toNamed(Routes.notifications);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: IconButton(
              icon: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SvgPicture.asset(AppImages.icMenuHamburguer),
              ),
              iconSize: 44,
              splashRadius: 24,
              onPressed: () {
                if (AuthHelper.isGuest) {
                  Get.offAllNamed(Routes.login);
                } else {
                  _scaffoldKey.currentState?.openDrawer();
                }
              },
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Definição mais precisa do que é um tablet para melhor adaptação
          final isTablet = constraints.maxWidth > 600;
          // Ajuste adicional para iPads maiores
          final isLargeTablet = constraints.maxWidth > 900;

          if (isTablet) {
            return _buildTabletLayout(constraints, isLargeTablet);
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  Widget _buildTabletLayout(BoxConstraints constraints, bool isLargeTablet) {
    // Ajustar a proporção da barra lateral baseado no tamanho do tablet
    final sidebarWidth = isLargeTablet
        ? constraints.maxWidth * 0.3  // Menor proporção para iPad Pro
        : constraints.maxWidth * 0.35; // Proporção para iPad normal

    final sidebarPadding = EdgeInsets.all(isLargeTablet ? 24.0 : 16.0);
    final sectionSpacing = SizedBox(height: isLargeTablet ? 32.0 : 24.0);
    final titleStyle = TextStyle(
      fontSize: isLargeTablet ? 22.0 : 18.0,
      fontWeight: FontWeight.bold,
      color: AppColors.primaryColor,
    );

    final searchTextStyle = TextStyle(
      fontSize: isLargeTablet ? 18.0 : 16.0,
    );

    final mainAreaPadding = EdgeInsets.all(isLargeTablet ? 24.0 : 16.0);
    final mainTitleStyle = TextStyle(
      fontSize: isLargeTablet ? 24.0 : 20.0,
      fontWeight: FontWeight.bold,
      color: AppColors.primaryColor,
    );

    return Row(
      children: [
        // Painel lateral com busca e serviços - Ajustado para ser mais proporcional
        Container(
          width: sidebarWidth,
          padding: sidebarPadding,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              right: BorderSide(color: AppColors.grayBorderColor, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isLargeTablet ? 24.0 : 16.0),
              // Barra de busca com tamanho aumentado para iPad
              SearchBarWidget(
                controller: _searchController,
                onSearchChanged: (value) =>
                    controller.updateFilters(searchQuery: value),
                onFilterTap: () => showFilterBottomSheet(
                  context: context,
                  initialParams: FilterParams(
                    rating: controller.rating,
                    services: controller.services,
                    distance: controller.distance,
                  ),
                  onTap: _applyFilters,
                  availableCategories: controller.availableCategories,
                ),
                hintText: 'O que você procura?',
                hasFilter: true,
                // Aumentar o tamanho da fonte para iPads
                textStyle: searchTextStyle,
              ),
              sectionSpacing,
              // Título com tamanho maior
              Text(
                'Serviços',
                style: titleStyle,
              ),
              SizedBox(height: isLargeTablet ? 24.0 : 16.0),
              // Lista de serviços
              const Expanded(child: ServicesList()),
            ],
          ),
        ),
        // Área principal com lista de oficinas
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: mainAreaPadding,
                child: Text(
                  'Oficinas próximas',
                  style: mainTitleStyle,
                ),
              ),
              Expanded(
                child: Obx(() {
                  if (controller.isGettingLocation) {
                    return _buildWorkshopsLoadingGrid(isLargeTablet);
                  }
                  return _buildWorkshopsGrid(isLargeTablet);
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkshopsLoadingGrid(bool isLargeTablet) {
    final horizontalPadding = EdgeInsets.symmetric(horizontal: isLargeTablet ? 24.0 : 16.0);
    final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      // Número de colunas ajustado ao tamanho da tela
      crossAxisCount: isLargeTablet ? 3 : 2,
      mainAxisSpacing: isLargeTablet ? 24 : 16,
      crossAxisSpacing: isLargeTablet ? 24 : 16,
      // Ajuste da proporção para melhor visualização
      childAspectRatio: isLargeTablet ? 1.3 : 1.2,
    );

    return GridView.builder(
      padding: horizontalPadding,
      gridDelegate: gridDelegate,
      itemCount: 6,
      itemBuilder: (context, index) => Skeletonizer(
        child: MechanicWorkshopCard(
          mechanicWorkshop: MechanicWorkshop(
            fullName: 'Oficina',
            streetAddress: 'Endereço',
            distance: 12,
            rating: 5,
          ),
          onTap: null,
          // Aumentar tamanho dos elementos para iPad
          isTablet: true,
        ),
      ),
    );
  }

  Widget _buildWorkshopsGrid(bool isLargeTablet) {
    final horizontalPadding = EdgeInsets.symmetric(horizontal: isLargeTablet ? 24.0 : 16.0);
    final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: isLargeTablet ? 3 : 2,
      mainAxisSpacing: isLargeTablet ? 24 : 16,
      crossAxisSpacing: isLargeTablet ? 24 : 16,
      childAspectRatio: isLargeTablet ? 1.3 : 1.2,
    );

    return GridView.builder(
      padding: horizontalPadding,
      gridDelegate: gridDelegate,
      itemCount: controller.workshopsPagingController.itemList?.length ?? 0,
      itemBuilder: (context, index) {
        final workshop = controller.workshopsPagingController.itemList![index];
        return MechanicWorkshopCard(
          mechanicWorkshop: workshop,
          onTap: () => Get.toNamed(
            Routes.mechanicWorkshopDetails,
            arguments: WorkshopArgs(workshop.id!, workshopName: workshop.fullName),
          ),
          // Passar indicador de tablet para ajustar elementos internos
          isTablet: true,
        );
      },
    );
  }

  Widget _buildMobileLayout() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 16),
              SearchBarWidget(
                controller: _searchController,
                onSearchChanged: (value) =>
                    controller.updateFilters(searchQuery: value),
                onFilterTap: () => showFilterBottomSheet(
                  context: context,
                  initialParams: FilterParams(
                    rating: controller.rating,
                    services: controller.services,
                    distance: controller.distance,
                  ),
                  onTap: _applyFilters,
                  availableCategories: controller.availableCategories,
                ),
                hintText: 'O que você procura?',
                hasFilter: true,
              ),
              const SizedBox(height: 32),
              const SizedBox(
                height: 200,
                child: ServicesList(),
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ),
        Obx(() {
          if (controller.isGettingLocation) {
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Skeletonizer(
                      child: MechanicWorkshopCard(
                        mechanicWorkshop: MechanicWorkshop(
                          fullName: 'Oficina',
                          streetAddress: 'Endereço',
                          distance: 12,
                          rating: 5,
                        ),
                        onTap: () {},
                      ),
                    ),
                  ),
                  childCount: 6,
                ),
              ),
            );
          }
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: _buildWorkshopsList(),
          );
        }),
      ],
    );
  }

  Widget _buildWorkshopsList() {
    return SliverToBoxAdapter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Oficinas',
                style: TextStyle(
                  color: AppColors.blackPrimaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              InkWell(
                onTap: () {
                  if (GuestAccessHelper.checkGuestAccess(context)) {
                    Get.toNamed(Routes.mechanicWorkshops);
                  }
                },
                child: const Text(
                  'Ver todos',
                  style: TextStyle(
                    color:
                    AppColors.primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 400,
            child: RefreshIndicator(
              onRefresh: () => Future.sync(
                () => controller.workshopsPagingController.refresh(),
              ),
              child: PagedListView<int, MechanicWorkshop>(
                pagingController: controller.workshopsPagingController,
                builderDelegate: PagedChildBuilderDelegate<MechanicWorkshop>(
                  itemBuilder: (context, item, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: MechanicWorkshopCard(
                      mechanicWorkshop: item,
                      onTap: () {
                        if (GuestAccessHelper.checkGuestAccess(context)) {
                          Get.toNamed(
                            Routes.mechanicWorkshopDetails,
                            arguments: WorkshopArgs(item.id!, workshopName: item.fullName),
                          );
                        }
                      },
                    ),
                  ),
                  noItemsFoundIndicatorBuilder: (context) => Obx(() {
                    if (!controller.hasRequestPermission.value) {
                      // Quando não tem permissão de localização
                      return EmptyListIndicator(
                        isShowIcon: true,
                        title: 'Não foi possível encontrar oficinas próximas a você',
                        message: 'Para ver oficinas próximas, permita o acesso à sua localização',
                      );
                    } else {
                      // Quando tem permissão, mas não encontrou oficinas próximas
                      return const EmptyListIndicator(
                        isShowIcon: true,
                        title: 'Não encontramos oficinas próximas a você',
                        message: 'Tente ajustar seus filtros de busca ou ampliar a distância máxima',
                      );
                    }
                  }),
                  firstPageErrorIndicatorBuilder: (context) => ErrorIndicator(
                    onTryAgain: () => controller.workshopsPagingController.refresh(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            children: [
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: DrawerHeader(
                      child: Column(
                        children: [
                          Expanded(
                            child: SvgPicture.asset(
                              AppImages.headerMenuHome,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: SvgPicture.asset(AppImages.loginLogo),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 32,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: SvgPicture.asset(
                        AppImages.icCloseMenu,
                        height: 24,
                        width: 24,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Row(
                  children: [
                    SvgPicture.asset(AppImages.icHome),
                    const SizedBox(width: 10),
                    const Text('Início'),
                  ],
                ),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Row(
                  children: [
                    SvgPicture.asset(AppImages.icCarHome),
                    const SizedBox(width: 10),
                    const Text('Meus veículos'),
                  ],
                ),
                onTap: () {
                  if (GuestAccessHelper.checkGuestAccess(context)) {
                    Get.toNamed(Routes.myVehicles);
                  }
                },
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Row(
                  children: [
                    SvgPicture.asset(
                      AppImages.icOrders,
                      colorFilter: const ColorFilter.mode(
                        AppColors.softBlackColor,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('Pedidos'),
                  ],
                ),
                onTap: () {
                  if (AuthHelper.isGuest) {
                    console.log('Usuário visitante tentando acessar pedidos');
                    Get.offAllNamed(Routes.login);
                  } else {
                    Get.toNamed(Routes.ordersPlaced);
                  }
                },
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Row(
                  children: [
                    SvgPicture.asset(AppImages.icUserHome),
                    const SizedBox(width: 10),
                    const Text(
                      'Meu perfil',
                      style: TextStyle(
                        color: AppColors.softBlackColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  if (AuthHelper.isGuest) {
                    console.log('Usuário visitante tentando acessar meu perfil');
                    Get.offAllNamed(Routes.login);
                  } else {
                    Get.toNamed(Routes.userProfile);
                  }
                },
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Row(
                  children: [
                    SvgPicture.asset(AppImages.icHelp),
                    const SizedBox(width: 10),
                    const Text(
                      'Central de ajuda',
                      style: TextStyle(
                        color: AppColors.softBlackColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  if (AuthHelper.isGuest) {
                    console.log('Usuário visitante tentando acessar central de ajuda');
                    Get.offAllNamed(Routes.login);
                  } else {
                    Get.toNamed(Routes.helpCenter);
                  }
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child:
                SvgPicture.asset(AppImages.carMenuHome, height: 60, width: 60),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkshopsSliverGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return PagedListView<int, MechanicWorkshop>(
            pagingController: controller.workshopsPagingController,
            builderDelegate: PagedChildBuilderDelegate<MechanicWorkshop>(
              itemBuilder: (context, workshop, index) {
                return MechanicWorkshopCard(
                  mechanicWorkshop: workshop,
                  onTap: () {
                    if (AuthHelper.isGuest) {
                      console.log('Usuário visitante tentando acessar detalhes da oficina');
                      Get.offAllNamed(Routes.login);
                    } else {
                      Get.toNamed(
                        Routes.mechanicWorkshopDetails,
                        arguments: WorkshopArgs(workshop.id!, workshopName: workshop.fullName),
                      );
                    }
                  },
                );
              },
              firstPageErrorIndicatorBuilder: (context) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.grayBorderColor,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Erro ao carregar oficinas',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.blackSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => controller.workshopsPagingController.refresh(),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
              noItemsFoundIndicatorBuilder: (context) => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: AppColors.grayBorderColor,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Nenhuma oficina encontrada',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.blackSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: 1,
      ),
    );
  }
}
