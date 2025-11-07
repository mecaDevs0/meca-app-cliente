import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../screens/notifications/recent_notifications_screen.dart';

class NotificationAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final Widget? leading;
  final List<Widget>? actions;
  final bool floating;
  final bool pinned;

  const NotificationAppBar({
    Key? key,
    required this.title,
    this.showBackButton = false,
    this.leading,
    this.actions,
    this.floating = false,
    this.pinned = true,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Future<int> _getUnreadCount() async {
    try {
      final apiService = ApiService();
      final result = await apiService.getNotifications(limit: 100, read: false);
      if (result['success'] == true) {
        final notifications = (result['data'] as List?) ?? [];
        return notifications.length;
      }
    } catch (e) {
      print('Erro ao buscar contagem de notificações: $e');
    }
    return 0;
  }

  Widget _buildNotificationButton(BuildContext context, ThemeService themeService) {
    return FutureBuilder<int>(
      future: _getUnreadCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        
        return Stack(
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications,
                color: themeService.isDarkMode ? Colors.white : const Color(0xFF252940),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RecentNotificationsScreen(),
                  ),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final appBarActions = <Widget>[];
        
        // Adicionar botão de notificações
        appBarActions.add(_buildNotificationButton(context, themeService));
        
        // Adicionar actions customizadas se houver
        if (actions != null) {
          appBarActions.addAll(actions!);
        }

        return AppBar(
          elevation: 0,
          backgroundColor: themeService.isDarkMode 
              ? const Color(0xFF1E1E1E) 
              : Colors.white,
          title: Text(
            title,
            style: TextStyle(
              color: themeService.isDarkMode ? Colors.white : const Color(0xFF252940),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          leading: leading ?? (showBackButton
              ? IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: themeService.isDarkMode ? Colors.white : const Color(0xFF252940),
                  ),
                  onPressed: () => Navigator.pop(context),
                )
              : null),
          actions: appBarActions,
        );
      },
    );
  }
}





