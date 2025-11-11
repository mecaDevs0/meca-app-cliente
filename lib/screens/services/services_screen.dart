import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
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
    if (_services.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.build_outlined,
                size: 80,
                color: Color(0xFF00C977),
              ),
              const SizedBox(height: 20),
              const Text(
                'Nenhum serviço disponível',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00C977),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Não há serviços cadastrados no momento',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _services.length,
      itemBuilder: (context, index) {
        final service = _services[index];
        return _buildServiceCard(service);
      },
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final String serviceName = (service['name'] ?? 'Serviço').toString();
        final String? description = service['description']?.toString();
        final dynamic rawPrice = service['price'] ?? service['service_price'];
        final double? price = rawPrice is num
            ? rawPrice.toDouble()
            : rawPrice is String
                ? double.tryParse(rawPrice.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.'))
                : null;

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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF00C977).withOpacity(0.1),
                    const Color(0xFF00C977).withOpacity(0.05),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFF00C977).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C977).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.build,
                      color: Color(0xFF00C977),
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
                            color: Color(0xFF00C977),
                          ),
                        ),
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
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
                              color: Color(0xFF00C977),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Ver oficinas próximas',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF00C977),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (price != null) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C977).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'R\$ ${price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Color(0xFF00C977),
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
                              color: Color(0xFF00C977),
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