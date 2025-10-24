import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/api_service.dart';
import '../../widgets/meca_loading_widget.dart';
import 'workshop_detail_screen.dart';

class WorkshopsScreen extends StatefulWidget {
  const WorkshopsScreen({Key? key}) : super(key: key);

  @override
  State<WorkshopsScreen> createState() => _WorkshopsScreenState();
}

class _WorkshopsScreenState extends State<WorkshopsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _workshops = [];
  List<dynamic> _filteredWorkshops = [];
  bool _loading = false;
  String _error = '';
  Position? _currentPosition;
  
  // Filtros
  final TextEditingController _searchController = TextEditingController();
  String _selectedService = 'Todos';
  String _selectedDistance = 'Todos';
  String _selectedRating = 'Todos';
  String _selectedInstallment = 'Todos';
  String _sortBy = 'distancia';

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
    _loadNearbyWorkshops();
  }

  Future<void> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print('Erro ao obter localização: $e');
    }
  }

  Future<void> _loadNearbyWorkshops() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    
    try {
      // Verificar se o serviço de localização está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _error = 'Serviço de localização desabilitado. Por favor, ative o GPS nas configurações do dispositivo.';
          _loading = false;
        });
        return;
      }

      // Verificar permissões
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _error = 'Permissão de localização negada. Por favor, permita o acesso à localização nas configurações do dispositivo.';
            _loading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _error = 'Permissão de localização permanentemente negada. Por favor, permita o acesso à localização nas configurações do dispositivo.';
          _loading = false;
        });
        return;
      }

      // Obter localização atual
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      final result = await _apiService.getNearbyWorkshops(
        position.latitude,
        position.longitude,
      );
      
      if (!mounted) return;
             if (result['success']) {
               List<dynamic> workshops = result['data']['workshops'] ?? [];
               
               // Calcular distâncias e adicionar aos dados
               for (var workshop in workshops) {
                 if (workshop['latitude'] != null && workshop['longitude'] != null) {
                   double distance = Geolocator.distanceBetween(
                     position.latitude,
                     position.longitude,
                     double.parse(workshop['latitude'].toString()),
                     double.parse(workshop['longitude'].toString()),
                   ) / 1000; // Converter para km
                   
                   workshop['distance'] = distance;
                 } else {
                   workshop['distance'] = 0.0;
                 }
               }
               
               setState(() {
                 _workshops = workshops;
                 _filteredWorkshops = List.from(_workshops);
                 _loading = false;
               });
               _applyFilters();
             } else {
        setState(() {
          _error = result['error'] ?? 'Erro ao carregar oficinas';
          _loading = false;
        });
      }
    } catch (e) {
      String errorMessage = 'Erro ao carregar oficinas';
      if (e.toString().contains('permission')) {
        errorMessage = 'Erro ao obter localização: Permissão de localização negada. Por favor, permita o acesso à localização nas configurações do dispositivo.';
      } else if (e.toString().contains('location')) {
        errorMessage = 'Erro ao obter localização: Não foi possível acessar sua localização atual. Verifique se o GPS está ativado.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Timeout ao obter localização. Verifique se o GPS está ativado e tente novamente.';
      } else {
        errorMessage = 'Erro ao carregar oficinas: $e';
      }
      
      if (!mounted) return;
      setState(() {
        _error = errorMessage;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // AppBar melhorado
          SliverAppBar(
            expandedHeight: 50,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF00C977),
            flexibleSpace: FlexibleSpaceBar(
              title: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    const Text(
                      'Oficinas Próximas',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.filter_list, color: Colors.white, size: 16),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () {
                          _showFilterModal();
                        },
                      ),
                    ),
                  ],
                ),
              ),
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
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Barra de pesquisa
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => _applyFilters(),
                decoration: InputDecoration(
                  hintText: 'Buscar por nome ou bairro...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF00C977)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFF1E1E1E) 
                      : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[700]! 
                          : Colors.grey[300]!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[700]! 
                          : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00C977), width: 2),
                  ),
                ),
              ),
            ),
          ),
          // Conteúdo
          SliverFillRemaining(
            child: _loading
                ? const MecaApiLoadingWidget(message: 'Buscando oficinas...')
                : _error.isNotEmpty
                    ? _buildErrorView()
                    : _buildWorkshopsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            Text(
              'Erro ao carregar oficinas',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadNearbyWorkshops,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C977),
              ),
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkshopsList() {
    if (_filteredWorkshops.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma oficina encontrada com os filtros aplicados',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredWorkshops.length,
      itemBuilder: (context, index) {
        final workshop = _filteredWorkshops[index];
        return _buildWorkshopCard(workshop);
      },
    );
  }

  Widget _buildWorkshopCard(Map<String, dynamic> workshop) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Usar distância real calculada
    final distance = workshop['distance'] ?? 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFF00C977).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF333333) : const Color(0xFF00C977).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WorkshopDetailScreen(workshopId: workshop['id']),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Logo da oficina
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C977), Color(0xFF00B369)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00C977).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: workshop['logo'] != null && 
                             workshop['logo'].isNotEmpty && 
                             workshop['logo'] != '' &&
                             workshop['logo'].startsWith('http')
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                workshop['logo'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.build,
                                    color: Colors.white,
                                    size: 35,
                                  );
                                },
                              ),
                            )
                          : const Icon(
                              Icons.build,
                              color: Colors.white,
                              size: 35,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workshop['name'] ?? 'Oficina',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? const Color(0xFF00C977) : const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Color(0xFF00C977),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  workshop['address'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Rating
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${workshop['rating'] ?? 4.5}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Distance
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C977).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.navigation,
                                      color: Color(0xFF00C977),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      distance > 0 ? '${distance.toStringAsFixed(1)} km' : 'Distância não disponível',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF00C977),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Services
                if (workshop['services'] != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (workshop['services'] as List).take(3).map((service) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C977).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF00C977).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          service,
                          style: const TextStyle(
                            color: Color(0xFF00C977),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 12),
                // Action button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C977), Color(0xFF00B369)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Ver Detalhes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  String _calculateDistance(Map<String, dynamic> workshop) {
    // Simula cálculo de distância (em produção, usar geolocalização real)
    final random = DateTime.now().millisecondsSinceEpoch % 100;
    if (random < 30) return '0.5 km';
    if (random < 60) return '1.2 km';
    if (random < 80) return '2.8 km';
    return '4.5 km';
  }
  
  void _applyFilters() {
    setState(() {
      _filteredWorkshops = _workshops.where((workshop) {
        // Filtro por nome/bairro/endereço
        if (_searchController.text.isNotEmpty) {
          final searchText = _searchController.text.toLowerCase();
          final name = (workshop['name'] ?? '').toString().toLowerCase();
          final address = (workshop['address'] ?? '').toString().toLowerCase();
          final neighborhood = (workshop['neighborhood'] ?? '').toString().toLowerCase();
          if (!name.contains(searchText) && !address.contains(searchText) && !neighborhood.contains(searchText)) {
            return false;
          }
        }
        
        // Filtro por serviço
        if (_selectedService != 'Todos') {
          final services = workshop['services'] ?? [];
          bool hasService = false;
          for (var service in services) {
            if (service['name'] == _selectedService) {
              hasService = true;
              break;
            }
          }
          if (!hasService) return false;
        }
        
        // Filtro por distância
        if (_selectedDistance != 'Todos') {
          final distance = workshop['distance'] ?? 0.0;
          switch (_selectedDistance) {
            case 'Até 1km':
              if (distance > 1.0) return false;
              break;
            case 'Até 5km':
              if (distance > 5.0) return false;
              break;
            case 'Até 10km':
              if (distance > 10.0) return false;
              break;
            case 'Até 20km':
              if (distance > 20.0) return false;
              break;
          }
        }
        
        // Filtro por avaliação
        if (_selectedRating != 'Todos') {
          final rating = workshop['rating'] ?? 0.0;
          switch (_selectedRating) {
            case '5 estrelas':
              if (rating < 5.0) return false;
              break;
            case '4+ estrelas':
              if (rating < 4.0) return false;
              break;
            case '3+ estrelas':
              if (rating < 3.0) return false;
              break;
            case '2+ estrelas':
              if (rating < 2.0) return false;
              break;
          }
        }
        
        // Filtro por parcelamento
        if (_selectedInstallment != 'Todos') {
          final acceptsInstallment = workshop['accepts_installment'] ?? false;
          if (_selectedInstallment == 'Aceita parcelamento' && !acceptsInstallment) return false;
          if (_selectedInstallment == 'Não aceita parcelamento' && acceptsInstallment) return false;
        }
        
        return true;
      }).toList();
      
      // Ordenação
      _filteredWorkshops.sort((a, b) {
        switch (_sortBy) {
          case 'distancia':
            return _calculateDistance(a).compareTo(_calculateDistance(b));
          case 'avaliacao':
            final ratingA = a['rating'] ?? 0.0;
            final ratingB = b['rating'] ?? 0.0;
            return ratingB.compareTo(ratingA);
          case 'nome':
            final nameA = (a['name'] ?? '').toString();
            final nameB = (b['name'] ?? '').toString();
            return nameA.compareTo(nameB);
          default:
            return 0;
        }
      });
    });
  }
  
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtros',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedService = 'Todos';
                        _selectedDistance = 'Todos';
                        _selectedRating = 'Todos';
                        _selectedInstallment = 'Todos';
                        _sortBy = 'distancia';
                      });
                      _applyFilters();
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Limpar',
                      style: TextStyle(color: Color(0xFF00C977)),
                    ),
                  ),
                ],
              ),
            ),
            // Filtros
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Seção de Ordenação
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ordenar por',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00C977),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildSortOption('Distância', 'distancia'),
                          _buildSortOption('Avaliação', 'avaliacao'),
                          _buildSortOption('Nome', 'nome'),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Seção de Filtros
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filtrar por',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00C977),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Serviço
                          _buildFilterSection(
                            'Serviço',
                            _selectedService,
                            ['Todos', 'Revisão para venda/compra de veículo', 'Revisões Preventivas', 'Serviços de direção hidráulica/elétrica', 'Serviços de escapamento', 'Serviços de motor e câmbio', 'Serviços para carros antigos (restauração)', 'Sistema de arrefecimento (radiador e bomba d\'água)', 'Sistema de Embreagem', 'Troca de correia dentada e correias auxiliares', 'Troca de óleo e filtros'],
                            (value) {
                              setState(() => _selectedService = value);
                            },
                          ),
                          const SizedBox(height: 16),
                          // Distância
                          _buildFilterSection(
                            'Distância',
                            _selectedDistance,
                            ['Todos', 'Até 1km', 'Até 5km', 'Até 10km', 'Até 20km'],
                            (value) {
                              setState(() => _selectedDistance = value);
                            },
                          ),
                          const SizedBox(height: 16),
                          // Avaliação
                          _buildFilterSection(
                            'Avaliação',
                            _selectedRating,
                            ['Todos', '5 estrelas', '4+ estrelas', '3+ estrelas', '2+ estrelas'],
                            (value) {
                              setState(() => _selectedRating = value);
                            },
                          ),
                          const SizedBox(height: 16),
                          // Parcelamento
                          _buildFilterSection(
                            'Aceita Parcelamento',
                            _selectedInstallment,
                            ['Todos', 'Aceita parcelamento', 'Não aceita parcelamento'],
                            (value) {
                              setState(() => _selectedInstallment = value);
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Botões
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00C977)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _applyFilters();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C977),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Aplicar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      },
    );
  }
  
  Widget _buildSortOption(String title, String value) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() => _sortBy = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00C977).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF00C977) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFF00C977) : Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00C977) : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFilterSection(String title, String selectedValue, List<String> options, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.map((option) {
            final isSelected = selectedValue == option;
            return GestureDetector(
              onTap: () => onChanged(option),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF00C977) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00C977) : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}