import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_alerts.dart';
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

  Future<void> _loadVehicles({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _vehicles = [];
    });
    
    // Invalidar cache se forçar refresh
    if (forceRefresh) {
      _apiService.invalidateVehiclesCache();
    }
    
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
      AppAlerts.showError(
        context,
        message: 'Não foi possível identificar sua conta. Faça login novamente para ver seus veículos.',
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
        AppAlerts.showSuccess(
          context,
          message: result['message'] ??
              (isFavorite ? 'Veículo adicionado aos favoritos.' : 'Veículo removido dos favoritos.'),
        );
        _loadVehicles(forceRefresh: true); // Recarrega a lista forçando refresh
      } else {
        AppAlerts.showError(
          context,
          message: result['error'] ?? 'Não foi possível alterar os favoritos agora. Tente novamente em instantes.',
        );
      }
    } catch (e) {
      AppAlerts.showError(
        context,
        message: 'Não foi possível alterar os favoritos agora. Tente novamente em instantes.',
      );
    }
  }

  Future<void> _confirmDeleteVehicle(Map<String, dynamic> vehicle) async {
    final plate = vehicle['plate'] ?? vehicle['placa'] ?? vehicle['license_plate'] ?? 'este veículo';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Veículo'),
        content: Text('Tem certeza que deseja remover o veículo $plate? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteVehicle(vehicle['id'].toString());
    }
  }

  Future<void> _deleteVehicle(String vehicleId) async {
    try {
      final result = await _apiService.deleteVehicle(vehicleId);
      
      if (result['success']) {
        AppAlerts.showSuccess(
          context,
          message: result['message'] ?? 'Veículo removido com sucesso.',
        );
        _loadVehicles(forceRefresh: true); // Recarrega a lista forçando refresh
      } else {
        AppAlerts.showError(
          context,
          message: result['error'] ?? 'Não foi possível remover o veículo agora. Tente novamente em instantes.',
        );
      }
    } catch (e) {
      AppAlerts.showError(
        context,
        message: 'Não foi possível remover o veículo agora. Tente novamente em instantes.',
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
                  Navigator.pushNamed(context, '/add-vehicle').then((_) => _loadVehicles(forceRefresh: true));
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
                                    Navigator.pushNamed(context, '/add-vehicle').then((_) => _loadVehicles(forceRefresh: true));
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
        final isDark = themeService.isDarkMode;
        final vehicleColor = _getVehicleColor(vehicle['color']);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/edit-vehicle',
                  arguments: vehicle,
                ).then((_) => _loadVehicles(forceRefresh: true));
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header com ícone e ações
                    Row(
                      children: [
                        // Car Icon moderno com cor do veículo - Design iOS style
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                vehicleColor,
                                vehicleColor.withOpacity(0.8),
                                vehicleColor.withOpacity(0.6),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: vehicleColor.withOpacity(0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.2 : 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Efeito de brilho sutil
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.2),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              // Ícone do carro
                              Icon(
                                Icons.electric_car_rounded,
                                color: Colors.white,
                                size: 36,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Vehicle Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              // Placa e Ano na mesma linha
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      vehicle['plate'] ?? 'ABC-1234',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.2,
                                        fontSize: 13,
                                        fontFeatures: [const FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildInfoChip(
                                    icon: Icons.calendar_today_rounded,
                                    label: '${vehicle['year'] ?? '2024'}',
                                    isDark: isDark,
                                    compact: true,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Favorite button (compacto)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              final currentFavorite = vehicle['is_favorite'] == true || vehicle['is_favorite'] == 'true';
                              _toggleFavorite(vehicle['id'].toString(), !currentFavorite);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                (vehicle['is_favorite'] == true || vehicle['is_favorite'] == 'true') 
                                    ? Icons.star_rounded 
                                    : Icons.star_outline_rounded,
                                color: (vehicle['is_favorite'] == true || vehicle['is_favorite'] == 'true')
                                    ? Colors.amber 
                                    : (isDark ? Colors.grey[600] : Colors.grey[400]),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Info adicional (combustível se houver)
                    if (vehicle['fuel'] != null && vehicle['fuel'].toString().isNotEmpty)
                      Row(
                        children: [
                          _buildInfoChip(
                            icon: Icons.local_gas_station_rounded,
                            label: vehicle['fuel'].toString(),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    // Action buttons row
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.history_rounded,
                            label: 'Histórico',
                            color: const Color(0xFF00C977),
                            isDark: isDark,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VehicleHistoryScreen(
                                    vehicleId: (vehicle['id'] ?? '').toString(),
                                    plate: (vehicle['plate'] ?? vehicle['placa'] ?? vehicle['license_plate'] ?? '').toString(),
                                    vehicle: vehicle,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.edit_rounded,
                            label: 'Editar',
                            color: const Color(0xFF007AFF),
                            isDark: isDark,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/edit-vehicle',
                                arguments: vehicle,
                              ).then((_) => _loadVehicles(forceRefresh: true));
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.delete_outline_rounded,
                            label: 'Remover',
                            color: Colors.red,
                            isDark: isDark,
                            onTap: () => _confirmDeleteVehicle(vehicle),
                          ),
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

  Widget _buildInfoChip({required IconData icon, required String label, required bool isDark, bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 6 : 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getVehicleColor(dynamic colorValue) {
    if (colorValue == null || colorValue.toString().isEmpty) {
      return const Color(0xFF00C977); // Cor padrão MECA
    }
    
    final colorStr = colorValue.toString().toLowerCase().trim();
    
    // Mapeamento de cores comuns
    final colorMap = {
      'vermelho': Colors.red,
      'red': Colors.red,
      'azul': Colors.blue,
      'blue': Colors.blue,
      'verde': Colors.green,
      'green': Colors.green,
      'amarelo': Colors.yellow,
      'yellow': Colors.yellow,
      'branco': Colors.white,
      'white': Colors.white,
      'preto': Colors.black,
      'black': Colors.black,
      'cinza': Colors.grey,
      'gray': Colors.grey,
      'gris': Colors.grey,
      'prata': Colors.grey[300]!,
      'silver': Colors.grey[300]!,
      'laranja': Colors.orange,
      'orange': Colors.orange,
      'rosa': Colors.pink,
      'pink': Colors.pink,
      'roxo': Colors.purple,
      'purple': Colors.purple,
      'marrom': Colors.brown,
      'brown': Colors.brown,
    };
    
    // Tentar encontrar cor no mapa
    if (colorMap.containsKey(colorStr)) {
      return colorMap[colorStr]!;
    }
    
    // Tentar parsear como hex
    if (colorStr.startsWith('#')) {
      try {
        return Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
      } catch (e) {
        // Ignorar erro de parse
      }
    }
    
    // Cor padrão se não conseguir identificar
    return const Color(0xFF00C977);
  }
}
