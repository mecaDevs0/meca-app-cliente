import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../services/notification_service.dart';
import '../../services/onesignal_service.dart';
import '../notifications/recent_notifications_screen.dart';
import '../../providers/notification_provider.dart';
import '../../utils/formatters.dart';
import 'edit_password_screen.dart';

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
      
      print('Erro ao carregar dados do cliente: $e');
      
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
          appBar: AppBar(
            elevation: 0,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(
              'Meu Perfil',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF252940),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            actions: [
              _buildNotificationButton(context, themeService, notificationProvider),
            ],
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
          _buildHeader(),
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

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF00C977).withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Icon(
            Icons.person,
            color: Color(0xFF00C977),
            size: 30,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_customerData?['firstName'] ?? _customerData?['first_name'] ?? ''} ${_customerData?['lastName'] ?? _customerData?['last_name'] ?? ''}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _customerData?['email'] ?? '',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _editProfile,
          icon: const Icon(Icons.edit),
          color: const Color(0xFF00C977),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    return Card(
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
            color: themeService.isDarkMode ? Colors.white : const Color(0xFF252940),
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
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDark = themeService.isDarkMode;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
              // Header com gradiente
            Container(
                padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF00C977),
                      Color(0xFF00A866),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                        Icons.support_agent,
                color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MECA - Suporte',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Estamos aqui para ajudar',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Conteúdo
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                      // Contato
                      _buildModernContactSection(
                        isDark,
                        Icons.email_outlined,
                'Email',
                'contato@mecabr.com',
                        Colors.blue,
                        () async {
                          final emailUri = Uri(
                            scheme: 'mailto',
                            path: 'contato@mecabr.com',
                            query: 'subject=Suporte MECA - Solicitação de Ajuda',
                          );
                          if (await canLaunchUrl(emailUri)) {
                            await launchUrl(emailUri);
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Não foi possível abrir o aplicativo de email.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                      ),
              const SizedBox(height: 16),
                      _buildModernContactSection(
                        isDark,
                        Icons.access_time_rounded,
                        'Horário de Atendimento',
                        'Disponível 24 horas',
                        const Color(0xFF00C977),
                        null,
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // FAQ
                      Text(
                        'Perguntas Frequentes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF252940),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFAQItem(isDark, 'Como agendar um serviço?', 'Busque uma oficina no mapa ou lista, escolha o serviço, data e horário e confirme. A oficina aprovará e você receberá a confirmação.'),
                      const SizedBox(height: 12),
                      _buildFAQItem(isDark, 'Como cancelar um agendamento?', 'Você pode cancelar até 2 horas antes do horário pelo app. Depois disso, entre em contato com a oficina.'),
                      const SizedBox(height: 12),
                      _buildFAQItem(isDark, 'Como alterar meus dados?', 'No Perfil, toque em "Editar perfil" para alterar nome, e-mail, telefone e outros dados.'),
                      const SizedBox(height: 12),
                      _buildFAQItem(isDark, 'Como funciona o pagamento?', 'Após a oficina finalizar o serviço e você aprovar o orçamento, pague no app por PIX ou cartão. O valor é repassado automaticamente à oficina.'),
            ],
          ),
        ),
              ),
              
              // Botões
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Fechar',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF252940),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final emailUri = Uri(
                scheme: 'mailto',
                path: 'contato@mecabr.com',
                query: 'subject=Suporte MECA - Solicitação de Ajuda',
              );
              if (await canLaunchUrl(emailUri)) {
                await launchUrl(emailUri);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Não foi possível abrir o aplicativo de email.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C977),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.email, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Entrar em Contato',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernContactSection(
    bool isDark,
    IconData icon,
    String label,
    String value,
    Color iconColor,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF252940),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(bool isDark, String question, String answer) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFF00C977),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF252940),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  answer,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
          print('🔒 Mantendo notificações locais (já marcadas como lidas)');
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
        print('Erro ao sincronizar notificações: $e');
      }
    }
  }

  Widget _buildContactInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF00C977)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
        print('Erro ao remover device token: $e');
      }
      
      await _apiService.logout();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }
}
