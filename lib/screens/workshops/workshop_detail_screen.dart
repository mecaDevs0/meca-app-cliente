import 'dart:convert';

import 'package:flutter/material.dart';
import '../../widgets/meca_toast.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../utils/formatters.dart';
import '../booking/booking_screen.dart';
import '../pre_compra/pre_compra_booking_screen.dart';


class WorkshopDetailScreen extends StatefulWidget {
  final String workshopId;
  /// Distância em km (opcional). Se > 50, exibe aviso de oficina longe.
  final double? distanceKm;

  const WorkshopDetailScreen({
    Key? key,
    required this.workshopId,
    this.distanceKm,
  }) : super(key: key);

  @override
  State<WorkshopDetailScreen> createState() => _WorkshopDetailScreenState();
}

class _WorkshopDetailScreenState extends State<WorkshopDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _workshop;
  List<Map<String, dynamic>> _services = [];
  List<dynamic> _galleryPhotos = [];
  bool _loading = false;
  String _error = '';
  bool _showAllServices = false;
  bool _isFavorite = false;

  /// URL do logo sempre via proxy da API (evita 403 do S3). Nunca retorna URL S3 direta.
  String? get _safeWorkshopLogoUrl {
    final raw = _workshop?['logo_url']?.toString()?.trim();
    if (raw != null && raw.isNotEmpty && raw.startsWith('http')) return raw;
    return null;
  }

  @override
  void initState() {
    super.initState();
    debugPrint('📍 [WorkshopDetail] initState - workshopId: ${widget.workshopId}');
    debugPrint('📍 [WorkshopDetail] distanceKm recebido: ${widget.distanceKm}');
    debugPrint('📍 [WorkshopDetail] distanceKm > 50? ${widget.distanceKm != null && widget.distanceKm! > 50}');
    _loadWorkshopDetails();
    if (widget.distanceKm != null && widget.distanceKm! > 50) {
      debugPrint('⚠️ [WorkshopDetail] MOSTRANDO POPUP DE OFICINA DISTANTE!');
      WidgetsBinding.instance.addPostFrameCallback((_) => _showFarWorkshopDialog());
    } else {
      debugPrint('✅ [WorkshopDetail] Oficina próxima ou sem distância, sem popup');
    }
  }

  void _showFarWorkshopDialog() {
    if (!mounted) return;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 28),
            const SizedBox(width: 10),
            const Expanded(child: Text('Oficina Distante', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta oficina está a aproximadamente ${widget.distanceKm!.toStringAsFixed(0)} km de você.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[800], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Isso pode impactar em custos de deslocamento e tempo de atendimento.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tem certeza que deseja continuar?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Voltar', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00C977),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Sim, continuar'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed != true && mounted) {
        Navigator.of(context).pop(); // Volta para a tela anterior
      }
    });
  }

  Future<void> _toggleFavorite() async {
    final workshopId = int.tryParse(widget.workshopId);
    if (workshopId == null) return;

    // Optimistic update
    setState(() {
      _isFavorite = !_isFavorite;
    });

    try {
      await _apiService.toggleWorkshopFavorite(workshopId);
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isFavorite = !_isFavorite;
        });
      }
    }
  }

  void _shareWorkshop() {
    if (_workshop == null) return;
    final name = (_workshop!['name'] ?? 'Oficina').toString();
    final city = (_workshop!['city'] ?? '').toString();
    final ratingVal = _getWorkshopRating();
    final ratingText = ratingVal != null ? ' - Nota: ${ratingVal.toStringAsFixed(1)}' : '';
    final cityText = city.isNotEmpty ? ' em $city' : '';
    final text = 'Confira a oficina $name$cityText$ratingText no MECA! Baixe o app: https://mecabr.com';
    Share.share(text);
  }

  Future<void> _loadWorkshopDetails() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final futureDetails = _apiService.getWorkshopDetails(widget.workshopId);
      final futureServices = _apiService.getWorkshopServices(widget.workshopId);
      final results = await Future.wait([futureDetails, futureServices]);

      if (!mounted) return;
      final result = results[0] as Map<String, dynamic>;
      final servicesResult = results[1] as Map<String, dynamic>;

      if (result['success']) {
        final rawWorkshop = Map<String, dynamic>.from(result['data'] ?? {});
        // Schedule vem direto da API EC2 (dados reais: schedule ou working_hours do RDS)
        final normalizedWorkshop = _normalizeWorkshop(rawWorkshop);
        List<Map<String, dynamic>> servicesList = [];
        if (servicesResult['success']) {
          final rawData = servicesResult['data'];
          if (rawData is List) {
            servicesList = rawData
                .whereType<Map>()
                .map((s) => _normalizeService(Map<String, dynamic>.from(s)))
                .toList();
          } else if (rawData is Map) {
            final nested = rawData['services'] ?? rawData['data'];
            if (nested is List) {
              servicesList = nested
                  .whereType<Map>()
                  .map((s) => _normalizeService(Map<String, dynamic>.from(s)))
                  .toList();
            }
          }
        }
        if (!mounted) return;
        setState(() {
          _workshop = normalizedWorkshop;
          _services = servicesList;
          _loading = false;
          _error = '';
          _showAllServices = false;
          _isFavorite = normalizedWorkshop['is_favorite'] == true || normalizedWorkshop['is_favorite'] == 1;
        });

        _apiService.getWorkshopGallery(widget.workshopId).then((photos) {
          if (mounted) setState(() => _galleryPhotos = photos);
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
      bottomNavigationBar: _loading || _error.isNotEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 60,
                  child: _buildBookingButton(),
                ),
              ),
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

  // Widget do Header Minimalista com Gradiente Vertical
  Widget _buildDeepTechHeader(String workshopName, double? rating, String? logoUrl) {
    return Container(
      // BACKGROUND: Gradiente vertical suave (fusão perfeita)
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF00B369), // Verde Secundário (Topo)
            const Color(0xFF121E29), // Mesma cor de fundo do app (Base - fusão invisível)
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // LOGO: Hero centralizado
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E1E1E), // Escuro, NÃO BRANCO
                border: Border.all(
                  color: const Color(0xFF00C977), // Neon
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: logoUrl != null && 
                       logoUrl.isNotEmpty && 
                       logoUrl != '' &&
                       logoUrl.startsWith('http')
                  ? Image.network(
                      logoUrl,
                      fit: BoxFit.cover,
                      width: 100,
                      height: 100,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFF1E1E1E),
                          child: const Icon(
                            Icons.build,
                            color: Color(0xFF00C977),
                            size: 50,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: const Color(0xFF1E1E1E),
                      child: const Icon(
                        Icons.build,
                        color: Color(0xFF00C977),
                        size: 50,
                      ),
                    ),
              ),
            ),
            const SizedBox(height: 16),
            // NOME: Texto Branco, Bold, UPPERCASE, Premium
            Text(
              workshopName.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0, // Espaçamento entre letras para visual Premium
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // BADGE: Fundo translúcido escuro, centralizado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    (rating != null && rating > 0 && rating <= 5)
                        ? rating.toStringAsFixed(1)
                        : '-',
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
    );
  }

  Widget _buildWorkshopDetails() {
    if (_workshop == null) return const SizedBox();

    final String workshopName = (_workshop!['name'] ?? 'Oficina').toString();
    final double? rating = _getWorkshopRating();
    
    final raw = _workshop!['logo_url']?.toString()?.trim();
    final String? logoUrl = (raw != null && raw.isNotEmpty && raw.startsWith('http')) ? raw : null;

    return CustomScrollView(
      slivers: [
        // Header Minimalista com Gradiente Vertical
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: const Color(0xFF121E29), // Mesma cor do gradiente final
          actions: [
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? const Color(0xFF00C977) : Colors.white,
              ),
              onPressed: _toggleFavorite,
              tooltip: _isFavorite ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
            ),
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: _shareWorkshop,
              tooltip: 'Compartilhar oficina',
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _buildDeepTechHeader(workshopName, rating, logoUrl),
          ),
        ),
        
        // Conteúdo da oficina (transição natural sem sobreposição)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informações básicas (transição natural)
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

                // Portfólio de fotos da oficina
                if (_galleryPhotos.isNotEmpty) _buildPortfolioSection(),
                const SizedBox(height: 80), // Espaço para o botão fixo
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
            _buildInfoRow(Icons.location_on, 'Endereço', _workshop!['address']?.toString() ?? 'Não informado'),
            _buildInfoRow(
              Icons.phone,
              'Telefone',
              _workshop!['phone'] != null && _workshop!['phone'].toString().trim().isNotEmpty
                  ? Formatters.formatPhone(_workshop!['phone']?.toString())
                  : 'Disponível após confirmação do agendamento',
            ),
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
    final double? latitudeRaw = _extractWorkshopLatitude();
    final double? longitudeRaw = _extractWorkshopLongitude();
    final bool hasCoords = latitudeRaw != null && longitudeRaw != null;
    
    // Usar variáveis não-nullable quando temos coordenadas
    final double? latitude = hasCoords ? latitudeRaw : null;
    final double? longitude = hasCoords ? longitudeRaw : null;

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
                onTap: hasCoords && latitude != null && longitude != null 
                    ? () => _showMapOptions(latitude, longitude) 
                    : null,
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
                        child: hasCoords && latitude != null && longitude != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(latitude, longitude),
                                    zoom: 15.0,
                                  ),
                                  markers: {
                                    Marker(
                                      markerId: const MarkerId('workshopLocation'),
                                      position: LatLng(latitude, longitude),
                                      infoWindow: InfoWindow(
                                        title: _workshop?['name'] ?? 'Oficina',
                                      ),
                                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                                    ),
                                  },
                                  mapType: MapType.normal,
                                  liteModeEnabled: true,
                                  myLocationEnabled: false,
                                  myLocationButtonEnabled: false,
                                  zoomControlsEnabled: false,
                                  mapToolbarEnabled: false,
                                  scrollGesturesEnabled: false,
                                  tiltGesturesEnabled: false,
                                  rotateGesturesEnabled: false,
                                  zoomGesturesEnabled: false,
                                  onMapCreated: (GoogleMapController controller) {
                                  },
                                ),
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
                    onPressed: hasCoords && latitude != null && longitude != null 
                        ? () => _launchGoogleMaps(latitude, longitude) 
                        : null,
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
                    onPressed: hasCoords && latitude != null && longitude != null 
                        ? () => _launchWaze(latitude, longitude) 
                        : null,
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
    if (_workshop == null) return null;
    
    // Tentar múltiplas fontes de dados
    final addressDetails = _workshop?['address_details'] as Map<String, dynamic>?;
    final address = _workshop?['address'];
    final addressMap = address is Map ? Map<String, dynamic>.from(address) : null;
    
    final sources = [
      _workshop?['latitude'],
      _workshop?['lat'],
      addressDetails?['latitude'],
      addressDetails?['lat'],
      addressMap?['latitude'],
      addressMap?['lat'],
      // Tentar parsear se vier como string JSON
      _tryParseFromString(_workshop?['latitude']),
      _tryParseFromString(_workshop?['lat']),
    ];
    
    for (final source in sources) {
      if (source == null) continue;
      final parsed = _parseDouble(source);
      if (parsed != null && parsed != 0.0) {
        // Validar se é uma latitude válida (-90 a 90)
        if (parsed >= -90 && parsed <= 90) {
          return parsed;
        }
      }
    }
    return null;
  }

  double? _extractWorkshopLongitude() {
    if (_workshop == null) return null;
    
    // Tentar múltiplas fontes de dados
    final addressDetails = _workshop?['address_details'] as Map<String, dynamic>?;
    final address = _workshop?['address'];
    final addressMap = address is Map ? Map<String, dynamic>.from(address) : null;
    
    final sources = [
      _workshop?['longitude'],
      _workshop?['lng'],
      _workshop?['lon'],
      addressDetails?['longitude'],
      addressDetails?['lng'],
      addressDetails?['lon'],
      addressMap?['longitude'],
      addressMap?['lng'],
      addressMap?['lon'],
      // Tentar parsear se vier como string JSON
      _tryParseFromString(_workshop?['longitude']),
      _tryParseFromString(_workshop?['lng']),
    ];
    
    for (final source in sources) {
      if (source == null) continue;
      final parsed = _parseDouble(source);
      if (parsed != null && parsed != 0.0) {
        // Validar se é uma longitude válida (-180 a 180)
        if (parsed >= -180 && parsed <= 180) {
          return parsed;
        }
      }
    }
    return null;
  }

  // Helper para tentar parsear coordenadas que podem vir como string
  dynamic _tryParseFromString(dynamic value) {
    if (value is String) {
      // Tentar parsear como double direto
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null) return parsed;
      
      // Tentar extrair de string JSON
      try {
        final decoded = jsonDecode(value);
        if (decoded is num) return decoded;
      } catch (_) {
        // Ignorar erro de parse JSON
      }
    }
    return value;
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

  String _buildFullAddress() {
    final address = (_workshop?['address_text'] ?? _workshop?['address'] ?? '').toString().trim();
    final city = (_workshop?['city'] ?? '').toString().trim();
    final state = (_workshop?['state'] ?? '').toString().trim();
    final parts = [address, city, state].where((s) => s.isNotEmpty).toList();
    return parts.join(', ');
  }

  Future<void> _launchGoogleMaps(double lat, double lng) async {
    final fullAddress = _buildFullAddress();
    final Uri googleUrl;
    if (fullAddress.isNotEmpty) {
      googleUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(fullAddress)}&travelmode=driving');
    } else {
      googleUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    }
    await _launchExternalUrl(googleUrl);
  }

  Future<void> _launchWaze(double lat, double lng) async {
    final fullAddress = _buildFullAddress();
    final Uri wazeUrl;
    if (fullAddress.isNotEmpty) {
      wazeUrl = Uri.parse('https://waze.com/ul?q=${Uri.encodeComponent(fullAddress)}&navigate=yes');
    } else {
      wazeUrl = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
    }
    await _launchExternalUrl(wazeUrl);
  }

  Future<void> _launchExternalUrl(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      MecaToast.show(context, 'Não foi possível abrir o app de mapas.');
    }
  }

  Widget _buildWorkingHoursCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // CRITICAL: Horários REAIS da API EC2 (schedule ou working_hours do RDS - dados reais, sem mock)
    // A API retorna schedule: { monday: { is_open: true, start_time: '08:00', end_time: '18:00' }, ... }
    final scheduleRaw = _workshop!['schedule'] ?? _workshop!['working_hours'];
    Map<String, dynamic> scheduleData = {};
    
    if (scheduleRaw != null) {
      if (scheduleRaw is String) {
        try {
          final decoded = jsonDecode(scheduleRaw);
          scheduleData = decoded is Map ? Map<String, dynamic>.from(decoded) : {};
        } catch (_) {
          scheduleData = {};
        }
      } else if (scheduleRaw is Map) {
        scheduleData = Map<String, dynamic>.from(scheduleRaw);
      }
    }
    
    // Fallback: is_open_now e today_hours da API (America/Sao_Paulo)
    final isOpenNow = _workshop!['is_open_now'] == true;
    final todayHours = _workshop!['today_hours']?.toString();
    
    // Mapeamento: inglês -> português (setup pode salvar com chaves em português)
    const enToPt = {
      'monday': 'segunda', 'tuesday': 'terca', 'wednesday': 'quarta',
      'thursday': 'quinta', 'friday': 'sexta', 'saturday': 'sabado', 'sunday': 'domingo',
    };
    // Converter formato da API (is_open/enabled, start_time/start/inicio, end_time/end/fim) para formato do app
    final hours = <String, Map<String, String>?>{};
    final dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    bool hasAnySchedule = false;

    for (final dayKey in dayKeys) {
      final dayData = scheduleData[dayKey] ?? scheduleData[enToPt[dayKey] ?? ''];
      if (dayData != null && dayData is Map) {
        final isOpen = dayData['is_open'] == true || dayData['enabled'] == true || dayData['ativo'] == 'true';
        final start = dayData['start_time'] ?? dayData['start'] ?? dayData['inicio'];
        final end = dayData['end_time'] ?? dayData['end'] ?? dayData['fim'];
        if (isOpen && start != null && start.toString().trim().isNotEmpty && end != null && end.toString().trim().isNotEmpty) {
          hours[dayKey] = {
            'start': start.toString().trim(),
            'end': end.toString().trim(),
          };
          hasAnySchedule = true;
        } else {
          hours[dayKey] = null;
        }
      } else {
        hours[dayKey] = null;
      }
    }
    
    // Quando não há schedule cadastrado: mostrar "Horário não informado" ou fallback today_hours
    final noSchedule = !hasAnySchedule;
    final closedLabel = noSchedule ? 'Não informado' : 'Fechado';

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
                  'Horários',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (todayHours != null && todayHours.isNotEmpty && todayHours != 'Fechado') ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOpenNow
                          ? const Color(0xFF00C977).withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isOpenNow ? 'Aberto agora' : 'Hoje: $todayHours',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isOpenNow ? const Color(0xFF00C977) : Colors.orange[800],
                      ),
                    ),
                  ),
                ],
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
                      : (noSchedule ? Colors.grey.withOpacity(0.1) : Colors.red.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOpen 
                        ? const Color(0xFF00C977).withOpacity(0.3)
                        : (noSchedule ? Colors.grey.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isOpen ? Icons.check_circle : (noSchedule ? Icons.help_outline : Icons.cancel),
                          color: isOpen ? const Color(0xFF00C977) : (noSchedule ? Colors.grey : Colors.red),
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
                      isOpen ? '${dayHours!['start']} - ${dayHours['end']}' : closedLabel,
                      style: TextStyle(
                        color: isOpen ? const Color(0xFF00C977) : (noSchedule ? Colors.grey : Colors.red),
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
    
    // Dividir serviços em Gerais e Especializados
    final generalServicesNames = ['Mecânica Geral', 'Mecanica Geral', 'Estética Automotiva', 'Estetica Automotiva', 'Funilaria e Pintura', 'Funilaria e Pintura'];
    final generalServices = services.where((service) {
      final name = (service['name'] ?? '').toString();
      return generalServicesNames.any((generalName) => 
        name.toLowerCase().contains(generalName.toLowerCase()) ||
        generalName.toLowerCase().contains(name.toLowerCase())
      );
    }).toList();
    
    final specializedServices = services.where((service) {
      final name = (service['name'] ?? '').toString();
      return !generalServicesNames.any((generalName) => 
        name.toLowerCase().contains(generalName.toLowerCase()) ||
        generalName.toLowerCase().contains(name.toLowerCase())
      );
    }).toList()..sort((a, b) {
      final nameA = (a['name'] ?? '').toString().toLowerCase();
      final nameB = (b['name'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });
    
    final allServices = [...generalServices, ...specializedServices];
    final bool hasMoreThanThree = allServices.length > 3;
    final List<Map<String, dynamic>> visibleServices = _showAllServices
        ? allServices
        : allServices.take(3).toList();
    
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
            // Mostrar seções se mostrar todos os serviços
            if (_showAllServices && generalServices.isNotEmpty && specializedServices.isNotEmpty) ...[
              _buildServiceSectionHeader('Serviços Gerais', isDarkMode),
              const SizedBox(height: 12),
              ...generalServices.map<Widget>((service) => _buildServiceItem(service, isDarkMode)),
              const SizedBox(height: 20),
              _buildServiceSectionHeader('Serviços Especializados', isDarkMode),
              const SizedBox(height: 12),
              ...specializedServices.map<Widget>((service) => _buildServiceItem(service, isDarkMode)),
            ] else ...[
              ...visibleServices.map<Widget>((service) => _buildServiceItem(service, isDarkMode)),
            ],
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

  Widget _buildServiceSectionHeader(String title, bool isDarkMode) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.white : const Color(0xFF252940),
      ),
    );
  }

  Widget _buildServiceItem(Map<String, dynamic> service, bool isDarkMode) {
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
            final serviceNameLower = serviceName.toLowerCase();
            final isPreCompra = serviceNameLower.contains('pré-compra') ||
                serviceNameLower.contains('pre-compra') ||
                serviceId == 'srv_pre_compra_veicular';

            if (isPreCompra) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PreCompraBookingScreen(
                    workshopId: widget.workshopId,
                    workshopName: workshopName,
                  ),
                ),
              );
              return;
            }

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
                  workshopLogoUrl: _safeWorkshopLogoUrl,
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
  }
  
  
  Widget _buildPortfolioSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C977).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library, color: Color(0xFF00C977), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Portfólio',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                '${_galleryPhotos.length} foto${_galleryPhotos.length != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _galleryPhotos.length,
              itemBuilder: (context, index) {
                final photo = _galleryPhotos[index];
                final imageUrl = photo['image_url']?.toString() ?? '';
                final caption = photo['caption']?.toString();
                return GestureDetector(
                  onTap: () => _showPhotoViewer(index),
                  child: Container(
                    width: 160,
                    margin: EdgeInsets.only(right: index < _galleryPhotos.length - 1 ? 12 : 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[200],
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Color(0xFF00C977)),
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (ctx, err, stack) => Container(
                              color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[200],
                              child: Icon(Icons.broken_image, color: Colors.grey[400], size: 32),
                            ),
                          ),
                          if (caption != null && caption.isNotEmpty)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.7),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Text(
                                  caption,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoViewer(int initialIndex) {
    showDialog(
      context: context,
      builder: (ctx) {
        int currentIndex = initialIndex;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final photo = _galleryPhotos[currentIndex];
            final imageUrl = photo['image_url']?.toString() ?? '';
            final caption = photo['caption']?.toString();
            return Dialog(
              backgroundColor: Colors.black,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity == null) return;
                      if (details.primaryVelocity! < -100 && currentIndex < _galleryPhotos.length - 1) {
                        setDialogState(() => currentIndex++);
                      } else if (details.primaryVelocity! > 100 && currentIndex > 0) {
                        setDialogState(() => currentIndex--);
                      }
                    },
                    child: InteractiveViewer(
                      child: Center(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, stack) => const Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(ctx).padding.top + 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  if (caption != null && caption.isNotEmpty)
                    Positioned(
                      bottom: MediaQuery.of(ctx).padding.bottom + 16,
                      left: 16,
                      right: 16,
                      child: Text(
                        caption,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  Positioned(
                    bottom: MediaQuery.of(ctx).padding.bottom + 40,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_galleryPhotos.length, (i) {
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == currentIndex
                                ? const Color(0xFF00C977)
                                : Colors.white38,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBookingButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C977), Color(0xFF00B369)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C977).withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 1,
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
                  workshopLogoUrl: _safeWorkshopLogoUrl,
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
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'AGENDAR SERVIÇO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
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
    // Preservar schedule, working_hours, is_open_now, today_hours da API (dados reais RDS, sem mock)
    if (workshop['schedule'] != null) normalized['schedule'] = workshop['schedule'];
    if (workshop['working_hours'] != null) normalized['working_hours'] = workshop['working_hours'];
    if (workshop['is_open_now'] != null) normalized['is_open_now'] = workshop['is_open_now'];
    if (workshop['today_hours'] != null) normalized['today_hours'] = workshop['today_hours'];
    
    // Garantir que phone seja preservado (pode vir como string, number ou null)
    if (normalized['phone'] != null) {
      normalized['phone'] = normalized['phone'].toString();
    }
    
    // Garantir que logo_url seja preservado corretamente (mesma lógica da tela de lista)
    normalized['logo_url'] = normalized['logo_url'] ?? normalized['logo'];
    
    // Garantir que logo_url seja uma string válida (não vazia)
    if (normalized['logo_url'] != null && normalized['logo_url'].toString().trim().isEmpty) {
      normalized['logo_url'] = null;
    }
    
    // Garantir que latitude e longitude sejam sempre números quando disponíveis
    
    // Normalizar latitude
    final latRaw = normalized['latitude'];
    if (latRaw != null) {
      final lat = _parseDouble(latRaw);
      normalized['latitude'] = lat;
      print('   Latitude normalizada: $lat');
    } else {
      normalized['latitude'] = null;
      print('   Latitude é null');
    }
    
    // Normalizar longitude
    final lngRaw = normalized['longitude'];
    if (lngRaw != null) {
      final lng = _parseDouble(lngRaw);
      normalized['longitude'] = lng;
      print('   Longitude normalizada: $lng');
    } else {
      normalized['longitude'] = null;
      print('   Longitude é null');
    }
    
    return normalized;
  }

  Map<String, dynamic> _normalizeService(Map<String, dynamic> service) {
    final normalized = Map<String, dynamic>.from(service);
    
    // Mapear campos da API para campos esperados pelo app
    // A API retorna service_name e service_description, mas o app espera name e description
    normalized['name'] = normalized['service_name'] ?? normalized['name'] ?? 'Serviço';
    normalized['description'] = normalized['service_description'] ?? normalized['description'] ?? 'Descrição do serviço';
    
    // Garantir que name e description não sejam vazios
    if (normalized['name'] == null || normalized['name'].toString().trim().isEmpty) {
      normalized['name'] = 'Serviço';
    }
    if (normalized['description'] == null || normalized['description'].toString().trim().isEmpty) {
      normalized['description'] = 'Descrição do serviço';
    }
    
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
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == 'null' || trimmed == 'NULL' || trimmed == '') return null;
      final lower = trimmed.toLowerCase();
      if (lower == 'n/a' || lower == 'na' || lower == 'null' || lower == '--' || lower == 'undefined') {
        return null;
      }
      final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
      if (parsed != null && !parsed.isNaN && parsed.isFinite) {
        return parsed;
      }
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
    if (rating == null || rating <= 0 || rating > 5) {
      return '- ⭐';
    }
    final formatted = rating.toStringAsFixed(1);
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

















