import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../booking/booking_screen.dart';

class WorkshopDetailScreen extends StatefulWidget {
  final String workshopId;

  const WorkshopDetailScreen({
    Key? key,
    required this.workshopId,
  }) : super(key: key);

  @override
  State<WorkshopDetailScreen> createState() => _WorkshopDetailScreenState();
}

class _WorkshopDetailScreenState extends State<WorkshopDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _workshop;
  List<Map<String, dynamic>> _services = [];
  bool _loading = false;
  String _error = '';
  bool _showAllServices = false;

  @override
  void initState() {
    super.initState();
    _loadWorkshopDetails();
  }

  Future<void> _loadWorkshopDetails() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    
    try {
      final result = await _apiService.getWorkshopDetails(widget.workshopId);
      
      if (!mounted) return;
      
      if (result['success']) {
        final rawWorkshop = Map<String, dynamic>.from(
          result['data']?['workshop'] ?? result['data'] ?? {},
        );

        final services = await _loadWorkshopServices();

        if (!mounted) return;
        setState(() {
          _workshop = _normalizeWorkshop(rawWorkshop);
          _services = services;
          _loading = false;
          _error = '';
          _showAllServices = false;
        });
      } else {
        setState(() {
          _error = result['error'] ?? 'Erro ao carregar oficina';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar oficina: $e';
        _loading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadWorkshopServices() async {
    try {
      final servicesResult = await _apiService.getWorkshopServices(widget.workshopId);
      if (servicesResult['success']) {
        final rawData = servicesResult['data'];
        List<Map<String, dynamic>> servicesList = [];
        if (rawData is List) {
          servicesList = rawData
              .whereType<Map>()
              .map((service) => _normalizeService(Map<String, dynamic>.from(service)))
              .toList();
        } else if (rawData is Map) {
          final nested = rawData['services'] ?? rawData['data'];
          if (nested is List) {
            servicesList = nested
                .whereType<Map>()
                .map((service) => _normalizeService(Map<String, dynamic>.from(service)))
                .toList();
          }
        }
        return servicesList;
      }
    } catch (e) {
      print('Erro ao carregar serviços da oficina: $e');
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0A0A0A) : Colors.grey[50],
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C977)))
          : _error.isNotEmpty
              ? _buildErrorView()
              : _buildWorkshopDetails(),
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
              'Erro ao carregar oficina',
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
              onPressed: _loadWorkshopDetails,
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

  Widget _buildWorkshopDetails() {
    if (_workshop == null) return const SizedBox();

    final String workshopName = (_workshop!['name'] ?? 'Oficina').toString();
    final double? rating = _getWorkshopRating();
    final String logoUrl = (_workshop!['logo_url'] ?? _workshop!['logo'] ?? '').toString();

    return CustomScrollView(
      slivers: [
        // Header melhorado com imagem da fachada
        SliverAppBar(
          expandedHeight: 310,
          pinned: true,
          backgroundColor: const Color(0xFF00C977),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF00C977),
                    const Color(0xFF00B369),
                    const Color(0xFF00A85C),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo da oficina melhorado
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: logoUrl.isNotEmpty && logoUrl.startsWith('http')
                            ? Image.network(
                                logoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.build,
                                    color: Color(0xFF00C977),
                                    size: 50,
                                  );
                                },
                              )
                            : const Icon(
                                Icons.build,
                                color: Color(0xFF00C977),
                                size: 50,
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      workshopName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            rating != null && rating > 0
                                ? rating.toStringAsFixed(rating >= 10 ? 0 : 1)
                                : '--',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Conteúdo da oficina melhorado
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informações básicas melhoradas
                _buildInfoCard(),
                const SizedBox(height: 20),
                
                // Mapa e ações rápidas
                _buildLocationMapCard(),
                const SizedBox(height: 20),
                
                // Horários de funcionamento melhorados
                _buildWorkingHoursCard(),
                const SizedBox(height: 20),
                
                // Serviços oferecidos melhorados
                _buildServicesCard(),
                const SizedBox(height: 20),
                
                // Botão de agendamento
                _buildBookingButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C977).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Color(0xFF00C977),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Informações da Oficina',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.location_on, 'Endereço', _workshop!['address'] ?? 'Não informado'),
            _buildInfoRow(Icons.phone, 'Telefone', _workshop!['phone'] ?? 'Não informado'),
            _buildInfoRow(Icons.email, 'Email', _workshop!['email'] ?? 'Não informado'),
                _buildInfoRow(
                  Icons.star,
                  'Avaliação',
                  _formatRatingWithStar(),
                ),
            if (_workshop!['description'] != null && _workshop!['description'].isNotEmpty)
              _buildInfoRow(Icons.description, 'Descrição', _workshop!['description']),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF00C977)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationMapCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final String addressText = (_workshop?['address_text'] ?? _workshop?['address'] ?? 'Endereço não informado').toString();
    final double? latitude = _extractWorkshopLatitude();
    final double? longitude = _extractWorkshopLongitude();
    final bool hasCoords = latitude != null && longitude != null;
    final String? staticMapUrl = hasCoords ? _buildStaticMapUrl(latitude!, longitude!) : null;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00C977).withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C977).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFF00C977),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Localização e Rotas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        addressText,
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GestureDetector(
                onTap: hasCoords ? () => _showMapOptions(latitude!, longitude!) : null,
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey[isDarkMode ? 900 : 200]!,
                        Colors.grey[isDarkMode ? 850 : 100]!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: staticMapUrl != null
                            ? Image.network(
                                staticMapUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return _buildMapPlaceholder(isDarkMode);
                                },
                                errorBuilder: (_, __, ___) => _buildMapPlaceholder(isDarkMode),
                              )
                            : _buildMapPlaceholder(isDarkMode),
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.my_location, size: 16, color: Colors.white.withOpacity(0.9)),
                              const SizedBox(width: 6),
                              Text(
                                hasCoords ? 'Mapa interativo' : 'Localização aproximada',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (hasCoords)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: ElevatedButton.icon(
                            onPressed: () => _showMapOptions(latitude!, longitude!),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF00C977),
                              shadowColor: Colors.black54,
                              elevation: 6,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.directions),
                            label: const Text(
                              'Traçar rota',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hasCoords ? () => _launchGoogleMaps(latitude!, longitude!) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C977),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.map),
                    label: const Text(
                      'Google Maps',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasCoords ? () => _launchWaze(latitude!, longitude!) : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: const Color(0xFF00C977).withOpacity(0.6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.directions_car, color: Color(0xFF00C977)),
                    label: Text(
                      'Abrir no Waze',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00C977).withOpacity(hasCoords ? 1 : 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPlaceholder(bool isDarkMode) {
    return Container(
      height: 220,
      color: isDarkMode ? const Color(0xFF101010) : const Color(0xFFE8F5EE),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore,
              size: 42,
              color: isDarkMode ? Colors.white54 : const Color(0xFF00C977),
            ),
            const SizedBox(height: 8),
            Text(
              'Mapa indisponível',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double? _extractWorkshopLatitude() {
    final addressDetails = _workshop?['address_details'] as Map<String, dynamic>?;
    final sources = [
      _workshop?['latitude'],
      _workshop?['lat'],
      addressDetails?['latitude'],
      addressDetails?['lat'],
    ];
    for (final source in sources) {
      final parsed = _parseDouble(source);
      if (parsed != null) return parsed;
    }
    return null;
  }

  double? _extractWorkshopLongitude() {
    final addressDetails = _workshop?['address_details'] as Map<String, dynamic>?;
    final sources = [
      _workshop?['longitude'],
      _workshop?['lng'],
      addressDetails?['longitude'],
      addressDetails?['lng'],
    ];
    for (final source in sources) {
      final parsed = _parseDouble(source);
      if (parsed != null) return parsed;
    }
    return null;
  }

  String? _buildStaticMapUrl(double lat, double lng) {
    final key = AppConfig.googleMapsApiKeyBrowser;
    if (key.isEmpty) return null;
    final encodedMarker = Uri.encodeComponent('color:0x00C977|label:M|$lat,$lng');
    return 'https://maps.googleapis.com/maps/api/staticmap?center=$lat,$lng&zoom=15&size=640x360&scale=2'
        '&maptype=roadmap&markers=$encodedMarker&key=$key';
  }

  void _showMapOptions(double lat, double lng) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF101010) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.map, color: Color(0xFF00C977)),
                  title: const Text('Abrir no Google Maps'),
                  subtitle: const Text('Rota completa pelo Google Maps'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _launchGoogleMaps(lat, lng);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.directions_car, color: Color(0xFF00C977)),
                  title: const Text('Abrir no Waze'),
                  subtitle: const Text('Rota em tempo real pelo Waze'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _launchWaze(lat, lng);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchGoogleMaps(double lat, double lng) async {
    final googleUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    await _launchExternalUrl(googleUrl);
  }

  Future<void> _launchWaze(double lat, double lng) async {
    final wazeUrl = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
    await _launchExternalUrl(wazeUrl);
  }

  Future<void> _launchExternalUrl(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o app de mapas.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildWorkingHoursCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final workingHours = _workshop!['working_hours'] ?? {};
    
    // Horários padrão se não houver dados
    final defaultHours = {
      'monday': {'start': '08:00', 'end': '18:00'},
      'tuesday': {'start': '08:00', 'end': '18:00'},
      'wednesday': {'start': '08:00', 'end': '18:00'},
      'thursday': {'start': '08:00', 'end': '18:00'},
      'friday': {'start': '08:00', 'end': '18:00'},
      'saturday': {'start': '08:00', 'end': '12:00'},
      'sunday': null,
    };
    
    final hours = workingHours.isNotEmpty ? workingHours : defaultHours;
    
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C977).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: Color(0xFF00C977),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Horários de Funcionamento',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...hours.entries.map((entry) {
              final day = entry.key;
              final dayHours = entry.value;
              final isOpen = dayHours != null;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOpen 
                      ? const Color(0xFF00C977).withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOpen 
                        ? const Color(0xFF00C977).withOpacity(0.3)
                        : Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isOpen ? Icons.check_circle : Icons.cancel,
                          color: isOpen ? const Color(0xFF00C977) : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getDayName(day),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      isOpen ? '${dayHours['start']} - ${dayHours['end']}' : 'Fechado',
                      style: TextStyle(
                        color: isOpen ? const Color(0xFF00C977) : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final services = _services;
    
    // Serviços padrão se não houver dados
    final defaultServices = [
      {
        'id': '1',
        'name': 'Troca de Óleo',
        'description': 'Troca completa de óleo do motor',
        'price': 80.00,
        'duration': 30,
      },
      {
        'id': '2', 
        'name': 'Alinhamento e Balanceamento',
        'description': 'Alinhamento e balanceamento das rodas',
        'price': 120.00,
        'duration': 45,
      },
      {
        'id': '3',
        'name': 'Revisão Geral',
        'description': 'Revisão completa do veículo',
        'price': 200.00,
        'duration': 120,
      },
    ];
    
    final servicesList = services.isNotEmpty ? services : defaultServices;
    final bool hasMoreThanThree = servicesList.length > 3;
    final List<Map<String, dynamic>> visibleServices = _showAllServices
        ? servicesList
        : servicesList.take(3).toList();
    
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C977).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.build,
                    color: Color(0xFF00C977),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Serviços Oferecidos',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...visibleServices.map<Widget>((service) {
              final String serviceId = (service['id'] ?? service['service_id'] ?? '').toString();
              final String serviceName = (service['name'] ?? 'Serviço').toString();
              final String? description = service['description']?.toString();
              final dynamic rawPrice = service['price'] ?? service['service_price'];
              final double? price = _parseDouble(rawPrice);
              final dynamic rawDuration = service['duration'] ?? service['duration_minutes'];
              final int? duration = rawDuration is num
                  ? rawDuration.toInt()
                  : rawDuration is String
                      ? int.tryParse(rawDuration)
                      : null;
              final String workshopName = (_workshop?['name'] ?? 'Oficina').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00C977).withOpacity(0.2),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      // Navegar direto para agendamento ao selecionar serviço
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookingScreen(
                            serviceId: serviceId,
                            workshopId: widget.workshopId,
                            serviceName: serviceName,
                            servicePrice: price != null && price > 0 ? price.toString() : '',
                            serviceDuration: duration?.toString() ?? rawDuration?.toString() ?? '',
                            workshopName: workshopName,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
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
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  serviceName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  description ?? 'Descrição do serviço',
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (price != null && price > 0)
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
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    if (duration != null && duration > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '$duration min',
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Color(0xFF00C977),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            if (hasMoreThanThree)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton(
                  onPressed: () {
                    setState(() => _showAllServices = !_showAllServices);
                  },
                  child: Text(
                    _showAllServices ? 'Ver menos' : 'Ver mais',
                    style: const TextStyle(
                      color: Color(0xFF00C977),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBookingButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C977), Color(0xFF00B369)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C977).withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Navegar para tela de agendamento com seleção de serviço
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookingScreen(
                  serviceId: '', // Vazio para permitir seleção
                  workshopId: widget.workshopId,
                  serviceName: 'Selecione um serviço',
                  servicePrice: '0',
                  serviceDuration: '',
                  workshopName: _workshop?['name'] ?? 'Oficina',
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Agendar Serviço',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDayName(String day) {
    const days = {
      'monday': 'Segunda-feira',
      'tuesday': 'Terça-feira',
      'wednesday': 'Quarta-feira',
      'thursday': 'Quinta-feira',
      'friday': 'Sexta-feira',
      'saturday': 'Sábado',
      'sunday': 'Domingo',
    };
    return days[day] ?? day;
  }

  Map<String, dynamic> _normalizeWorkshop(Map<String, dynamic> workshop) {
    final normalized = Map<String, dynamic>.from(workshop);
    final addressDetails = _extractAddressDetails(normalized['address']);
    normalized['address_details'] = addressDetails;
    normalized['address'] = _formatAddress(addressDetails ?? normalized['address']);
    normalized['address_text'] = normalized['address'];
    normalized['rating'] = _parseDouble(normalized['rating']);
    normalized['logo_url'] = normalized['logo_url'] ?? normalized['logo'];
    return normalized;
  }

  Map<String, dynamic> _normalizeService(Map<String, dynamic> service) {
    final normalized = Map<String, dynamic>.from(service);
    normalized['price'] = _parseDouble(normalized['price'] ?? normalized['service_price']);
    final duration = normalized['duration'] ?? normalized['duration_minutes'];
    if (duration is num) {
      normalized['duration'] = duration.toInt();
    } else if (duration is String) {
      normalized['duration'] = int.tryParse(duration);
    }
    return normalized;
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
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final lower = trimmed.toLowerCase();
      if (lower == 'n/a' || lower == 'na' || lower == 'null' || lower == '--') {
        return null;
      }
      return double.tryParse(trimmed.replaceAll(',', '.'));
    }
    return null;
  }

  double? _getWorkshopRating() {
    return _parseDouble(_workshop?['rating']) ??
        _parseDouble(_workshop?['average_rating']) ??
        _parseDouble(_workshop?['score']);
  }

  String _formatRatingWithStar() {
    final rating = _getWorkshopRating();
    if (rating == null || rating <= 0) {
      return 'Sem avaliações';
    }
    final formatted = rating.toStringAsFixed(rating >= 10 ? 0 : 1);
    return '$formatted ⭐';
  }

  String _formatAddress(dynamic address) {
    if (address == null) return 'Não informado';
    if (address is String) {
      if (address.isEmpty) return 'Não informado';
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
        if (rawValues.isEmpty) return 'Não informado';
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
}

















