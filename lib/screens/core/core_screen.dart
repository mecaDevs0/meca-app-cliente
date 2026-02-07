import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/theme_service.dart';
import '../../services/api_service.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../home/home_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';
import '../workshops/workshops_screen.dart';

class CoreScreen extends StatefulWidget {
  final int? initialIndex;
  final int? ordersInitialTab;

  const CoreScreen({
    Key? key,
    this.initialIndex,
    this.ordersInitialTab,
  }) : super(key: key);

  @override
  State<CoreScreen> createState() => _CoreScreenState();
}

class _CoreScreenState extends State<CoreScreen> with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late PageController _pageController;
  final ApiService _apiService = ApiService();
  
  final List<Widget> _pages = [
    const HomeScreen(),
    const WorkshopsScreen(),
    const OrdersScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshUnreadNotifications();
      if (_currentIndex == _pages.length - 1) {
        Provider.of<NotificationProvider>(context, listen: false).markProfileBadgeSeen();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    if (index == _pages.length - 1) {
      Provider.of<NotificationProvider>(context, listen: false).markProfileBadgeSeen();
    } else {
      _refreshUnreadNotifications();
    }
  }

  void _onNavTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    if (index == _pages.length - 1) {
      Provider.of<NotificationProvider>(context, listen: false).markProfileBadgeSeen();
    }
  }

  Future<void> _refreshUnreadNotifications() async {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    try {
      // PROTEÇÃO: Se usuário já marcou como lidas (contador = 0), NÃO sobrescrever
      if (notificationProvider.unreadNotifications == 0 && notificationProvider.notifications.isNotEmpty) {
        print('🔒 [CoreScreen] Mantendo notificações locais (já marcadas como lidas)');
        return;
      }
      
      final result = await _apiService.getNotifications(limit: 100);
      if (result['success'] == true) {
        final data = result['data'];
        notificationProvider.setNotificationsFromPayload(data);
      }
    } catch (e) {
      // Apenas logar no debug para evitar travamentos na UI
      debugPrint('Erro ao atualizar notificações: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          body: PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: _pages,
          ),
          bottomNavigationBar: CustomBottomNav(
            currentIndex: _currentIndex,
            onTap: _onNavTap,
            items: const [
              BottomNavItem(
                icon: Icons.home,
                activeIcon: Icons.home,
                label: 'Início',
              ),
              BottomNavItem(
                icon: Icons.build,
                activeIcon: Icons.build,
                label: 'Oficinas',
              ),
              BottomNavItem(
                icon: Icons.schedule,
                activeIcon: Icons.schedule,
                label: 'Agendamentos',
              ),
              BottomNavItem(
                icon: Icons.person,
                activeIcon: Icons.person,
                label: 'Perfil',
              ),
            ],
          ),
        );
      },
    );
  }

}



















