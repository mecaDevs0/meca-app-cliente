import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/theme_service.dart';
import '../../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _workshops = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    // Carregar serviços
    final servicesResult = await _apiService.getServices();
    if (servicesResult['success'] && servicesResult['data'] != null) {
      _services = List<Map<String, dynamic>>.from(servicesResult['data']);
    }

    // Carregar oficinas
    final workshopsResult = await _apiService.getWorkshops();
    if (workshopsResult['success'] && workshopsResult['data'] != null) {
      _workshops = List<Map<String, dynamic>>.from(workshopsResult['data']);
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDark = themeService.isDarkMode;
        
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
          body: SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C977)),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: const Color(0xFF00C977),
                    backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                    child: CustomScrollView(
                      slivers: [
                        // AppBar com tema
                        SliverAppBar(
                          expandedHeight: 120,
                          floating: false,
                          pinned: true,
                          backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                          flexibleSpace: FlexibleSpaceBar(
                            background: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? [
                                          const Color(0xFF00C977),
                                          const Color(0xFF00B369),
                                          const Color(0xFF00A85C),
                                        ]
                                      : [
                                          const Color(0xFF00C977),
                                          const Color(0xFF00B369),
                                        ],
                                ),
                              ),
                              child: SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Image.asset(
                                              'assets/logos/icone_branco.png',
                                              width: 30,
                                              height: 30,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Olá! 👋',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  'Encontre a oficina perfeita',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => Navigator.pushNamed(context, '/notifications'),
                                            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Conteúdo
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Seção de Serviços
                                Text(
                                  'Serviços Populares',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF2D3748),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                SizedBox(
                                  height: 140,
                                  child: _services.isEmpty
                                      ? Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Nenhum serviço disponível',
                                              style: TextStyle(
                                                color: isDark ? const Color(0xFF8B8B8B) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        )
                                      : ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: _services.length,
                                          itemBuilder: (context, index) {
                                            final service = _services[index];
                                            return _buildServiceCard(service, isDark);
                                          },
                                        ),
                                ),

                                const SizedBox(height: 30),

                                // Filtros
                                Row(
                                  children: [
                                    Text(
                                      'Oficinas Próximas',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF2D3748),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00C977).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.filter_list, color: Color(0xFF00C977)),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 15),

                                // Lista de Oficinas
                                _workshops.isEmpty
                                    ? Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Nenhuma oficina disponível',
                                            style: TextStyle(
                                              color: isDark ? const Color(0xFF8B8B8B) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _workshops.length,
                                        itemBuilder: (context, index) {
                                          final workshop = _workshops[index];
                                          return _buildWorkshopCard(workshop, isDark);
                                        },
                                      ),

                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service, bool isDark) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF00C977),
            Color(0xFF00B369),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C977).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.build,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              service['name'] ?? 'Serviço',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkshopCard(Map<String, dynamic> workshop, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C977), Color(0xFF00B369)],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.garage,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workshop['name'] ?? 'Oficina',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '4.5',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? const Color(0xFF8B8B8B) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Icon(Icons.location_on, 
                          color: isDark ? const Color(0xFF8B8B8B) : const Color(0xFF64748B), 
                          size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '2.5 km',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? const Color(0xFF8B8B8B) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    workshop['address'] ?? 'Endereço não disponível',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF8B8B8B) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00C977).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF00C977),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
