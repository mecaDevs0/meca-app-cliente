import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;
    _pageController = PageController(initialPage: _currentIndex);
    _pages = [
      HomeScreen(onNavigateToTab: _onNavTap),
      const WorkshopsScreen(),
      OrdersScreen(initialTab: widget.ordersInitialTab),
      const ProfileScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshUnreadNotifications();
      _checkReactivation();
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
        debugPrint('[CoreScreen] Mantendo notificações locais (já marcadas como lidas)');
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

  Future<void> _checkReactivation() async {
    try {
      final result = await _apiService.get('/customer/reactivation');
      if (!mounted) return;
      if (result['success'] == true && result['eligible'] == true) {
        final coupon = result['coupon'] as Map<String, dynamic>?;
        if (coupon != null) {
          _showReactivationModal(coupon);
        }
      }
    } catch (_) {}
  }

  void _showReactivationModal(Map<String, dynamic> coupon) {
    final code = coupon['code'] ?? '';
    final discount = coupon['discount_percent'] ?? 10;
    final validUntil = coupon['valid_until'] ?? '';

    String dateStr = '';
    if (validUntil.isNotEmpty) {
      try {
        final dt = DateTime.parse(validUntil);
        dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C977).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.waving_hand,
                  color: Color(0xFF00C977),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sentimos sua falta!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ganhe $discount% de desconto no seu próximo serviço',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Código copiado!'),
                      backgroundColor: Color(0xFF00C977),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C977).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00C977).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        code,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF00C977),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy, size: 18, color: Color(0xFF00C977)),
                    ],
                  ),
                ),
              ),
              if (dateStr.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Válido até $dateStr',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _onNavTap(1);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C977),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Agendar agora',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Agora não',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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



















