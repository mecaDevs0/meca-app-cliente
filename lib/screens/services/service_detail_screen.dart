import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/api_service.dart';
import '../../widgets/meca_loading_widget.dart';
import '../booking/booking_screen.dart';

class ServiceDetailScreen extends StatefulWidget {
  final String serviceId;
  final String workshopId;

  const ServiceDetailScreen({
    Key? key,
    required this.serviceId,
    required this.workshopId,
  }) : super(key: key);

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _service;
  List<Map<String, dynamic>> _workshops = [];
  bool _loading = true;
  String _error = '';
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadServiceDetails();
  }

  Future<void> _getCurrentLocation() async {
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

  Future<void> _loadServiceDetails() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      // Carregar detalhes do serviço
      final serviceResult = await _apiService.getServiceDetails(widget.serviceId);
      if (serviceResult['success']) {
        setState(() {
          _service = serviceResult['data'];
        });
      } else {
        setState(() {
          _error = serviceResult['error'] ?? 'Erro ao carregar detalhes do serviço';
          _loading = false;
        });
        return;
      }

      // Carregar oficinas que oferecem este serviço
      if (_currentPosition != null) {
        final workshopsResult = await _apiService.getNearbyWorkshops(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
        
        if (workshopsResult['success']) {
          List<dynamic> allWorkshops = workshopsResult['data']['workshops'] ?? [];
          
          // Todas as oficinas podem oferecer qualquer serviço
          List<Map<String, dynamic>> serviceWorkshops = [];
          
          for (var workshop in allWorkshops) {
            // Calcular distância
            if (workshop['latitude'] != null && workshop['longitude'] != null) {
              double distance = Geolocator.distanceBetween(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                double.parse(workshop['latitude'].toString()),
                double.parse(workshop['longitude'].toString()),
              ) / 1000; // Converter para km
              
              workshop['distance'] = distance;
            } else {
              workshop['distance'] = 0.0;
            }
            
            serviceWorkshops.add(Map<String, dynamic>.from(workshop));
          }
          
          // Ordenar por distância
          serviceWorkshops.sort((a, b) {
            final distanceA = a['distance'] ?? 0.0;
            final distanceB = b['distance'] ?? 0.0;
            return distanceA.compareTo(distanceB);
          });
          
          setState(() {
            _workshops = serviceWorkshops;
            _loading = false;
          });
        } else {
          setState(() {
            _error = 'Erro ao carregar oficinas';
            _loading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Localização não disponível';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erro de conexão: ${e.toString()}';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detalhes do Serviço',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF00C977),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const MecaApiLoadingWidget(message: 'Carregando detalhes...')
          : _error.isNotEmpty
              ? _buildErrorView()
              : _buildServiceDetails(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Erro ao carregar serviço',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadServiceDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C977),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Tentar Novamente',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceDetails() {
    if (_service == null) return const SizedBox();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header do serviço
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF00C977),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone do serviço
                Container(
                  width: 60,
                  height: 60,
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
                const SizedBox(height: 16),
                Text(
                  _service!['name'] ?? 'Serviço',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _service!['description'] ?? 'Descrição não disponível',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_service!['price'] != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'R\$ ${_service!['price'].toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF00C977),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (_service!['duration'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${_service!['duration']} min',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
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
          
          // Conteúdo principal
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lista de oficinas
                _buildWorkshopsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceInfo() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00C977).withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informações do Serviço',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          if (_service!['requirements'] != null) ...[
            const Text(
              'Requisitos:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            ...(_service!['requirements'] as List).map<Widget>((requirement) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF00C977),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        requirement,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
          ],
          
          if (_service!['notes'] != null) ...[
            const Text(
              'Observações:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _service!['notes'],
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkshopsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Oficinas que oferecem este serviço',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00C977).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_workshops.length} oficinas',
                style: const TextStyle(
                  color: Color(0xFF00C977),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (_workshops.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade700 : Colors.grey.shade200),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.build_circle_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Nenhuma oficina encontrada',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Não há oficinas próximas oferecendo este serviço.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _workshops.length,
            itemBuilder: (context, index) {
              return _buildWorkshopCard(_workshops[index]);
            },
          ),
      ],
    );
  }

  Widget _buildWorkshopCard(Map<String, dynamic> workshop) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00C977).withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToWorkshop(workshop),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Logo da oficina
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C977).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.build,
                    color: Color(0xFF00C977),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Informações da oficina
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workshop['name'] ?? 'Oficina',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        workshop['address'] ?? 'Endereço não informado',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${workshop['distance']?.toStringAsFixed(1) ?? '0.0'} km',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${workshop['rating'] ?? 4.5}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Indicador de distância
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C977).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${workshop['distance']?.toStringAsFixed(1) ?? '0.0'} km',
                    style: const TextStyle(
                      color: Color(0xFF00C977),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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


  void _navigateToWorkshop(Map<String, dynamic> workshop) {
    // Navegar direto para agendamento ao selecionar oficina
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(
          serviceId: widget.serviceId,
          workshopId: workshop['id'] ?? '',
          serviceName: _service?['name'] ?? 'Serviço',
          servicePrice: _service?['price']?.toString() ?? '0',
          serviceDuration: _service?['duration']?.toString() ?? '',
          workshopName: workshop['name'] ?? 'Oficina',
        ),
      ),
    );
  }
}