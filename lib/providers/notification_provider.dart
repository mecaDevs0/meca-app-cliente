import 'dart:convert';

import 'package:flutter/foundation.dart';

class NotificationProvider extends ChangeNotifier {
  int _unreadNotifications = 0;
  bool _showProfileBadge = false;
  List<Map<String, dynamic>> _notifications = const [];

  int get unreadNotifications => _unreadNotifications;
  bool get showProfileBadge => _showProfileBadge;
  List<Map<String, dynamic>> get notifications => _notifications;

  void setUnreadNotifications(int count, {bool resetBadge = false}) {
    final normalized = count.clamp(0, 9999).toInt();
    _unreadNotifications = normalized;

    if (!resetBadge) {
      _showProfileBadge = normalized > 0;
    } else if (normalized == 0) {
      _showProfileBadge = false;
    }

    notifyListeners();
  }

  void setNotifications(List<Map<String, dynamic>> notifications) {
    _notifications = notifications.map((notification) => Map<String, dynamic>.from(notification)).toList();
    final unread = _countUnread(notifications).clamp(0, 9999);
    _unreadNotifications = unread;
    _showProfileBadge = unread > 0;
    notifyListeners();
  }

  void setNotificationsFromPayload(dynamic payload) {
    final normalized = normalizeNotifications(payload);
    setNotifications(normalized);
  }

  void incrementUnread({int delta = 1}) {
    if (delta <= 0) return;
    _unreadNotifications = (_unreadNotifications + delta).clamp(0, 9999);
    _showProfileBadge = _unreadNotifications > 0;
    notifyListeners();
  }

  void markNotificationAsRead(String id) {
    final updated = _notifications.map((notification) {
      if ('${notification['id']}' == id) {
        return {
          ...notification,
          'read': true,
          'is_read': true,
        };
      }
      return notification;
    }).toList();

    setNotifications(updated);
  }

  void markProfileBadgeSeen() {
    if (_showProfileBadge) {
      _showProfileBadge = false;
      notifyListeners();
    }
  }

  void clearAll() {
    if (_unreadNotifications != 0 || _showProfileBadge || _notifications.isNotEmpty) {
      _unreadNotifications = 0;
      _showProfileBadge = false;
      _notifications = const [];
      notifyListeners();
    }
  }

  static int extractUnreadCount(dynamic payload) {
    try {
      if (payload is Map<String, dynamic>) {
        final unreadRaw = payload['unread_count'] ?? payload['unreadCount'];
        final unreadParsed = unreadRaw is int
            ? unreadRaw
            : (unreadRaw is String ? int.tryParse(unreadRaw) : null);
        if (unreadParsed != null) {
          return unreadParsed;
        }

        final normalized = normalizeNotifications(payload);
        return _countUnread(normalized);
      }

      if (payload is List) {
        final normalized = normalizeNotifications(payload);
        return _countUnread(normalized);
      }
    } catch (e) {
      debugPrint('Erro ao extrair contagem de notificações: $e');
    }
    return 0;
  }

  static List<Map<String, dynamic>> normalizeNotifications(dynamic payload) {
    try {
      if (payload is Map<String, dynamic>) {
        final primary = payload['notifications'] ?? payload['items'];
        if (primary != null) {
          return _mapList(primary);
        }

        final dataField = payload['data'];
        if (dataField is List) {
          return _mapList(dataField);
        }
        if (dataField is Map) {
          final nested = dataField['notifications'] ?? dataField['items'] ?? dataField['data'];
          return _mapList(nested);
        }

        return _mapList(dataField);
      }
      return _mapList(payload);
    } catch (e) {
      debugPrint('Erro ao normalizar notificações: $e');
      return const [];
    }
  }

  static List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Object>()
          .map<Map<String, dynamic>>((item) {
            Map<String, dynamic> normalized;
            if (item is Map<String, dynamic>) {
              normalized = Map<String, dynamic>.from(item);
            } else if (item is Map) {
              normalized = Map<String, dynamic>.from(item);
            } else {
              normalized = <String, dynamic>{};
            }

            final dataField = normalized['data'];
            if (dataField is String) {
              try {
                final decoded = jsonDecode(dataField);
                if (decoded is Map) {
                  normalized['data'] = Map<String, dynamic>.from(decoded);
                }
              } catch (_) {
                // Ignorar erro de parse e manter string original
              }
            }

            return normalized;
          })
          .toList();
    }
    return const [];
  }

  static int _countUnread(List<Map<String, dynamic>> notifications) {
    int count = 0;
    for (final notification in notifications) {
      final isRead = notification['read'] == true || notification['is_read'] == true;
      if (!isRead) count++;
    }
    return count;
  }
}
