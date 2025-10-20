import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': '1',
      'title': 'Agendamento Confirmado',
      'message': 'Sua oficina confirmou o agendamento para amanhã às 10h',
      'type': 'booking',
      'read': false,
      'created_at': DateTime.now().subtract(const Duration(hours: 2)),
    },
    {
      'id': '2',
      'title': 'Serviço Concluído',
      'message': 'O serviço de troca de óleo foi concluído',
      'type': 'service',
      'read': false,
      'created_at': DateTime.now().subtract(const Duration(days: 1)),
    },
    {
      'id': '3',
      'title': 'Nova Promoção',
      'message': '20% de desconto em alinhamento e balanceamento',
      'type': 'promo',
      'read': true,
      'created_at': DateTime.now().subtract(const Duration(days: 2)),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Notificações',
          style: TextStyle(
            color: Color(0xFF252940),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (var notif in _notifications) {
                  notif['read'] = true;
                }
              });
            },
            child: const Text(
              'Marcar todas como lidas',
              style: TextStyle(
                color: Color(0xFF00C977),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationCard(notification);
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['read'] ?? false;
    final type = notification['type'] ?? 'general';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : const Color(0xFF00C977).withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isRead ? Colors.grey[200]! : const Color(0xFF00C977).withOpacity(0.3),
          width: isRead ? 1 : 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getNotificationTypeColor(type).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getNotificationTypeIcon(type),
            color: _getNotificationTypeColor(type),
          ),
        ),
        title: Text(
          notification['title'] ?? '',
          style: TextStyle(
            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
            color: const Color(0xFF252940),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(
              notification['message'] ?? '',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(notification['created_at']),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        trailing: !isRead
            ? Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF00C977),
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () {
          setState(() {
            notification['read'] = true;
          });
          Navigator.pushNamed(
            context,
            '/notification-detail',
            arguments: notification,
          );
        },
      ),
    );
  }

  IconData _getNotificationTypeIcon(String type) {
    switch (type) {
      case 'booking':
        return Icons.event;
      case 'service':
        return Icons.build;
      case 'promo':
        return Icons.local_offer;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationTypeColor(String type) {
    switch (type) {
      case 'booking':
        return const Color(0xFF7896D8);
      case 'service':
        return const Color(0xFF00C977);
      case 'promo':
        return const Color(0xFFDBA800);
      default:
        return const Color(0xFF252940);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 60) {
      return 'Há ${difference.inMinutes} minutos';
    } else if (difference.inHours < 24) {
      return 'Há ${difference.inHours} horas';
    } else if (difference.inDays == 1) {
      return 'Ontem';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }
}
