import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/theme_service.dart';
import '../providers/notification_provider.dart';

class BottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavItem> items;

  const CustomBottomNav({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final navBgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0);
    
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: navBgColor,
        border: Border(
          top: BorderSide(
            color: borderColor,
            width: 1,
          ),
        ),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildNavItem(context, index, item);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, BottomNavItem item) {
    final themeService = Provider.of<ThemeService>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final isDark = themeService.isDarkMode;
    final isActive = currentIndex == index;
    
    final activeColor = const Color(0xFF00C977);
    final inactiveColor = isDark ? const Color(0xFF666666) : const Color(0xFF999999);
    final textColor = isActive ? activeColor : inactiveColor;
    final hasUnreadNotifications = notificationProvider.unreadNotifications > 0;
    final hasBookingNotifications = _hasUnreadBookingNotifications(notificationProvider);
    bool shouldShowBadge = false;
    if (index == 2) {
      shouldShowBadge = hasBookingNotifications;
    } else if (index == items.length - 1) {
      shouldShowBadge = hasUnreadNotifications;
    }
    
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive 
                    ? activeColor.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isActive ? item.activeIcon : item.icon,
                    color: textColor,
                    size: 24,
                  ),
                  if (shouldShowBadge)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasUnreadBookingNotifications(NotificationProvider provider) {
    for (final notification in provider.notifications) {
      final isRead = notification['read'] == true || notification['is_read'] == true;
      if (isRead) continue;

      final type = (notification['type'] ?? '').toString().toLowerCase();
      final title = (notification['title'] ?? '').toString().toLowerCase();
      final message = (notification['message'] ?? '').toString().toLowerCase();

      final bool bookingKeyword = type.contains('booking') ||
          type.contains('agendamento') ||
          title.contains('agendamento') ||
          message.contains('agendamento');

      if (bookingKeyword) {
        return true;
      }
    }
    return false;
  }
}












