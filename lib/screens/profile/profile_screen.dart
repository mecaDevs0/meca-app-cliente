import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    
    final result = await _apiService.getProfile();
    
    if (result['success']) {
      setState(() {
        _profile = result['data'];
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await _apiService.clearToken();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C977)))
          : CustomScrollView(
              slivers: [
                // Header with gradient
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: const Color(0xFF252940),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF252940),
                            Color(0xFF1B1D2E),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 45,
                              backgroundColor: const Color(0xFF00C977),
                              child: Text(
                                (_profile?['name'] ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              _profile?['name'] ?? 'Usuário',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _profile?['email'] ?? '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Menu Items
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: Icons.person,
                          title: 'Editar Perfil',
                          onTap: () => Navigator.pushNamed(context, '/edit-profile'),
                        ),
                        _buildMenuItem(
                          icon: Icons.directions_car,
                          title: 'Meus Veículos',
                          onTap: () => Navigator.pushNamed(context, '/my-vehicles'),
                        ),
                        _buildMenuItem(
                          icon: Icons.event,
                          title: 'Meus Agendamentos',
                          onTap: () => Navigator.pushNamed(context, '/orders'),
                        ),
                        _buildMenuItem(
                          icon: Icons.notifications,
                          title: 'Notificações',
                          onTap: () => Navigator.pushNamed(context, '/notifications'),
                        ),
                        _buildMenuItem(
                          icon: Icons.lock,
                          title: 'Alterar Senha',
                          onTap: () => Navigator.pushNamed(context, '/change-password'),
                        ),
                        _buildMenuItem(
                          icon: Icons.help,
                          title: 'Central de Ajuda',
                          onTap: () => Navigator.pushNamed(context, '/help'),
                        ),
                        const SizedBox(height: 20),
                        _buildMenuItem(
                          icon: Icons.logout,
                          title: 'Sair',
                          iconColor: Colors.red,
                          titleColor: Colors.red,
                          onTap: _logout,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (iconColor ?? const Color(0xFF00C977)).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: iconColor ?? const Color(0xFF00C977),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: titleColor ?? const Color(0xFF252940),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}
