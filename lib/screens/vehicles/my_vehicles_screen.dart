import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/meca_loading_widget.dart';
import 'vehicle_history_screen.dart';

class MyVehiclesScreen extends StatefulWidget {
  const MyVehiclesScreen({Key? key}) : super(key: key);

  @override
  State<MyVehiclesScreen> createState() => _MyVehiclesScreenState();
}

class _MyVehiclesScreenState extends State<MyVehiclesScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _vehicles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() => _loading = true);
    
    // Obter ID do cliente do perfil
    String? customerId;
    try {
      final profileResult = await _apiService.getProfile();
      if (profileResult['success'] && profileResult['data'] != null) {
        customerId = profileResult['data']['id'] ?? 
                    profileResult['data']['customer_id'];
      }
    } catch (e) {
      print('Erro ao obter perfil: $e');
    }

    if (customerId == null || customerId.isEmpty) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Erro: Não foi possível identificar o usuário. Faça login novamente.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final result = await _apiService.getMyVehicles(customerId);
    
    if (result['success']) {
      final vehiclesList = (result['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      // Remover duplicatas baseado no ID
      final uniqueVehicles = <String, Map<String, dynamic>>{};
      for (var vehicle in vehiclesList) {
        final id = vehicle['id']?.toString() ?? '';
        if (id.isNotEmpty && !uniqueVehicles.containsKey(id)) {
          uniqueVehicles[id] = vehicle;
        }
      }
      setState(() {
        _vehicles = uniqueVehicles.values.toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorite(String vehicleId, bool isFavorite) async {
    try {
      final result = await _apiService.toggleFavoriteVehicle(vehicleId, isFavorite);
      
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFavorite ? 'Veículo adicionado aos favoritos' : 'Veículo removido dos favoritos'),
            backgroundColor: const Color(0xFF00C977),
            duration: const Duration(seconds: 2),
          ),
        );
        _loadVehicles(); // Recarrega a lista
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Erro ao favoritar veículo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao favoritar veículo'),
          backgroundColor: Colors.red,
        ),
      );
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
              'Meus Veículos',
              style: TextStyle(
                color: themeService.isDarkMode 
                    ? Colors.white 
                    : const Color(0xFF252940),
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle, color: Color(0xFF00C977), size: 28),
                onPressed: () {
                  Navigator.pushNamed(context, '/add-vehicle').then((_) => _loadVehicles());
                },
              ),
            ],
          ),
          body: _loading
              ? const MecaApiLoadingWidget(message: 'Carregando veículos...')
              : _vehicles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C977).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF00C977).withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.directions_car,
                                  size: 80,
                                  color: Color(0xFF00C977),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Nenhum veículo cadastrado',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00C977),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Adicione um veículo para começar',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/add-vehicle').then((_) => _loadVehicles());
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Adicionar Veículo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00C977),
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF00C977),
                      onRefresh: _loadVehicles,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(15),
                        itemCount: _vehicles.length,
                        itemBuilder: (context, index) {
                          final vehicle = _vehicles[index];
                          return _buildVehicleCard(vehicle);
                        },
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            color: themeService.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/vehicle-detail',
                  arguments: vehicle,
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Car Icon (reduzido)
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C977), Color(0xFF00B369)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.directions_car,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 15),
                    // Vehicle Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${vehicle['brand']} ${vehicle['model']}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: themeService.isDarkMode ? Colors.white : const Color(0xFF252940),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF252940),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              vehicle['plate'] ?? 'ABC-1234',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Ano: ${vehicle['year'] ?? '2024'}',
                            style: TextStyle(
                              color: themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action Buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Favorite button
                        IconButton(
                          icon: Icon(
                            (vehicle['is_favorite'] == true || vehicle['is_favorite'] == 'true') ? Icons.star : Icons.star_border,
                            color: (vehicle['is_favorite'] == true || vehicle['is_favorite'] == 'true')
                                ? Colors.amber 
                                : const Color(0xFF00C977),
                          ),
                          onPressed: () {
                            final currentFavorite = vehicle['is_favorite'] == true || vehicle['is_favorite'] == 'true';
                            _toggleFavorite(vehicle['id'].toString(), !currentFavorite);
                          },
                          tooltip: (vehicle['is_favorite'] == true || vehicle['is_favorite'] == 'true') ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
                        ),
                        // History button
                        IconButton(
                          icon: const Icon(Icons.history, color: Color(0xFF00C977)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VehicleHistoryScreen(
                                  vehicleId: vehicle['id'],
                                  vehicle: vehicle,
                                ),
                              ),
                            );
                          },
                          tooltip: 'Ver histórico',
                        ),
                        // Edit button
                        IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFF00C977)),
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/edit-vehicle',
                              arguments: vehicle,
                            ).then((_) => _loadVehicles());
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
