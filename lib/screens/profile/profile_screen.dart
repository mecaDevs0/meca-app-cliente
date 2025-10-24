import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _customerData;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  Future<void> _loadCustomerData() async {
    setState(() => _isLoading = true);
    
    try {
      // Obter dados reais do perfil do usuário
      final result = await _apiService.getUserProfile();
      
      if (result['success']) {
        setState(() {
          _customerData = result['data'];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar perfil: ${result['error']}')),
        );
      }
      
    } catch (e) {
      print('Erro ao carregar dados do cliente: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C977)))
            : _buildContent(isDark),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildProfileCard(),
          const SizedBox(height: 24),
          _buildSettingsSection(),
          const SizedBox(height: 24),
          _buildThemeSection(isDark),
          const SizedBox(height: 24),
          _buildLogoutButton(),
        ],
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
                '${_customerData?['first_name'] ?? ''} ${_customerData?['last_name'] ?? ''}',
                style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              const SizedBox(height: 4),
              Text(
                _customerData?['email'] ?? '',
                style: const TextStyle(
                  color: Colors.grey,
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
            const Text(
              'Informações Pessoais',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.person, 'Nome', '${_customerData?['first_name'] ?? ''} ${_customerData?['last_name'] ?? ''}'),
            _buildInfoRow(Icons.email, 'Email', _customerData?['email'] ?? ''),
            _buildInfoRow(Icons.phone, 'Telefone', _customerData?['phone'] ?? ''),
            _buildInfoRow(Icons.location_on, 'Endereço', _customerData?['address'] ?? ''),
            _buildInfoRow(Icons.badge, 'CPF', _customerData?['cpf'] ?? ''),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Configurações',
          style: TextStyle(
            fontSize: 18,
              fontWeight: FontWeight.bold,
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
          onTap: () => _showNotificationsSettings(),
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
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF00C977)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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

  void _editProfile() {
    Navigator.pushNamed(context, '/edit-profile');
  }

  void _showNotificationsSettings() {
    Navigator.pushNamed(context, '/notifications');
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF00C977),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.build,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('MECA - Suporte'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Precisa de ajuda? Entre em contato conosco:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildContactInfo(
                Icons.email,
                'Email',
                'suporte@meca.com.br',
              ),
              const SizedBox(height: 12),
              _buildContactInfo(
                Icons.phone,
                'Telefone',
                '(11) 99999-9999',
              ),
              const SizedBox(height: 12),
              _buildContactInfo(
                Icons.access_time,
                'Horário de Atendimento',
                'Segunda a Sexta: 8h às 18h',
              ),
              const SizedBox(height: 12),
              _buildContactInfo(
                Icons.location_on,
                'Endereço',
                'Rua das Oficinas, 123\nSão Paulo - SP',
              ),
              const SizedBox(height: 16),
              const Text(
                'FAQ Rápido:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Como agendar um serviço?'),
              const Text('• Como cancelar um agendamento?'),
              const Text('• Como alterar meus dados?'),
              const Text('• Como funciona o pagamento?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Aqui você poderia abrir um chat ou email
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C977),
            ),
            child: const Text('Entrar em Contato'),
          ),
        ],
      ),
    );
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
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}