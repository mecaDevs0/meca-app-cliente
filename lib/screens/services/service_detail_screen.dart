import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;

import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../utils/price_utils.dart';
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
  final LocationService _locationService = LocationService.instance;
  Map<String, dynamic>? _service;
  List<Map<String, dynamic>> _workshops = [];
  bool _loading = true;
  String _error = '';
  Position? _currentPosition;

  // Helper para converter rating de forma segura (String ou num para double)
  double? _parseRating(dynamic rating) {
    if (rating == null) return null;
    if (rating is num) return rating.toDouble();
    if (rating is String) {
      final parsed = double.tryParse(rating);
      return parsed;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _resolveLocation();
    await _loadServiceDetails();
  }

  Future<void> _resolveLocation() async {
    try {
      final status = await _locationService.ensurePermissions();
      if (!status.canRequestPosition) return;

      final position = await _locationService.getCurrentPosition(forceFresh: true);
      if (position != null && mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      // Silenciar erro de localização
    }
  }

  Future<void> _loadServiceDetails() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      // Carregar detalhes do serviço
      final serviceResult = await _apiService.getServiceDetails(widget.serviceId);
      if (!mounted) return;
      if (serviceResult['success']) {
        setState(() {
          _service = Map<String, dynamic>.from(serviceResult['data'] ?? {});
        });
      } else {
        setState(() {
          _error = serviceResult['error'] ?? 'Erro ao carregar detalhes do serviço';
          _loading = false;
        });
        return;
      }

      // Carregar oficinas que oferecem este serviço (mesmo sem localização)
      final workshopsResult = await _apiService.getWorkshopsByService(
        widget.serviceId,
        lat: _currentPosition?.latitude,
        lng: _currentPosition?.longitude,
        radiusKm: _currentPosition != null ? 50.0 : null,
      );

      if (!mounted) return;
      if (workshopsResult['success']) {
        final list = (workshopsResult['data'] as List?) ?? [];
        setState(() {
          _workshops = list.map<Map<String, dynamic>>((e) {
            final workshop = Map<String, dynamic>.from(e as Map);
            // Normalizar rating para garantir que seja double (não String)
            workshop['rating'] = _parseRating(workshop['rating']);
            return workshop;
          }).toList();
        });
      } else {
        // Não definir erro se falhar ao carregar oficinas, apenas mostrar lista vazia
        // Silenciar aviso
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar detalhes do serviço: ${e.toString()}';
        _loading = false;
      });
      // Silenciar erro
    } finally {
      if (!mounted) return;
      if (!_error.isNotEmpty) {
        setState(() {
          _loading = false;
        });
      }
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _service!['name'] ?? 'Serviço',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _service!['description'] ?? 'Descrição não disponível',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 16),
                Builder(builder: (context) {
                  final priceLabel = PriceUtils.formatCurrency(_service?['price']);

                  double? durationMinutes;
                  final durationRaw = _service?['duration'];
                  if (durationRaw is num) {
                    durationMinutes = durationRaw.toDouble();
                  } else if (durationRaw is String) {
                    durationMinutes = double.tryParse(durationRaw);
                  }

                  return Row(
                    children: [
                      if (priceLabel != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            priceLabel,
                            style: const TextStyle(
                              color: Color(0xFF00C977),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (durationMinutes != null && durationMinutes > 0)
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
                                '${durationMinutes.toStringAsFixed(durationMinutes % 1 == 0 ? 0 : 1)} min',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                }),
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


  Widget _buildWorkshopsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Oficinas que oferecem este serviço',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
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
                  child: (workshop['logo_url'] != null && 
                          workshop['logo_url'].toString().isNotEmpty && 
                          workshop['logo_url'].toString().startsWith('http'))
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            workshop['logo_url'].toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.build,
                                color: Color(0xFF00C977),
                                size: 24,
                              );
                            },
                          ),
                        )
                      : const Icon(
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
                        _formatWorkshopAddress(workshop['address_text'] ?? workshop['address']),
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
                          Builder(
                            builder: (context) {
                              final ratingValue = _parseRating(workshop['rating']);
                              return Text(
                                (ratingValue != null && ratingValue > 0 && ratingValue <= 5)
                                    ? ratingValue.toStringAsFixed(1)
                                    : '-',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              );
                            },
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

  String _formatWorkshopAddress(dynamic rawAddress) {
    if (rawAddress == null) return 'Endereço não informado';

    if (rawAddress is String) {
      final trimmed = rawAddress.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
        return 'Endereço não informado';
      }

      final looksLikeJson = (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'));
      if (looksLikeJson) {
        try {
          final decoded = json.decode(trimmed);
          return _formatWorkshopAddress(decoded);
        } catch (_) {
          return _sanitizeAddressString(trimmed);
        }
      }

      return _sanitizeAddressString(trimmed);
    }

    if (rawAddress is Map) {
      final street = rawAddress['street'] ?? rawAddress['logradouro'] ?? rawAddress['addressLine1'];
      final number = rawAddress['number'] ?? rawAddress['numero'];
      final neighborhood = rawAddress['neighborhood'] ?? rawAddress['bairro'];
      final city = rawAddress['city'] ?? rawAddress['cidade'];
      final state = rawAddress['state'] ?? rawAddress['uf'];

      final cityState = [
        if (city != null && city.toString().trim().isNotEmpty) city.toString().trim(),
        if (state != null && state.toString().trim().isNotEmpty) state.toString().trim(),
      ].join(city != null && state != null ? ' - ' : '');

      final parts = <String>[
        if (street != null && street.toString().trim().isNotEmpty) street.toString().trim(),
        if (number != null && number.toString().trim().isNotEmpty) number.toString().trim(),
        if (neighborhood != null && neighborhood.toString().trim().isNotEmpty) neighborhood.toString().trim(),
        if (cityState.trim().isNotEmpty) cityState.trim(),
      ];

      if (parts.isEmpty) return 'Endereço não informado';
      return parts.join(', ');
    }

    return rawAddress.toString();
  }

  String _sanitizeAddressString(String input) {
    final sanitized = input
        .replaceAll(RegExp(r'[\{\}\[\]\\"]'), '')
        .replaceAll(RegExp(r'\\n'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (sanitized.isEmpty || sanitized.toLowerCase() == 'null') {
      return 'Endereço não informado';
    }
    return sanitized;
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
          workshopLogoUrl: workshop['logo_url']?.toString(),
        ),
      ),
    );
  }
}











