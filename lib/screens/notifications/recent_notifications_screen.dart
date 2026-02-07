import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/notification_provider.dart';
import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_alerts.dart';

class RecentNotificationsScreen extends StatefulWidget {
  const RecentNotificationsScreen({Key? key}) : super(key: key);

  @override
  State<RecentNotificationsScreen> createState() => _RecentNotificationsScreenState();
}

class _RecentNotificationsScreenState extends State<RecentNotificationsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<NotificationProvider>(context, listen: false).markProfileBadgeSeen();
      // Marcar todas as notificações como lidas automaticamente ao entrar na tela
      _markAllAsReadSilently();
    });
    _loadNotifications();
  }

  // Marcar todas como lidas silenciosamente (sem mostrar mensagem)
  Future<void> _markAllAsReadSilently() async {
    try {
      final result = await _apiService.markAllNotificationsRead();
      if (mounted && result['success'] == true) {
        final provider = Provider.of<NotificationProvider>(context, listen: false);
        // Marcar todas as notificações no provider como lidas
        final updatedNotifications = _notifications.map((n) {
          return Map<String, dynamic>.from(n)
            ..['is_read'] = true
            ..['read'] = true;
        }).toList();
        provider.setNotifications(updatedNotifications);
        provider.setUnreadNotifications(0, resetBadge: true);
        // Recarregar notificações para garantir sincronização
        _loadNotifications();
      }
    } catch (e) {
      // Silenciar erros - não mostrar mensagem ao usuário
      print('Erro ao marcar notificações como lidas: $e');
    }
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      final result = await _apiService.getNotifications();

      if (result['success'] == true) {
        final provider = Provider.of<NotificationProvider>(context, listen: false);
        final payload = result['data'];
        final normalized = NotificationProvider.normalizeNotifications(payload);
        final unread = NotificationProvider.extractUnreadCount(payload);

        setState(() {
          _notifications = normalized;
          _unreadCount = unread;
        });
        provider.setNotifications(normalized);
        provider.markProfileBadgeSeen();
      }
    } catch (e) {
      print('Erro ao carregar notificações: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _apiService.markNotificationRead(notificationId);
      if (!mounted) return;
      final provider = Provider.of<NotificationProvider>(context, listen: false);
      provider.markNotificationAsRead(notificationId);
      _loadNotifications();
    } catch (e) {
      print('Erro ao marcar notificação como lida: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final result = await _apiService.markAllNotificationsRead();
      if (!mounted) return;
      
      if (result['success'] == true) {
        final provider = Provider.of<NotificationProvider>(context, listen: false);
        
        // PRIMEIRO: Marcar todas as notificações locais como lidas
        final updatedNotifications = _notifications.map((n) {
          return Map<String, dynamic>.from(n)
            ..['is_read'] = true
            ..['read'] = true;
        }).toList();
        
        // Atualizar estado local imediatamente
        setState(() {
          _notifications = updatedNotifications;
          _unreadCount = 0;
        });
        
        // Atualizar provider
        provider.setNotifications(updatedNotifications);
        provider.setUnreadNotifications(0, resetBadge: true);
        
        // NÃO recarregar do servidor imediatamente!
        // O servidor pode ter delay para atualizar, então mantemos o estado local
        // A próxima vez que o usuário entrar na tela, as notificações serão sincronizadas
        
        // Mostrar feedback de sucesso
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todas as notificações foram marcadas como lidas'),
            backgroundColor: Color(0xFF00C977),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // Mostrar erro
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Erro ao marcar notificações como lidas'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Erro ao marcar todas como lidas: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao conectar com o servidor. Tente novamente.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDark = themeService.isDarkMode;
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Notificações',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF252940),
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
                if (_unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: isDark ? Colors.white : const Color(0xFF252940),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_unreadCount > 0)
                TextButton.icon(
                  onPressed: _markAllAsRead,
                  icon: const Icon(
                    Icons.done_all,
                    size: 18,
                    color: Color(0xFF00C977),
                  ),
                  label: const Text(
                    'Ler todas',
                    style: TextStyle(
                      color: Color(0xFF00C977),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C977)))
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: const Color(0xFF00C977),
                  child: _notifications.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            return _buildNotificationCard(_notifications[index], themeService);
                          },
                        ),
                ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            'Nenhuma notificação',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Você não tem notificações no momento',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, ThemeService themeService) {
    final isRead = notification['read'] == true;
    final date = notification['created_at'] != null ? DateTime.tryParse(notification['created_at']) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: themeService.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? Colors.transparent : const Color(0xFF00C977).withOpacity(0.3),
          width: isRead ? 0 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!isRead) {
              _markAsRead(notification['id'].toString());
            }
            _handleNotificationTap(notification);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getNotificationColor(notification['type']).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getNotificationIcon(notification['type']),
                    color: _getNotificationColor(notification['type']),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification['title'] ?? 'Notificação',
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                          fontSize: 16,
                          color: themeService.isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification['message'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      if (date != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isRead)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00C977),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'booking':
        return Colors.blue;
      case 'reminder':
        return Colors.orange;
      case 'promotion':
        return Colors.purple;
      case 'system':
        return Colors.grey;
      default:
        return const Color(0xFF00C977);
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'booking':
        return Icons.calendar_today;
      case 'reminder':
        return Icons.notifications;
      case 'promotion':
        return Icons.local_offer;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final data = notification['data'] as Map<String, dynamic>?;
    final bookingId = data?['booking_id'] ?? notification['booking_id'];
    final vehicleId = data?['vehicle_id'] ?? notification['vehicle_id'];
    final serviceId = data?['service_id'] ?? notification['service_id'];
    final workshopId = data?['workshop_id'] ?? notification['workshop_id'];

    if (bookingId != null) {
      Navigator.pushNamed(
        context,
        '/order-detail',
        arguments: {'id': bookingId},
      );
      return;
    }

    if (vehicleId != null) {
      Navigator.pushNamed(
        context,
        '/vehicle-detail',
        arguments: {'id': vehicleId},
      );
      return;
    }

    if (serviceId != null) {
      Navigator.pushNamed(
        context,
        '/service-detail',
        arguments: {'id': serviceId},
      );
      return;
    }

    if (workshopId != null) {
      Navigator.pushNamed(
        context,
        '/workshop-detail',
        arguments: {'id': workshopId},
      );
      return;
    }

    final type = notification['type']?.toString() ?? '';
    if (type.contains('booking') || type.contains('agendamento')) {
      final title = notification['title']?.toString() ?? '';
      final message = notification['message']?.toString() ?? '';
      if (title.toLowerCase().contains('agendamento') || message.toLowerCase().contains('agendamento')) {
        Navigator.pushNamed(context, '/orders');
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Esta notificação não tem uma ação direta. Verifique os detalhes manualmente.'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}



