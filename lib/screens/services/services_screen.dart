import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../utils/price_utils.dart';
import '../../widgets/meca_loading_widget.dart';
import 'service_detail_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({Key? key}) : super(key: key);

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _services = [];
  bool _loading = true;
  String _error = '';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final result = await _apiService.getServices();
      
      if (result['success']) {
        final rawData = result['data'];
        List<Map<String, dynamic>> servicesList = [];

        if (rawData is List) {
          servicesList = rawData
              .whereType<Map>()
              .map((service) => Map<String, dynamic>.from(service))
              .toList();
        } else if (rawData is Map) {
          final nested = rawData['services'] ?? rawData['data'];
          if (nested is List) {
            servicesList = nested
                .whereType<Map>()
                .map((service) => Map<String, dynamic>.from(service))
                .toList();
          }
        }

        setState(() {
          _services = servicesList;
          _loading = false;
        });
      } else {
        setState(() {
          _error = result['error'] ?? 'Erro ao carregar serviços';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erro de conexão. Verifique sua internet.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: themeService.isDarkMode ? const Color(0xFF0A0A0A) : Colors.grey[50],
          appBar: AppBar(
            title: const Text(
              'Serviços',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF00C977),
              ),
            ),
            backgroundColor: themeService.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Color(0xFF00C977)),
          ),
          body: _loading
              ? const MecaApiLoadingWidget(message: 'Carregando serviços...')
              : _error.isNotEmpty
                  ? _buildErrorWidget()
                  : _buildServicesList(),
        );
      },
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              'Erro ao carregar serviços',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00C977),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadServices,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C977),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesList() {
    final filteredServices = _services.where((service) {
      final query = _searchQuery.toLowerCase();
      if (query.isEmpty) return true;
      final name = service['name']?.toString().toLowerCase() ?? '';
      final description = service['description']?.toString().toLowerCase() ?? '';
      final category = service['category']?.toString().toLowerCase() ?? '';
      return name.contains(query) || description.contains(query) || category.contains(query);
    }).toList();

    final bool hasOriginalServices = _services.isNotEmpty;
    final bool noResults = hasOriginalServices ? filteredServices.isEmpty : _searchQuery.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            cursorColor: const Color(0xFF00C977),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Color(0xFF00C977)),
              hintText: 'Buscar serviço por nome ou descrição...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF00C977), width: 2),
              ),
            ),
          ),
        ),
        if (!hasOriginalServices && _searchQuery.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.build_outlined,
                      size: 80,
                      color: Color(0xFF00C977),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Nenhum serviço disponível',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00C977),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Não há serviços cadastrados no momento.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (noResults)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.search_off_rounded,
                      size: 72,
                      color: Color(0xFF00C977),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum serviço encontrado para "${_searchQuery.trim()}"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: filteredServices.length,
              itemBuilder: (context, index) {
                final service = filteredServices[index];
                return _buildServiceCard(service);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final String serviceName = (service['name'] ?? 'Serviço').toString();
        final String? description = service['description']?.toString();
        final String? priceLabel = PriceUtils.formatCurrency(service['price'] ?? service['service_price']);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _navigateToServiceDetail(service),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF00B07F),
                    Color(0xFF007E6C),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.build,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.75),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Ver oficinas próximas',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (priceLabel != null) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  priceLabel!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ],
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

  void _navigateToServiceDetail(Map<String, dynamic> service) {
    final serviceId = (service['id'] ?? service['service_id'] ?? '').toString();
    final workshopId = service['workshop_id']?.toString() ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceDetailScreen(
          serviceId: serviceId,
          workshopId: workshopId,
        ),
      ),
    );
  }
}