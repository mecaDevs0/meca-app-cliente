import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/api_service.dart';

class WorkshopsListScreen extends StatefulWidget {
  const WorkshopsListScreen({Key? key}) : super(key: key);

  @override
  State<WorkshopsListScreen> createState() => _WorkshopsListScreenState();
}

class _WorkshopsListScreenState extends State<WorkshopsListScreen> {
  final ApiService _apiService = ApiService();
  Position? _currentPosition;
  List<Map<String, dynamic>> _workshops = [];
  List<Map<String, dynamic>> _filteredWorkshops = [];
  bool _loading = true;
  String _sortBy = 'distancia';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });

      await _loadWorkshops();
    } catch (e) {
      print('Error initializing: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadWorkshops() async {
    setState(() => _loading = true);
    
    final result = await _apiService.getWorkshops(
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
      radius: 50.0,
    );

    if (result['success']) {
      final workshops = (result['data']['workshops'] as List?) ?? [];
      setState(() {
        _workshops = workshops.cast<Map<String, dynamic>>();
        _filteredWorkshops = List.from(_workshops);
        _applySorting();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  void _applySorting() {
    switch (_sortBy) {
      case 'distancia':
        _filteredWorkshops.sort((a, b) {
          final distA = a['distance'] ?? 999999;
          final distB = b['distance'] ?? 999999;
          return distA.compareTo(distB);
        });
        break;
      case 'nota':
        _filteredWorkshops.sort((a, b) {
          final ratingA = a['rating'] ?? 0;
          final ratingB = b['rating'] ?? 0;
          return ratingB.compareTo(ratingA);
        });
        break;
      case 'nome':
        _filteredWorkshops.sort((a, b) {
          final nameA = a['name'] ?? '';
          final nameB = b['name'] ?? '';
          return nameA.compareTo(nameB);
        });
        break;
      case 'preco':
        _filteredWorkshops.sort((a, b) {
          final priceA = a['average_price'] ?? 0;
          final priceB = b['average_price'] ?? 0;
          return priceA.compareTo(priceB);
        });
        break;
    }
  }

  void _filterWorkshops(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredWorkshops = List.from(_workshops);
      } else {
        _filteredWorkshops = _workshops.where((workshop) {
          final name = workshop['name']?.toString().toLowerCase() ?? '';
          final address = workshop['address']?.toString().toLowerCase() ?? '';
          return name.contains(query.toLowerCase()) || address.contains(query.toLowerCase());
        }).toList();
      }
      _applySorting();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Oficinas',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF00C977),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF00C977),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
            ),
            child: Container(
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
              child: TextField(
                controller: _searchController,
                onChanged: _filterWorkshops,
                decoration: InputDecoration(
                  hintText: 'Buscar oficinas...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF00C977)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
          ),

          // Filter and Sort
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredWorkshops.length} oficinas encontradas',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF252940),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      _sortBy = value;
                      _applySorting();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C977).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF00C977).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.sort, size: 18, color: Color(0xFF00C977)),
                        SizedBox(width: 5),
                        Text(
                          'Ordenar',
                          style: TextStyle(
                            color: Color(0xFF00C977),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'distancia', child: Text('Distância')),
                    const PopupMenuItem(value: 'nota', child: Text('Nota')),
                    const PopupMenuItem(value: 'nome', child: Text('Nome')),
                    const PopupMenuItem(value: 'preco', child: Text('Preço')),
                  ],
                ),
              ],
            ),
          ),

          // Workshops List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C977)))
                : _filteredWorkshops.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 20),
                            Text(
                              'Nenhuma oficina encontrada',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadWorkshops,
                        color: const Color(0xFF00C977),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _filteredWorkshops.length,
                          itemBuilder: (context, index) {
                            final workshop = _filteredWorkshops[index];
                            return _buildWorkshopCard(workshop);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkshopCard(Map<String, dynamic> workshop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
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
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.pushNamed(
              context,
              '/workshop-detail',
              arguments: workshop,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Workshop Image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C977).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.build,
                    color: Color(0xFF00C977),
                    size: 40,
                  ),
                ),
                const SizedBox(width: 15),
                // Workshop Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workshop['name'] ?? 'Oficina',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF252940),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 5),
                          Text(
                            '${workshop['rating'] ?? '4.5'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF252940),
                            ),
                          ),
                          Text(
                            ' (${workshop['reviews_count'] ?? '0'})',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              workshop['address'] ?? 'Endereço não disponível',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.directions_car, color: Colors.grey[600], size: 16),
                          const SizedBox(width: 5),
                          Text(
                            workshop['distance'] != null
                                ? '${(workshop['distance'] as num).toStringAsFixed(1)} km'
                                : 'Distância não disponível',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow Icon
                const Icon(Icons.arrow_forward_ios, color: Color(0xFF00C977), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}


