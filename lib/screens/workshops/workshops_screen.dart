import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';

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

      await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Posição obtida - não precisa armazenar
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
      
      // Buscar TODAS as oficinas (sem limite de raio)
      final result = await _apiService.getNearbyWorkshops(
        position.latitude,
        position.longitude,
        10000.0, // Raio muito grande para pegar todas (em km)
      );
      
      if (!mounted) return;
             if (result['success']) {
               final data = result['data'];
               List<dynamic> workshops = [];
               
               // Adaptar resposta para diferentes formatos
               if (data is Map) {
                 workshops = data['workshops'] ?? data['workshop'] ?? data['data'] ?? [];
               } else if (data is List) {
                 workshops = data;
               }
               
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

                 final addressDetails = _extractAddressDetails(workshop['address']);
                 if (addressDetails != null) {
                   workshop['address_details'] = addressDetails;
                   workshop['address'] = _formatAddress(addressDetails);
                 } else {
                   workshop['address'] = _formatAddress(workshop['address']);
                 }
                 workshop['logo_url'] = workshop['logo_url'] ?? workshop['logo'];
                 workshop['rating'] = _parseDouble(workshop['rating']);
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
          // AppBar melhorado com título na mesma linha dos botões
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFF00C977),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Oficinas Próximas',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: 0.3,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.25),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list, color: Colors.white, size: 20),
                onPressed: () {
                  _showFilterModal();
                },
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: Container(
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
                      Colors.white.withOpacity(0.15),
                      Colors.transparent,
                    ],
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
    final distanceRaw = workshop['distance'];
    final double distance = distanceRaw is num
        ? distanceRaw.toDouble()
        : distanceRaw is String
            ? double.tryParse(distanceRaw.replaceAll(',', '.')) ?? 0.0
            : 0.0;
    final double ratingValue = _parseDouble(workshop['rating']) ?? 0.0;
    
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
                      child: workshop['logo_url'] != null && 
                             workshop['logo_url'].isNotEmpty && 
                             workshop['logo_url'] != '' &&
                             workshop['logo_url'].startsWith('http')
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                workshop['logo_url'],
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
                                  _formatAddress(workshop['address'] ?? workshop['address_details']),
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
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
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
                                      ratingValue > 0
                                          ? ratingValue.toStringAsFixed(ratingValue >= 10 ? 0 : 1)
                                          : 'N/A',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
                                      distance > 0
                                          ? _formatDistance(distance)
                                          : 'Distância não disponível',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isDarkMode ? const Color(0xFF00C977) : const Color(0xFF00C977),
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
                      // Capitalizar primeira letra de cada palavra
                      final serviceName = service.toString();
                      final capitalizedService = serviceName.split(' ').map((word) {
                        if (word.isEmpty) return word;
                        return word[0].toUpperCase() + (word.length > 1 ? word.substring(1).toLowerCase() : '');
                      }).join(' ');
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDarkMode 
                              ? const Color(0xFF00C977).withOpacity(0.15)
                              : const Color(0xFF00C977).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF00C977).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          capitalizedService,
                          style: TextStyle(
                            color: const Color(0xFF00C977),
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
          double distanceValue = 0.0;
          if (distance is num) {
            distanceValue = distance.toDouble();
          } else if (distance is String) {
            distanceValue = double.tryParse(distance.replaceAll(' km', '').trim()) ?? 0.0;
          }
          switch (_selectedDistance) {
            case 'Até 1km':
              if (distanceValue > 1.0) return false;
              break;
            case 'Até 5km':
              if (distanceValue > 5.0) return false;
              break;
            case 'Até 10km':
              if (distanceValue > 10.0) return false;
              break;
            case 'Até 20km':
              if (distanceValue > 20.0) return false;
              break;
          }
        }
        
        // Filtro por avaliação
        if (_selectedRating != 'Todos') {
          final rating = workshop['rating'] ?? 0.0;
          double ratingValue = 0.0;
          if (rating is num) {
            ratingValue = rating.toDouble();
          } else if (rating is String) {
            ratingValue = double.tryParse(rating) ?? 0.0;
          }
          switch (_selectedRating) {
            case '5 estrelas':
              if (ratingValue < 5.0) return false;
              break;
            case '4+ estrelas':
              if (ratingValue < 4.0) return false;
              break;
            case '3+ estrelas':
              if (ratingValue < 3.0) return false;
              break;
            case '2+ estrelas':
              if (ratingValue < 2.0) return false;
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
            final distanceA = a['distance'] ?? 0.0;
            final distanceB = b['distance'] ?? 0.0;
            if (distanceA is num && distanceB is num) {
              return distanceA.toDouble().compareTo(distanceB.toDouble());
            }
            return 0;
          case 'avaliacao':
            final ratingA = a['rating'] ?? 0.0;
            final ratingB = b['rating'] ?? 0.0;
            if (ratingA is num && ratingB is num) {
              return ratingB.toDouble().compareTo(ratingA.toDouble());
            }
            return 0;
          case 'nome':
            final nameA = (a['name'] ?? '').toString().toLowerCase();
            final nameB = (b['name'] ?? '').toString().toLowerCase();
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
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
                      Text(
                        'Filtros',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedService = 'Todos';
                            _selectedDistance = 'Todos';
                            _selectedRating = 'Todos';
                            _selectedInstallment = 'Todos';
                            _sortBy = 'distancia';
                          });
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
                            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ordenar por',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : const Color(0xFF00C977),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildSortOption('Distância', 'distancia', isDarkMode, () {
                                setModalState(() {
                                  _sortBy = 'distancia';
                                });
                                setState(() {
                                  _sortBy = 'distancia';
                                });
                              }),
                              _buildSortOption('Avaliação', 'avaliacao', isDarkMode, () {
                                setModalState(() {
                                  _sortBy = 'avaliacao';
                                });
                                setState(() {
                                  _sortBy = 'avaliacao';
                                });
                              }),
                              _buildSortOption('Nome', 'nome', isDarkMode, () {
                                setModalState(() {
                                  _sortBy = 'nome';
                                });
                                setState(() {
                                  _sortBy = 'nome';
                                });
                              }),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Seção de Filtros
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filtrar por',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : const Color(0xFF00C977),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Serviço
                              _buildFilterSection(
                                'Serviço',
                                _selectedService,
                                ['Todos', 'Revisão para venda/compra de veículo', 'Revisões Preventivas', 'Serviços de direção hidráulica/elétrica', 'Serviços de escapamento', 'Serviços de motor e câmbio', 'Serviços para carros antigos (restauração)', 'Sistema de arrefecimento (radiador e bomba d\'água)', 'Sistema de Embreagem', 'Troca de correia dentada e correias auxiliares', 'Troca de óleo e filtros'],
                                isDarkMode,
                                (value) {
                                  setModalState(() {
                                    _selectedService = value;
                                  });
                                  setState(() {
                                    _selectedService = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              // Distância
                              _buildFilterSection(
                                'Distância',
                                _selectedDistance,
                                ['Todos', 'Até 1km', 'Até 5km', 'Até 10km', 'Até 20km'],
                                isDarkMode,
                                (value) {
                                  setModalState(() {
                                    _selectedDistance = value;
                                  });
                                  setState(() {
                                    _selectedDistance = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              // Avaliação
                              _buildFilterSection(
                                'Avaliação',
                                _selectedRating,
                                ['Todos', '5 estrelas', '4+ estrelas', '3+ estrelas', '2+ estrelas'],
                                isDarkMode,
                                (value) {
                                  setModalState(() {
                                    _selectedRating = value;
                                  });
                                  setState(() {
                                    _selectedRating = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              // Parcelamento
                              _buildFilterSection(
                                'Aceita Parcelamento',
                                _selectedInstallment,
                                ['Todos', 'Aceita parcelamento', 'Não aceita parcelamento'],
                                isDarkMode,
                                (value) {
                                  setModalState(() {
                                    _selectedInstallment = value;
                                  });
                                  setState(() {
                                    _selectedInstallment = value;
                                  });
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
                            setState(() {
                              // Aplicar filtros e atualizar estado
                              _applyFilters();
                            });
                            Navigator.pop(context);
                            // Recarregar lista após aplicar filtros
                            setState(() {});
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
      ),
    );
  }

  Widget _buildSortOption(String title, String value, bool isDarkMode, VoidCallback onTap) {
    final isSelected = _sortBy == value;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF00C977).withOpacity(0.15) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF00C977) 
                : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF00C977).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected 
                  ? const Color(0xFF00C977) 
                  : (isDarkMode ? Colors.grey[400] : Colors.grey[400]!),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected 
                    ? const Color(0xFF00C977) 
                    : (isDarkMode ? Colors.white70 : Colors.grey[600]!),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFilterSection(String title, String selectedValue, List<String> options, bool isDarkMode, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 8) / 2; // 2 cards por linha com 8px de espaçamento
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final isSelected = selectedValue == option;
                // Capitalizar primeira letra de cada palavra do nome do serviço
                final displayOption = option == 'Todos' 
                    ? option 
                    : option.split(' ').map((word) {
                        if (word.isEmpty) return word;
                        return word[0].toUpperCase() + (word.length > 1 ? word.substring(1).toLowerCase() : '');
                      }).join(' ');
                
                return SizedBox(
                  width: cardWidth,
                  child: InkWell(
                    onTap: () {
                      onChanged(option);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: cardWidth,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? const Color(0xFF00C977) 
                            : (isDarkMode ? const Color(0xFF2A2A2A) : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected 
                              ? const Color(0xFF00C977) 
                              : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                          width: isSelected ? 2 : 1.5,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: const Color(0xFF00C977).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
                      ),
                      child: Text(
                        displayOption,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected 
                              ? Colors.white 
                              : (isDarkMode ? Colors.white70 : Colors.grey[700]!),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Map<String, dynamic>? _extractAddressDetails(dynamic address) {
    if (address is Map<String, dynamic>) {
      return Map<String, dynamic>.from(address);
    }
    if (address is String) {
      try {
        final decoded = jsonDecode(address);
        if (decoded is Map<String, dynamic>) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String && value.trim().isNotEmpty) {
      return double.tryParse(value.trim().replaceAll(',', '.'));
    }
    return null;
  }

  String _formatDistance(double distance) {
    final formatted = distance >= 10
        ? distance.toStringAsFixed(0)
        : distance.toStringAsFixed(1);
    return '$formatted km';
  }

  String _formatAddress(dynamic address) {
    if (address == null) return 'Endereço não informado';
    if (address is String) {
      if (address.isEmpty) return 'Endereço não informado';
      return _sanitizeAddress(address);
    }
    if (address is Map) {
      final street = address['street'] ?? address['logradouro'] ?? address['addressLine1'];
      final number = address['number'] ?? address['numero'];
      final neighborhood = address['neighborhood'] ?? address['bairro'];
      final city = address['city'] ?? address['cidade'];
      final state = address['state'] ?? address['uf'];
      final cep = address['zip'] ?? address['cep'];

      final parts = <String>[];
      if (street != null) {
        if (number != null) {
          parts.add('$street, $number');
        } else {
          parts.add(street.toString());
        }
      }
      if (neighborhood != null) {
        parts.add(neighborhood.toString());
      }
      final cityState = [city, state]
          .where((element) => element != null && element.toString().isNotEmpty)
          .join(' - ');
      if (cityState.isNotEmpty) {
        parts.add(cityState);
      }
      if (cep != null && cep.toString().isNotEmpty) {
        parts.add('CEP ${cep.toString()}');
      }

      if (parts.isEmpty) {
        final rawValues = address.values
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .map(_sanitizeAddress)
            .toList();
        if (rawValues.isEmpty) return 'Endereço não informado';
        return rawValues.join(' • ');
      }

      return _sanitizeAddress(parts.join(' • '));
    }

    return _sanitizeAddress(address.toString());
  }

  String _sanitizeAddress(String value) {
    return value
        .replaceAll(RegExp(r'[\r\n]+'), ' • ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'(•\s*){2,}'), '• ')
        .trim();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}







