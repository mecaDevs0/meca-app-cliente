import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/theme_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _marketingNotifications = false;
  bool _bookingReminders = true;
  bool _serviceUpdates = true;
  bool _promotions = false;

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
          body: SingleChildScrollView(
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
        onPressed: _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C977),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
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

  void _saveSettings() {
    // Aqui você salvaria as configurações no backend
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configurações salvas com sucesso!'),
        backgroundColor: Color(0xFF00C977),
      ),
    );
  }
}