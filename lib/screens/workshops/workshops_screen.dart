import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
import '../../widgets/meca_toast.dart';
import '../../services/location_service.dart';
import '../../utils/cep_formatter.dart';
import '../../widgets/meca_loading_widget.dart';
import 'workshop_detail_screen.dart';

class WorkshopsScreen extends StatefulWidget {
  /// Quando vindo da MIA, pré-filtra oficinas por este serviço
  final String? initialServiceId;
  final String? initialServiceName;

  const WorkshopsScreen({
    Key? key,
    this.initialServiceId,
    this.initialServiceName,
  }) : super(key: key);

  @override
  State<WorkshopsScreen> createState() => _WorkshopsScreenState();
}

class _WorkshopsScreenState extends State<WorkshopsScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService.instance;
  List<dynamic> _workshops = [];
  List<dynamic> _filteredWorkshops = [];
  bool _loading = false;
  String _error = '';
  String? _locationWarning;
  String? _manualCepError;
  bool _isManualCepLoading = false;
  bool _manualCepSuccess = false;
  
  // Filtros
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _cepController = TextEditingController();
  String _selectedService = 'Todos';
  String _selectedDistance = 'Todas'; // Padrão: todas as distâncias
  String _selectedRating = 'Todos';
  String _selectedInstallment = 'Todos';
  String _sortBy = 'distancia';
  bool _showOnlyFavorites = false;
  final Map<String, int> _heartBounceCounters = {};

  bool get _hasActiveFilters =>
      _selectedService != 'Todos' ||
      _selectedDistance != 'Todas' ||
      _selectedRating != 'Todos' ||
      _selectedInstallment != 'Todos' ||
      _sortBy != 'distancia' ||
      _showOnlyFavorites;

  @override
  void initState() {
    super.initState();
    if (widget.initialServiceId != null && widget.initialServiceId!.isNotEmpty) {
      _loadWorkshopsByService();
    } else {
      _loadNearbyWorkshops();
    }
  }

  Future<void> _loadNearbyWorkshops() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = '';
      _locationWarning = null;
      _manualCepError = null;
      _manualCepSuccess = false;
    });
    
    try {
      final status = await _locationService.ensurePermissions();
      double? targetLat;
      double? targetLng;

      if (status.canRequestPosition) {
        final position = await _locationService.getCurrentPosition(forceFresh: true);
        if (position != null) {
          targetLat = position.latitude;
          targetLng = position.longitude;
        } else {
          if (!mounted) return;
          setState(() {
            _locationWarning = 'Não conseguimos acessar sua localização. Distâncias não serão exibidas.';
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _locationWarning = _buildLocationWarning(status);
        });
      }

      double? radiusKm;
      if (targetLat != null && _selectedDistance != 'Todas') {
        switch (_selectedDistance) {
          case 'Até 50km':
            radiusKm = 50.0;
            break;
          case 'Até 200km':
            radiusKm = 200.0;
            break;
        }
      }
      await _fetchWorkshops(targetLat, targetLng, radiusKm: radiusKm);
    } catch (e) {
      String errorMessage = 'Erro ao carregar oficinas';
      if (e.toString().contains('timeout')) {
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

  /// Carrega oficinas que oferecem o serviço sugerido pela MIA
  Future<void> _loadWorkshopsByService() async {
    if (!mounted) return;
    final serviceId = widget.initialServiceId;
    if (serviceId == null || serviceId.isEmpty) return;

    setState(() {
      _loading = true;
      _error = '';
      _locationWarning = null;
      _manualCepError = null;
    });

    try {
      double? targetLat;
      double? targetLng;
      final status = await _locationService.ensurePermissions();
      if (status.canRequestPosition) {
        final position = await _locationService.getCurrentPosition(forceFresh: true);
        if (position != null) {
          targetLat = position.latitude;
          targetLng = position.longitude;
        }
      }

      final result = await _apiService.getWorkshopsByService(
        serviceId,
        lat: targetLat,
        lng: targetLng,
        radiusKm: targetLat != null ? 200.0 : null,
      );

      if (!mounted) return;
      if (result['success'] == true && result['data'] != null) {
        List<dynamic> workshops = result['data'] is List ? result['data']! : [];
        _normalizeWorkshopList(workshops, targetLat, targetLng);
        setState(() {
          _workshops = workshops;
          _filteredWorkshops = List.from(_workshops);
          _loading = false;
          _error = '';
        });
        _applyFilters();
      } else {
        setState(() {
          _error = result['error'] ?? 'Erro ao buscar oficinas para este serviço';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar oficinas: $e';
        _loading = false;
      });
    }
  }

  Future<void> _fetchWorkshops(double? userLat, double? userLng, {double? radiusKm}) async {
    final searchQuery = _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null;
    final hasLocation = userLat != null && userLng != null;

    Map<String, dynamic> result;
    if (hasLocation) {
      final finalRadiusKm = radiusKm ?? 999999.0;
      result = await _apiService.getNearbyWorkshops(userLat, userLng, finalRadiusKm, searchQuery);
    } else {
      result = await _apiService.getAllWorkshops();
    }

    if (!mounted) return;
    if (result['success']) {
      final data = result['data'];
      List<dynamic> workshops = [];

      if (data is Map) {
        workshops = data['workshops'] ?? data['workshop'] ?? data['data'] ?? [];
      } else if (data is List) {
        workshops = data;
      }

      _normalizeWorkshopList(workshops, userLat, userLng);

      setState(() {
        _workshops = workshops;
        _filteredWorkshops = List.from(_workshops);
        _loading = false;
        _error = '';
      });
      _applyFilters();
    } else {
      setState(() {
        _error = result['error'] ?? 'Erro ao carregar oficinas';
        _loading = false;
      });
    }
  }

  /// Normaliza lista de workshops: distância, endereço, logo, rating (evita duplicação)
  void _normalizeWorkshopList(List<dynamic> workshops, double? userLat, double? userLng) {
    for (var workshop in workshops) {
      final workshopLat = _extractLatitude(workshop);
      final workshopLng = _extractLongitude(workshop);
      final rawDistance = workshop['distance'];
      double? distance;
      if (rawDistance != null) {
        if (rawDistance is num) {
          distance = rawDistance.toDouble();
        } else if (rawDistance is String) {
          distance = double.tryParse(rawDistance.replaceAll(',', '.'));
        }
        if (distance != null && distance <= 0) distance = null;
      }
      if (distance == null && userLat != null && userLng != null && workshopLat != null && workshopLng != null) {
        try {
          distance = Geolocator.distanceBetween(userLat, userLng, workshopLat, workshopLng) / 1000.0;
        } catch (_) {}
      }
      workshop['distance'] = distance;
      workshop['latitude'] = workshopLat;
      workshop['longitude'] = workshopLng;
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
  }

  String _buildLocationWarning(LocationStatus status) {
    if (!status.serviceEnabled) {
      return 'Seu GPS está desligado. Estamos exibindo oficinas padrão até você ativar a localização.';
    }

    if (status.permissionPermanentlyDenied) {
      return 'A permissão de localização está bloqueada para o app. Mostrando oficinas padrão.';
    }

    if (!status.permissionGranted) {
      return 'Permissão de localização negada. Mostrando oficinas padrão enquanto você libera o acesso.';
    }

    return 'Não conseguimos usar sua localização agora. Mostrando oficinas padrão.';
  }

  Future<(double, double)?> _resolveCoordinatesFromCep(String cep) async {
    final uri = Uri.parse('https://viacep.com.br/ws/$cep/json/');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw CepLookupException('Não conseguimos validar esse CEP agora. Tente novamente em instantes.');
    }

    final data = jsonDecode(response.body);
    if (data is Map && data['erro'] == true) {
      throw CepLookupException('CEP não encontrado. Verifique se digitou corretamente.');
    }

    final logradouro = (data['logradouro'] as String?)?.trim() ?? '';
    final bairro = (data['bairro'] as String?)?.trim() ?? '';
    final cidade = (data['localidade'] as String?)?.trim() ?? '';
    final estado = (data['uf'] as String?)?.trim() ?? '';

    final primaryQuery = [
      if (logradouro.isNotEmpty) logradouro,
      if (bairro.isNotEmpty) bairro,
      if (cidade.isNotEmpty) cidade,
      if (estado.isNotEmpty) estado,
      'Brasil'
    ].join(', ');

    final fallbackQuery = [
      if (cidade.isNotEmpty) cidade,
      if (estado.isNotEmpty) estado,
      'Brasil',
      'CEP $cep',
    ].join(', ');

    Future<(double, double)?> tryResolve(String query) async {
      if (query.trim().isEmpty) return null;
      try {
        final locations = await locationFromAddress(query);
        if (locations.isNotEmpty) {
          final loc = locations.first;
          return (loc.latitude, loc.longitude);
        }
      } catch (_) {}
      return null;
    }

    return await tryResolve(primaryQuery) ?? await tryResolve(fallbackQuery);
  }

  Future<void> _handleCepSearch() async {
    final rawCep = _cepController.text.trim();
    final normalizedCep = rawCep.replaceAll(RegExp(r'[^0-9]'), '');

    if (normalizedCep.length != 8) {
      setState(() {
        _manualCepError = 'Informe um CEP válido com 8 dígitos.';
        _manualCepSuccess = false;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _manualCepError = null;
      _isManualCepLoading = true;
      _manualCepSuccess = false;
    });

    try {
      final coords = await _resolveCoordinatesFromCep(normalizedCep);
      if (coords == null) {
        throw CepLookupException('Não encontramos a latitude/longitude desse CEP.');
      }

      setState(() {
        _locationWarning = 'Exibindo oficinas para o CEP $normalizedCep.';
        _manualCepSuccess = true;
      });
      await _fetchWorkshops(coords.$1, coords.$2);
    } catch (e) {
      setState(() {
        _manualCepError = e is CepLookupException
            ? e.message
            : 'Não conseguimos localizar esse CEP. Confira os números e tente novamente.';
        _manualCepSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isManualCepLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: isDarkMode ? const Color(0xFF111111) : Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            title: Text(
              'Oficinas Próximas',
              style: TextStyle(
                color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: true,
            actions: [
              Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.tune_rounded,
                      color: isDarkMode ? const Color(0xFF00C977) : const Color(0xFF00C977),
                      size: 22,
                    ),
                    onPressed: _showFilterModal,
                  ),
                  if (_hasActiveFilters)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00C977),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.06),
              ),
            ),
          ),
          // Banner MIA - quando veio do diagnóstico inteligente
          if (widget.initialServiceName != null && widget.initialServiceName!.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00C977).withOpacity(0.15),
                      const Color(0xFF00B369).withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF00C977).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C977).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF00C977), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recomendado pela MIA',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Oficinas para: ${widget.initialServiceName}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Barra de pesquisa
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  // Se tiver texto de busca, fazer nova busca na API
                  // Se não tiver texto, apenas aplicar filtros locais
                  if (value.trim().isNotEmpty) {
                    _loadNearbyWorkshops();
                  } else {
                    _applyFilters();
                  }
                },
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
          // Warning banner de localização
          if (_locationWarning != null && !_loading && _error.isEmpty)
            SliverToBoxAdapter(
              child: _buildWarningBanner(_locationWarning!),
            ),
          // Conteúdo
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: MecaApiLoadingWidget(message: 'Buscando oficinas...'),
            )
          else if (_error.isNotEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildErrorView(),
            )
          else if (_filteredWorkshops.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildWorkshopCard(_filteredWorkshops[index]),
                  childCount: _filteredWorkshops.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Erro ao carregar oficinas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadNearbyWorkshops,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Tentar Novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C977),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00C977).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.build_circle_outlined,
                size: 48,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhuma oficina encontrada',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.grey.shade900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _searchController.text.trim().isNotEmpty
                  ? 'Não encontramos oficinas com o termo "${_searchController.text.trim()}"'
                  : 'Não há oficinas disponíveis próximas a você no momento.\n\nTente ajustar os filtros de distância ou verifique sua localização.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchController.text.trim().isEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadNearbyWorkshops,
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C977),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBanner(String message) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF4E5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFFFB74D),
                  child: Icon(Icons.gps_off, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Localização indisponível. Distâncias não serão exibidas.',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8B5E00),
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: _loadNearbyWorkshops,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF8B5E00),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 14),
                      SizedBox(width: 4),
                      Text('GPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ou informe seu CEP',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark ? const Color(0xFF1F1F1F) : const Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _manualCepError != null
                          ? Colors.red.withOpacity(0.7)
                          : _manualCepSuccess
                              ? Colors.green.withOpacity(0.7)
                              : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      Icon(
                        Icons.location_searching,
                        size: 20,
                        color: _manualCepError != null
                            ? Colors.red
                            : _manualCepSuccess
                                ? Colors.green
                                : Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _cepController,
                          keyboardType: TextInputType.number,
                          maxLength: 9,
                          inputFormatters: [CepFormatter()],
                          cursorColor: const Color(0xFF00C977),
                          style: TextStyle(
                            color: theme.brightness == Brightness.dark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '00000000',
                            hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ElevatedButton(
                          onPressed: _isManualCepLoading ? null : _handleCepSearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C977),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(60, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isManualCepLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Buscar'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                if (_manualCepError != null)
                  Text(
                    _manualCepError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                  )
                else if (_manualCepSuccess)
                  const Text(
                    'Localização atualizada com sucesso!',
                    style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleWorkshopFavorite(Map<String, dynamic> workshop) async {
    final workshopId = workshop['id']?.toString();
    if (workshopId == null || workshopId.isEmpty) return;

    final nowFavorite = !(workshop['is_favorite'] == true);
    setState(() {
      workshop['is_favorite'] = nowFavorite;
      _heartBounceCounters[workshopId] = (_heartBounceCounters[workshopId] ?? 0) + 1;
    });

    try {
      await _apiService.toggleWorkshopFavorite(workshopId);
      if (mounted) {
        MecaToast.showSuccess(context, nowFavorite ? 'Adicionada aos favoritos' : 'Removida dos favoritos');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          workshop['is_favorite'] = !nowFavorite;
        });
        MecaToast.show(context, 'Erro ao atualizar favorito');
      }
    }
  }

  Widget _buildWorkshopCard(Map<String, dynamic> workshop) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardPadding = screenWidth >= 430 ? 20.0 : 16.0;
    final logoSize = screenWidth >= 430 ? 72.0 : 64.0;
    // Usar distância real calculada (pode ser null se oficina não tem coordenadas)
    final distanceRaw = workshop['distance'];
    final double? distance = distanceRaw != null
        ? (distanceRaw is num
            ? distanceRaw.toDouble()
            : distanceRaw is String
                ? double.tryParse(distanceRaw.replaceAll(',', '.'))
                : null)
        : null;
    final double? ratingValue =
        _parseDouble(workshop['rating']) ?? _parseDouble(workshop['average_rating']);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            // workshop['distance'] já está em km (calculado localmente dividido por 1000)
            // NÃO dividir novamente
            final double? distanceKm = distance;
            debugPrint('🚗 [WorkshopCard] Navegando para oficina: ${workshop['name']}');
            debugPrint('🚗 [WorkshopCard] distance (km): $distance');
            debugPrint('🚗 [WorkshopCard] distanceKm passado: $distanceKm');
            debugPrint('🚗 [WorkshopCard] Vai mostrar popup? ${distanceKm != null && distanceKm > 50}');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WorkshopDetailScreen(
                  workshopId: workshop['id'],
                  distanceKm: distanceKm,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Builder(
                      builder: (context) {
                        final rawLogo = workshop['logo_url']?.toString() ?? '';
                        final logoUrl = rawLogo.isNotEmpty && rawLogo.startsWith('http') ? rawLogo : null;
                        if (logoUrl == null || logoUrl.isEmpty) {
                          return Container(
                            width: logoSize,
                            height: logoSize,
                            decoration: BoxDecoration(
                              color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.store_outlined,
                              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                              size: logoSize * 0.4,
                            ),
                          );
                        }
                        return Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00C977).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              logoUrl,
                              fit: BoxFit.cover,
                              width: logoSize,
                              height: logoSize,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.store_outlined,
                                    color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                                    size: logoSize * 0.4,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workshop['name'] ?? 'Oficina',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? const Color(0xFF00C977) : const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
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
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
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
                                      size: 14,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      (ratingValue != null && ratingValue > 0 && ratingValue <= 5)
                                          ? ratingValue.toStringAsFixed(1)
                                          : '-',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: distance != null && distance > 200.0
                                        ? Colors.red.withOpacity(0.1)
                                        : const Color(0xFF00C977).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.navigation,
                                        color: distance != null && distance > 200.0
                                            ? Colors.red
                                            : const Color(0xFF00C977),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          distance != null && distance > 0
                                              ? _formatDistance(distance)
                                              : 'Sem distância',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: distance != null && distance > 200.0
                                                ? Colors.red
                                                : const Color(0xFF00C977),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _toggleWorkshopFavorite(workshop),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey('heart_${workshop['id']}_${_heartBounceCounters[workshop['id']?.toString()] ?? 0}'),
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            final scale = 0.5 + (value * 0.5);
                            return Transform.scale(
                              scale: scale,
                              child: child,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: workshop['is_favorite'] != true ? BoxDecoration(
                              color: isDarkMode ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(16),
                            ) : null,
                            child: Icon(
                              workshop['is_favorite'] == true ? Icons.favorite : Icons.favorite_border,
                              color: workshop['is_favorite'] == true
                                  ? const Color(0xFFFF4B6E)
                                  : (isDarkMode ? Colors.white.withOpacity(0.5) : Colors.grey[600]),
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Services
                if (workshop['services'] != null)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: (workshop['services'] as List).take(3).map((service) {
                      // Capitalizar primeira letra de cada palavra
                      final serviceName = service.toString();
                      final capitalizedService = serviceName.split(' ').map((word) {
                        if (word.isEmpty) return word;
                        return word[0].toUpperCase() + (word.length > 1 ? word.substring(1).toLowerCase() : '');
                      }).join(' ');
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF00C977).withOpacity(0.15)
                              : const Color(0xFF00C977).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF00C977).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          capitalizedService,
                          style: TextStyle(
                            color: const Color(0xFF00C977),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 10),
                // Action button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C977), Color(0xFF00B369)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Ver Detalhes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
        // Filtro de favoritas
        if (_showOnlyFavorites && workshop['is_favorite'] != true) {
          return false;
        }

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
        
        // Filtro por serviço (pular se veio da MIA - já estão filtradas)
        if (widget.initialServiceId == null && _selectedService != 'Todos') {
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
        if (_selectedDistance != 'Todas') {
          final distance = workshop['distance'] ?? 0.0;
          double distanceValue = 0.0;
          if (distance is num) {
            distanceValue = distance.toDouble();
          } else if (distance is String) {
            distanceValue = double.tryParse(distance.replaceAll(' km', '').trim()) ?? 0.0;
          }
          switch (_selectedDistance) {
            case 'Até 50km':
              if (distanceValue > 50.0) return false;
              break;
            case 'Até 200km':
              if (distanceValue > 200.0) return false;
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
                            _selectedDistance = 'Todas';
                            _selectedRating = 'Todos';
                            _selectedInstallment = 'Todos';
                            _sortBy = 'distancia';
                            _showOnlyFavorites = false;
                          });
                          setState(() {
                            _selectedService = 'Todos';
                            _selectedDistance = 'Todas';
                            _selectedRating = 'Todos';
                            _selectedInstallment = 'Todos';
                            _sortBy = 'distancia';
                            _showOnlyFavorites = false;
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
                        // Filtro de favoritas
                        GestureDetector(
                          onTap: () {
                            setModalState(() => _showOnlyFavorites = !_showOnlyFavorites);
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: _showOnlyFavorites
                                  ? const Color(0xFFFF4B6E).withOpacity(0.1)
                                  : (isDarkMode ? const Color(0xFF252525) : Colors.grey[100]),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _showOnlyFavorites
                                    ? const Color(0xFFFF4B6E).withOpacity(0.4)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _showOnlyFavorites ? Icons.favorite : Icons.favorite_border,
                                  color: _showOnlyFavorites
                                      ? const Color(0xFFFF4B6E)
                                      : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Apenas oficinas favoritas',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: _showOnlyFavorites ? FontWeight.w600 : FontWeight.w400,
                                      color: _showOnlyFavorites
                                          ? const Color(0xFFFF4B6E)
                                          : (isDarkMode ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ),
                                Icon(
                                  _showOnlyFavorites ? Icons.check_circle : Icons.circle_outlined,
                                  color: _showOnlyFavorites
                                      ? const Color(0xFFFF4B6E)
                                      : (isDarkMode ? Colors.grey[600] : Colors.grey[400]),
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),

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
                              
                              // Distância - MOVIDA PARA CIMA (primeira opção)
                              _buildFilterSection(
                                'Distância',
                                _selectedDistance,
                                ['Até 50km', 'Até 200km', 'Todas'],
                                isDarkMode,
                                (value) {
                                  setModalState(() {
                                    _selectedDistance = value;
                                  });
                                  setState(() {
                                    _selectedDistance = value;
                                  });
                                  // Recarregar oficinas com novo filtro de distância
                                  Navigator.pop(context);
                                  _loadNearbyWorkshops();
                                },
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
                            foregroundColor: const Color(0xFF00C977),
                            side: const BorderSide(color: Color(0xFF00C977), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _applyFilters();
                            });
                            Navigator.pop(context);
                            setState(() {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C977),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            elevation: 0,
                          ),
                          child: const Text('Aplicar'),
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
              ? const Color(0xFF00C977)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00C977)
                : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected
                  ? Colors.white
                  : (isDarkMode ? Colors.grey[400] : Colors.grey[400]!),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
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
                final displayOption = (option == 'Todos' || option == 'Todas') 
                    ? option 
                    : option.split(' ').map((word) {
                        if (word.isEmpty) return word;
                        return word[0].toUpperCase() + (word.length > 1 ? word.substring(1).toLowerCase() : '');
                      }).join(' ');
                
                return SizedBox(
                  width: cardWidth,
                  height: 56,
                  child: InkWell(
                    onTap: () {
                      onChanged(option);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        maxLines: 2,
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

  // Extrair latitude de múltiplas fontes possíveis
  double? _extractLatitude(Map<String, dynamic> workshop) {
    final addressDetails = workshop['address_details'] as Map<String, dynamic>?;
    final address = workshop['address'];
    final addressMap = address is Map ? Map<String, dynamic>.from(address) : null;
    
    final sources = [
      workshop['latitude'],
      workshop['lat'],
      addressDetails?['latitude'],
      addressDetails?['lat'],
      addressMap?['latitude'],
      addressMap?['lat'],
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

  // Extrair longitude de múltiplas fontes possíveis
  double? _extractLongitude(Map<String, dynamic> workshop) {
    final addressDetails = workshop['address_details'] as Map<String, dynamic>?;
    final address = workshop['address'];
    final addressMap = address is Map ? Map<String, dynamic>.from(address) : null;
    
    final sources = [
      workshop['longitude'],
      workshop['lng'],
      workshop['lon'],
      addressDetails?['longitude'],
      addressDetails?['lng'],
      addressDetails?['lon'],
      addressMap?['longitude'],
      addressMap?['lng'],
      addressMap?['lon'],
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
      if (parsed != null && parsed != 0.0 && !parsed.isNaN && parsed.isFinite) {
        return parsed;
      }
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
    _cepController.dispose();
    super.dispose();
  }
}

class CepLookupException implements Exception {
  CepLookupException(this.message);
  final String message;
}







