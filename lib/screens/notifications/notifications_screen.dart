import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_alerts.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _marketingNotifications = false;
  bool _bookingReminders = true;
  bool _serviceUpdates = true;
  bool _promotions = false;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.getNotificationSettings();
      if (result['success'] == true && result['data'] != null) {
        final settings = result['data'] as Map<String, dynamic>;
        setState(() {
          _pushNotifications = settings['push_notifications'] ?? true;
          _emailNotifications = settings['email_notifications'] ?? true;
          _smsNotifications = settings['sms_notifications'] ?? false;
          _marketingNotifications = settings['marketing_notifications'] ?? false;
          _bookingReminders = settings['booking_reminders'] ?? true;
          _serviceUpdates = settings['service_updates'] ?? true;
          _promotions = settings['promotions'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar configurações: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: themeService.isDarkMode 
              ? const Color(0xFF121212) 
              : const Color(0xFFFAFAFA),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: themeService.isDarkMode 
                ? const Color(0xFF1E1E1E) 
                : Colors.white,
            title: Text(
              'Notificações',
              style: TextStyle(
                color: themeService.isDarkMode 
                    ? Colors.white 
                    : const Color(0xFF252940),
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: themeService.isDarkMode 
                    ? Colors.white 
                    : const Color(0xFF252940),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C977)))
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNotificationType(
                  'Push Notifications',
                  'Receber notificações no dispositivo',
                  _pushNotifications,
                  (value) => setState(() => _pushNotifications = value),
                ),
                const SizedBox(height: 16),
                _buildNotificationType(
                  'Email',
                  'Receber notificações por email',
                  _emailNotifications,
                  (value) => setState(() => _emailNotifications = value),
                ),
                const SizedBox(height: 16),
                _buildNotificationType(
                  'SMS',
                  'Receber notificações por SMS',
                  _smsNotifications,
                  (value) => setState(() => _smsNotifications = value),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('Tipos de Notificação'),
                const SizedBox(height: 16),
                _buildNotificationType(
                  'Lembretes de Agendamento',
                  'Receber lembretes antes dos agendamentos',
                  _bookingReminders,
                  (value) => setState(() => _bookingReminders = value),
                ),
                const SizedBox(height: 16),
                _buildNotificationType(
                  'Atualizações de Serviço',
                  'Receber atualizações sobre o status dos serviços',
                  _serviceUpdates,
                  (value) => setState(() => _serviceUpdates = value),
                ),
                const SizedBox(height: 16),
                _buildNotificationType(
                  'Promoções',
                  'Receber ofertas e promoções especiais',
                  _promotions,
                  (value) => setState(() => _promotions = value),
                ),
                const SizedBox(height: 16),
                _buildNotificationType(
                  'Marketing',
                  'Receber conteúdo promocional',
                  _marketingNotifications,
                  (value) => setState(() => _marketingNotifications = value),
                ),
                const SizedBox(height: 32),
                _buildSaveButton(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF00C977),
      ),
    );
  }

  Widget _buildNotificationType(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: themeService.isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                color: themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            trailing: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF00C977),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C977),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Salvar Configurações',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;
    
    setState(() => _isSaving = true);
    
    try {
      final result = await _apiService.updateNotificationSettings({
        'push_notifications': _pushNotifications,
        'email_notifications': _emailNotifications,
        'sms_notifications': _smsNotifications,
        'marketing_notifications': _marketingNotifications,
        'booking_reminders': _bookingReminders,
        'service_updates': _serviceUpdates,
        'promotions': _promotions,
      });

      if (!mounted) return;

      if (result['success'] == true) {
        AppAlerts.showSuccess(
          context,
          message: 'Preferências de notificações salvas com sucesso.',
        );
      } else {
        AppAlerts.showError(
          context,
          message: 'Erro ao salvar: ${result['error'] ?? 'Erro desconhecido'}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppAlerts.showError(
        context,
        message: 'Não foi possível salvar suas preferências agora. Tente novamente.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}