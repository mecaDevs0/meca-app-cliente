import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../../services/api_service.dart';
import '../../widgets/animation_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  Position? _currentPosition;
  bool _loading = true;
  
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _workshops = [];
  
  String _selectedFilter = 'Distância'; // Distância, Nota, Nome, Preço
  String _searchQuery = '';
  
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() => _currentTabIndex = _tabController.index);
    });
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _loading = true);
    
    try {
      // Get location
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      
      final position = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = position);
      
      // Load services and workshops
      await Future.wait([
        _loadServices(),
        _loadWorkshops(),
      ]);
    } catch (e) {
      print('Error initializing: $e');
    }
    
    setState(() => _loading = false);
  }

  Future<void> _loadServices() async {
    final result = await _apiService.getMasterServices();
    if (result['success']) {
      setState(() {
        _services = (result['data']['services'] as List?)
            ?.cast<Map<String, dynamic>>() ?? [];
      });
    }
  }

  Future<void> _loadWorkshops() async {
    final result = await _apiService.getWorkshops(
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
      radius: 50.0,
    );
    if (result['success']) {
      setState(() {
        _workshops = (result['data']['workshops'] as List?)
            ?.cast<Map<String, dynamic>>() ?? [];
      });
    }
  }

  void _sortWorkshops(String filter) {
    setState(() {
      _selectedFilter = filter;
      switch (filter) {
        case 'Nota':
          _workshops.sort((a, b) => 
            (b['rating'] ?? 0.0).compareTo(a['rating'] ?? 0.0));
          break;
        case 'Nome':
          _workshops.sort((a, b) => 
            (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
          break;
        case 'Preço':
          _workshops.sort((a, b) => 
            (a['avg_price'] ?? 0.0).compareTo(b['avg_price'] ?? 0.0));
          break;
        case 'Distância':
        default:
          _workshops.sort((a, b) => 
            (a['distance'] ?? 0.0).compareTo(b['distance'] ?? 0.0));
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading ? _buildLoading() : _buildContent(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildLoading() {
    return Container(
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimationWidgets.buildLoadingAnimation(width: 150, height: 150),
            const SizedBox(height: 30),
            const Text(
              'Carregando...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: 120,
          floating: false,
          pinned: true,
          backgroundColor: const Color(0xFF00C977),
          flexibleSpace: FlexibleSpaceBar(
            title: const Text(
              'MECA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
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
                  ],
                ),
              ),
            ),
          ),
        ),

        // Search Bar
        SliverToBoxAdapter(
          child: Container(
            color: const Color(0xFF00C977),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Buscar serviços ou oficinas...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF00C977)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.filter_list, color: Color(0xFF252940)),
                    onPressed: _showFilterDialog,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Services Carousel
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Text(
                  'Serviços Populares',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF252940),
                  ),
                ),
              ),
              SizedBox(
                height: 140,
                child: _services.isEmpty
                    ? const Center(child: Text('Nenhum serviço disponível'))
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _services.length,
                        itemBuilder: (context, index) {
                          final service = _services[index];
                          return _buildServiceCard(service);
                        },
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),

        // Workshops Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Oficinas Próximas',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF252940),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C977).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.sort,
                        size: 16,
                        color: Color(0xFF00C977),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedFilter,
                        style: const TextStyle(
                          color: Color(0xFF00C977),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Workshops List
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: _workshops.isEmpty
              ? SliverToBoxAdapter(
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhuma oficina encontrada',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final workshop = _workshops[index];
                      return _buildWorkshopCard(workshop);
                    },
                    childCount: _workshops.length,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/service-detail',
          arguments: service,
        );
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF00C977).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getServiceIcon(service['name']?.toString() ?? ''),
                color: const Color(0xFF00C977),
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                service['name']?.toString() ?? 'Serviço',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF252940),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkshopCard(Map<String, dynamic> workshop) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/workshop-detail',
          arguments: workshop,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFF00C977).withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.build_circle,
                      size: 60,
                      color: const Color(0xFF00C977).withOpacity(0.3),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (workshop['rating'] ?? 4.8).toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workshop['name']?.toString() ?? 'Oficina',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF252940),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          workshop['address']?.toString() ?? 'Endereço não disponível',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C977).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(workshop['distance'] ?? 0).toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00C977),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.phone,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        workshop['phone']?.toString() ?? '(11) 0000-0000',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Aberto',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getServiceIcon(String serviceName) {
    final name = serviceName.toLowerCase();
    if (name.contains('óleo') || name.contains('oleo')) {
      return Icons.oil_barrel;
    } else if (name.contains('freio')) {
      return Icons.disc_full;
    } else if (name.contains('suspensão') || name.contains('suspensao')) {
      return Icons.settings_input_component;
    } else if (name.contains('alinhamento') || name.contains('balanceamento')) {
      return Icons.compare_arrows;
    } else if (name.contains('bateria')) {
      return Icons.battery_charging_full;
    } else if (name.contains('ar condicionado') || name.contains('ar')) {
      return Icons.ac_unit;
    } else {
      return Icons.build;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ordenar por'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption('Distância'),
            _buildFilterOption('Nota'),
            _buildFilterOption('Nome'),
            _buildFilterOption('Preço'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String filter) {
    final isSelected = _selectedFilter == filter;
    return ListTile(
      title: Text(filter),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFF00C977))
          : null,
      selected: isSelected,
      selectedTileColor: const Color(0xFF00C977).withOpacity(0.1),
      onTap: () {
        _sortWorkshops(filter);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Início', 0),
              _buildNavItem(Icons.calendar_today, 'Agendamentos', 1),
              _buildNavItem(Icons.person, 'Perfil', 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentTabIndex = index);
        switch (index) {
          case 1:
            Navigator.pushNamed(context, '/orders');
            break;
          case 2:
            Navigator.pushNamed(context, '/profile');
            break;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00C977).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF00C977) : Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFF00C977) : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}



