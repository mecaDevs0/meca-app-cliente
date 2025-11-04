import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';

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
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await _apiService.getNotifications();
      
      if (result['success'] == true) {
        final notifications = (result['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _notifications = notifications;
          _unreadCount = notifications.where((n) => n['read'] == false).length;
        });
      }
    } catch (e) {
      print('Erro ao carregar notificações: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _apiService.markNotificationRead(notificationId);
      _loadNotifications(); // Recarregar para atualizar UI
    } catch (e) {
      print('Erro ao marcar notificação como lida: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _apiService.markAllNotificationsRead();
      _loadNotifications(); // Recarregar para atualizar UI
    } catch (e) {
      print('Erro ao marcar todas como lidas: $e');
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
                Text(
                  'Notificações',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF252940),
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                if (_unreadCount > 0) ...[
                  const SizedBox(width: 12),
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
                TextButton(
                  onPressed: _markAllAsRead,
                  child: const Text(
                    'Marcar todas como lidas',
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
    final date = notification['created_at'] != null
        ? DateTime.tryParse(notification['created_at'])
        : null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: themeService.isDarkMode 
            ? const Color(0xFF1E1E1E) 
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead 
              ? Colors.transparent 
              : const Color(0xFF00C977).withOpacity(0.3),
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
            
            // Navegar baseado no tipo de notificação
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
    // Se tem booking_id, navegar para detalhes do agendamento
    if (notification['booking_id'] != null) {
      Navigator.pushNamed(
        context,
        '/order-detail',
        arguments: {'id': notification['booking_id']},
      );
      return;
    }
    
    // Se tem vehicle_id, navegar para detalhes do veículo
    if (notification['vehicle_id'] != null) {
      Navigator.pushNamed(
        context,
        '/vehicle-detail',
        arguments: {'id': notification['vehicle_id']},
      );
      return;
    }
    
    // Se tem service_id, navegar para detalhes do serviço
    if (notification['service_id'] != null) {
      Navigator.pushNamed(
        context,
        '/service-detail',
        arguments: {'id': notification['service_id']},
      );
      return;
    }
    
    // Se tem workshop_id, navegar para detalhes da oficina
    if (notification['workshop_id'] != null) {
      Navigator.pushNamed(
        context,
        '/workshop-detail',
        arguments: {'id': notification['workshop_id']},
      );
      return;
    }
    
    // Se não tem ID específico, verificar tipo e navegar
    final type = notification['type']?.toString() ?? '';
    if (type.contains('booking') || type.contains('agendamento')) {
      // Tentar extrair booking_id do título ou mensagem
      final title = notification['title']?.toString() ?? '';
      final message = notification['message']?.toString() ?? '';
      // Se encontrar referência a agendamento, navegar para lista de agendamentos
      if (title.toLowerCase().contains('agendamento') || message.toLowerCase().contains('agendamento')) {
        Navigator.pushNamed(context, '/orders');
        return;
      }
    }
    
    // Por padrão, não fazer nada ou mostrar snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notificação não possui ação associada'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

