import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../services/notification_service.dart';
import '../../services/onesignal_service.dart';
import '../../services/appsflyer_service.dart';
import '../notifications/recent_notifications_screen.dart';
import '../../providers/notification_provider.dart';
import '../../utils/formatters.dart';
import 'edit_password_screen.dart';
import '../loyalty/loyalty_screen.dart';
import '../referral/referral_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  Map<String, dynamic>? _customerData;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncNotifications();
    });
  }

  Future<void> _loadCustomerData({bool forceRefresh = false}) async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Obter dados reais do perfil do usuário (forçar refresh se necessário)
      final result = await _apiService.getUserProfile(forceRefresh: forceRefresh);
      
      if (!mounted) return;
      
      if (result['success']) {
        setState(() {
          _customerData = result['data'];
          _hasError = false;
          _errorMessage = null;
        });
        await _syncNotifications();
      } else {
        if (!mounted) return;
        
        // Tratar erro de forma mais amigável
        String errorMessage = result['error'] ?? 'Erro ao carregar perfil';
        
        // Simplificar mensagens de erro técnicas
        if (errorMessage.contains('401') || 
            errorMessage.contains('Token') || 
            errorMessage.contains('não fornecido') ||
            errorMessage.contains('expirado')) {
          errorMessage = 'Sessão expirada. Por favor, faça login novamente.';
          // Redirecionar para login após 2 segundos
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            }
          });
        } else if (errorMessage.contains('Connection refused') ||
                   errorMessage.contains('não está acessível') ||
                   errorMessage.contains('SocketException')) {
          errorMessage = 'Servidor não está acessível. Verifique sua conexão com a internet.';
        } else if (errorMessage.contains('timeout') ||
                   errorMessage.contains('Tempo de conexão')) {
          errorMessage = 'Tempo de conexão esgotado. Verifique sua internet e tente novamente.';
        } else if (errorMessage.contains('Sem conexão') ||
                   errorMessage.contains('Failed host lookup')) {
          errorMessage = 'Sem conexão com a internet. Verifique sua rede.';
        } else if (errorMessage.contains('DioException') || 
            errorMessage.contains('status code')) {
          errorMessage = 'Erro ao conectar com o servidor. Verifique sua conexão e tente novamente.';
        } else if (errorMessage.contains('500')) {
          errorMessage = 'Erro no servidor. Tente novamente em alguns instantes.';
        }
        
        setState(() {
          _hasError = true;
          _errorMessage = errorMessage;
        });
      }
      
    } catch (e) {
      if (!mounted) return;
      
      debugPrint('Erro ao carregar dados do cliente: $e');
      
      String errorMessage = 'Erro ao conectar com o servidor';
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('connection error')) {
        errorMessage = 'Servidor não está acessível. Verifique sua conexão com a internet.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Tempo de conexão esgotado. Verifique sua internet.';
      }
      
      setState(() {
        _hasError = true;
        _errorMessage = errorMessage;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeService, NotificationProvider>(
      builder: (context, themeService, notificationProvider, child) {
        final isDark = themeService.isDarkMode;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: isDark ? const Color(0xFF111111) : Colors.white,
            title: Text(
              'Meu Perfil',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: true,
            actions: [
              _buildNotificationButton(context, themeService, notificationProvider),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.06),
              ),
            ),
          ),
          body: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C977)))
                : _hasError
                    ? _buildErrorScreen(isDark)
                    : _buildContent(isDark, notificationProvider),
          ),
        );
      },
    );
  }

  Widget _buildErrorScreen(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar perfil',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Ocorreu um erro inesperado',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCustomerData,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C977),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _forceLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Sair da conta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : Colors.black,
                side: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark, NotificationProvider notificationProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildHeader(isDark),
          ),
          const SizedBox(height: 24),
          _buildProfileCard(),
          const SizedBox(height: 24),
          if (notificationProvider.unreadNotifications > 0) ...[
            _buildUnreadAlert(notificationProvider.unreadNotifications),
            const SizedBox(height: 24),
          ],
          _buildSettingsSection(notificationProvider),
          const SizedBox(height: 24),
          _buildThemeSection(isDark),
          const SizedBox(height: 24),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildUnreadAlert(int unreadCount) {
    return Card(
      color: const Color(0xFFFFF1F2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.notifications_active, color: Color(0xFFEF4444)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                unreadCount == 1
                    ? 'Você possui 1 notificação pendente.'
                    : 'Você possui $unreadCount notificações pendentes.',
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RecentNotificationsScreen(),
                  ),
                );
                if (mounted) {
                  await _syncNotifications();
                }
              },
              child: const Text(
                'Ver notificações',
                style: TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final firstName = _customerData?['firstName'] ?? _customerData?['first_name'] ?? '';
    final lastName = _customerData?['lastName'] ?? _customerData?['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final initials = fullName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF00C977).withOpacity(isDark ? 0.15 : 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              initials.isNotEmpty ? initials : '?',
              style: const TextStyle(
                color: Color(0xFF00C977),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _customerData?['email'] ?? '',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.45)
                      : Colors.black.withOpacity(0.45),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _editProfile,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.10)
                    : Colors.black.withOpacity(0.10),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined, size: 14, color: Color(0xFF00C977)),
                SizedBox(width: 5),
                Text(
                  'Editar',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF00C977),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFF00C977).withOpacity(isDark ? 0.25 : 0.35),
          width: 0.8,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informações Pessoais',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.person, 'Nome', '${_customerData?['firstName'] ?? _customerData?['first_name'] ?? ''} ${_customerData?['lastName'] ?? _customerData?['last_name'] ?? ''}'),
            _buildInfoRow(Icons.email, 'Email', _customerData?['email'] ?? ''),
            _buildInfoRow(Icons.phone, 'Telefone', Formatters.formatPhone(_customerData?['phone'] ?? _customerData?['phone_number'])),
            _buildInfoRow(Icons.badge, 'CPF', Formatters.formatCpf(_customerData?['cpf'] ?? _customerData?['document'] ?? _customerData?['cpf_number'] ?? _customerData?['document_number'])),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF00C977)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(NotificationProvider notificationProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configurações',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildSettingTile(
          icon: Icons.directions_car,
          title: 'Meus Veículos',
          subtitle: 'Gerenciar veículos cadastrados',
          onTap: () => Navigator.pushNamed(context, '/my-vehicles'),
        ),
        _buildSettingTile(
          icon: Icons.favorite,
          title: 'Oficinas Favoritas',
          subtitle: 'Oficinas que você salvou',
          onTap: () => Navigator.pushNamed(context, '/favorite-workshops'),
        ),
        _buildSettingTile(
          icon: Icons.receipt_long,
          title: 'Meus Pagamentos',
          subtitle: 'Histórico de pagamentos realizados',
          onTap: () => Navigator.pushNamed(context, '/payment-history'),
        ),
        _buildSettingTile(
          icon: Icons.star,
          title: 'Meus Pontos',
          subtitle: 'Programa de fidelidade MECA',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoyaltyScreen()),
            );
          },
        ),
        _buildSettingTile(
          icon: Icons.card_giftcard,
          title: 'Indique e Ganhe',
          subtitle: 'Convide amigos e ganhe R\$ 10',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReferralScreen()),
            );
          },
        ),
        _buildSettingTile(
          icon: Icons.notifications,
          title: 'Notificações',
          subtitle: 'Configurar notificações',
          showBadge: notificationProvider.unreadNotifications > 0,
          onTap: () => _showNotificationsSettings(),
        ),
        _buildSettingTile(
          icon: Icons.lock,
          title: 'Alterar Senha',
          subtitle: 'Alterar sua senha de acesso',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditPasswordScreen(),
              ),
            );
          },
        ),
        _buildSettingTile(
          icon: Icons.help,
          title: 'Ajuda',
          subtitle: 'Central de ajuda e suporte',
          onTap: () => _showHelp(),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showBadge = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF00C977)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBadge)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildThemeSection(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aparência',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: const Color(0xFF00C977),
                    ),
                    const SizedBox(width: 12),
                    const Text('Modo escuro'),
                  ],
                ),
                Switch(
                  value: isDark,
                  onChanged: (value) {
                    final themeService = Provider.of<ThemeService>(context, listen: false);
                    themeService.toggleTheme();
                  },
                  activeColor: const Color(0xFF00C977),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _logout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Sair da Conta',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _editProfile() async {
    final result = await Navigator.pushNamed(context, '/edit-profile');
    if (result == true) {
      // Invalidar cache ANTES de recarregar para garantir dados atualizados
      _apiService.invalidateProfileCache();
      // Recarregar dados do perfil FORÇANDO refresh (ignora cache)
      await _loadCustomerData(forceRefresh: true);
    }
  }

  Widget _buildNotificationButton(
    BuildContext context,
    ThemeService themeService,
    NotificationProvider notificationProvider,
  ) {
    final unreadCount = notificationProvider.unreadNotifications;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            Icons.notifications,
            color: const Color(0xFF00C977),
          ),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RecentNotificationsScreen(),
              ),
            );
            if (mounted) {
              await _syncNotifications();
            }
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
  }

  Future<void> _showNotificationsSettings() async {
    await Navigator.pushNamed(context, '/notifications');
    if (!mounted) return;
    await _syncNotifications();
  }

  void _showHelp() {
    // Ajuste 5: navegar para página de ajuda (não modal)
    Navigator.pushNamed(context, '/help');
  }

  Future<void> _syncNotifications() async {
    try {
      final result = await _apiService.getNotifications(limit: 100);
      if (!mounted) return;
      if (result['success'] == true) {
        final provider = Provider.of<NotificationProvider>(context, listen: false);
        final previousUnread = provider.unreadNotifications;
        
        // WORKAROUND: Se o usuário já marcou todas como lidas localmente (contador = 0),
        // NÃO sobrescrever com dados do servidor que podem estar bugados
        if (previousUnread == 0 && provider.notifications.isNotEmpty) {
          // Usuário já marcou como lidas, manter estado local
          debugPrint('Mantendo notificações locais (já marcadas como lidas)');
          return;
        }
        
        provider.setNotificationsFromPayload(result['data']);
        final currentUnread = provider.unreadNotifications;
        
        // Se há novas notificações não lidas, exibir push notification
        if (currentUnread > previousUnread) {
          final newNotifications = NotificationProvider.normalizeNotifications(result['data']);
          final unreadNotifications = newNotifications.where((n) => 
            (n['read'] != true && n['is_read'] != true)
          ).toList();
          
          // Exibir push notification para as novas notificações não lidas
          if (unreadNotifications.isNotEmpty) {
            final notificationService = NotificationService();
            for (var notification in unreadNotifications.take(3)) { // Limitar a 3 para não sobrecarregar
              final title = notification['title']?.toString() ?? 'Nova notificação';
              final message = notification['message']?.toString() ?? '';
              final notificationId = notification['id']?.toString() ?? '';
              final bookingId = notification['booking_id'] ?? notification['data']?['booking_id'];
              
              String? payload;
              if (bookingId != null) {
                payload = NotificationService.createNavigationPayload('booking', bookingId.toString());
              } else if (notificationId.isNotEmpty) {
                payload = NotificationService.createNavigationPayload('notifications', notificationId);
              }
              
              await notificationService.showLocalNotification(
                id: DateTime.now().millisecondsSinceEpoch ~/ 1000 + unreadNotifications.indexOf(notification),
                title: title,
                body: message.isNotEmpty ? message : 'Você tem uma nova notificação',
                payload: payload,
              );
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao sincronizar notificações: $e');
      }
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da Conta'),
        content: const Text('Tem certeza que deseja sair da sua conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _forceLogout();
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  Future<void> _forceLogout() async {
    try {
      // Remover token OneSignal antes de fazer logout
      try {
        final playerId = OneSignalService.getSubscriptionId();
        if (playerId != null) {
          await _apiService.removeDeviceToken(playerId);
          await OneSignalService.removeExternalUserId();
        }
      } catch (e) {
        debugPrint('Erro ao remover device token: $e');
      }
      
      await _apiService.logout();
    } catch (_) {}

    AppsFlyerService.instance.clearCustomerUserId();

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }
}
