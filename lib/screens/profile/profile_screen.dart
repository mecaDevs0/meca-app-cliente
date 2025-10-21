import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // AppBar com gradiente verde
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF00C977),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF00C977),
                      Color(0xFF00B369),
                      Color(0xFF00A85C),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Color(0xFF00C977),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Meu Perfil',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Menu de opções
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildMenuSection(
                    title: 'Minha Conta',
                    items: [
                      _MenuItem(
                        icon: Icons.person_outline,
                        title: 'Dados Pessoais',
                        subtitle: 'Edite suas informações',
                        onTap: () => Navigator.pushNamed(context, '/edit-profile'),
                      ),
                      _MenuItem(
                        icon: Icons.directions_car_outlined,
                        title: 'Meus Veículos',
                        subtitle: 'Gerencie seus veículos',
                        onTap: () => Navigator.pushNamed(context, '/my-vehicles'),
                      ),
                      _MenuItem(
                        icon: Icons.notifications_outlined,
                        title: 'Notificações',
                        subtitle: 'Configure suas preferências',
                        onTap: () => Navigator.pushNamed(context, '/notifications'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildMenuSection(
                    title: 'Ajuda',
                    items: [
                      _MenuItem(
                        icon: Icons.help_outline,
                        title: 'Central de Ajuda',
                        subtitle: 'FAQ e suporte',
                        onTap: () => Navigator.pushNamed(context, '/help'),
                      ),
                      _MenuItem(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacidade e Termos',
                        subtitle: 'Políticas do aplicativo',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildMenuSection(
                    title: 'Configurações',
                    items: [
                      _MenuItem(
                        icon: Icons.exit_to_app,
                        title: 'Sair',
                        subtitle: 'Desconectar da conta',
                        onTap: _logout,
                        isDestructive: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // Versão do app
                  Text(
                    'MECA Cliente v1.0.0',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection({
    required String title,
    required List<_MenuItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  _buildMenuItem(item),
                  if (index < items.length - 1)
                    Divider(height: 1, color: Colors.grey[200]),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(_MenuItem item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: item.isDestructive
              ? Colors.red.withOpacity(0.1)
              : const Color(0xFF00C977).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          item.icon,
          color: item.isDestructive ? Colors.red : const Color(0xFF00C977),
          size: 24,
        ),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: item.isDestructive ? Colors.red : const Color(0xFF2D3748),
        ),
      ),
      subtitle: Text(
        item.subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: item.isDestructive ? Colors.red : const Color(0xFF00C977),
      ),
      onTap: item.onTap,
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });
}
