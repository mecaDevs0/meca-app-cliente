import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../utils/price_utils.dart';
import '../../widgets/app_alerts.dart';
import '../../widgets/meca_loading_widget.dart';

class VehicleHistoryScreen extends StatefulWidget {
  final String vehicleId;
  final String plate;
  final Map<String, dynamic>? vehicle;

  const VehicleHistoryScreen({
    Key? key,
    required this.vehicleId,
    required this.plate,
    this.vehicle,
  }) : super(key: key);

  @override
  State<VehicleHistoryScreen> createState() => _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends State<VehicleHistoryScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _vehicle;
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicle != null
        ? Map<String, dynamic>.from(widget.vehicle!)
        : <String, dynamic>{};
    _vehicle!.putIfAbsent('plate', () => widget.plate);
    _loadVehicleHistory();
  }

  Future<void> _loadVehicleHistory() async {
    if (widget.vehicleId.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppAlerts.showError(
          context,
          message: 'Não encontramos o identificador do veículo. Volte e tente novamente.',
        );
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getMaintenanceHistory(widget.vehicleId);
      if (!mounted) return;

      if (response['success'] == true) {
        final history = <Map<String, dynamic>>[];
        final data = response['data'];

        if (data is List) {
          for (final item in data) {
            if (item is Map<String, dynamic>) {
              history.add(Map<String, dynamic>.from(item));
            } else if (item is Map) {
              history.add(item.map((key, value) => MapEntry(key.toString(), value)));
            }
          }
        }

        setState(() {
          _history = history;
          _isLoading = false;

          _vehicle ??= <String, dynamic>{};
          _vehicle!.putIfAbsent('plate', () => widget.plate);

          if (history.isNotEmpty) {
            final first = history.first;
            _vehicle!.putIfAbsent('brand', () => first['vehicle_brand'] ?? first['brand']);
            _vehicle!.putIfAbsent('model', () => first['vehicle_model'] ?? first['model']);
            _vehicle!.putIfAbsent('year', () => first['vehicle_year'] ?? first['year']);
          }
        });
      } else {
        setState(() => _isLoading = false);
        AppAlerts.showError(
          context,
          message: response['error']?.toString() ??
              'Não foi possível carregar o histórico deste veículo. Tente novamente.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppAlerts.showError(
        context,
        message: 'Não foi possível carregar o histórico deste veículo. Tente novamente.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final plate = (_vehicle?['plate'] ?? widget.plate).toString().toUpperCase();

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : const Color(0xFF252940),
        title: const Text(
          'Histórico do Veículo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const MecaApiLoadingWidget(message: 'Carregando histórico...')
          : RefreshIndicator(
              color: const Color(0xFF00C977),
              onRefresh: _loadVehicleHistory,
              child: _history.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildVehicleHeader(plate, isDarkMode),
                        const SizedBox(height: 20),
                        _buildEmptyState(isDarkMode),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      itemCount: _history.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildVehicleHeader(plate, isDarkMode),
                              const SizedBox(height: 20),
                            ],
                          );
                        }

                        final item = _history[index - 1];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildHistoryCard(item, isDarkMode),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildVehicleHeader(String plate, bool isDarkMode) {
    final brand = (_vehicle?['brand'] ?? '').toString();
    final model = (_vehicle?['model'] ?? '').toString();
    final year = (_vehicle?['year'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF00C977).withOpacity(0.2),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C977), Color(0xFF00B369)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_car, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plate.isEmpty ? 'Placa desconhecida' : plate,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFF252940),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [brand, model, year].where((value) => value.isNotEmpty).join(' • '),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00C977).withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.history, size: 64, color: Color(0xFF00C977)),
          const SizedBox(height: 16),
          Text(
            'Nenhum serviço encontrado',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF252940),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Quando você realizar serviços nesse veículo, eles aparecerão aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item, bool isDarkMode) {
    final serviceName = (item['service_name'] ?? item['service']?['name'] ?? 'Serviço').toString();
    final workshopName = (item['workshop_name'] ?? 'Oficina').toString();
    final status = (item['booking_status'] ?? item['status'] ?? '').toString();
    final notes = (item['notes'] ?? item['service_description'] ?? '').toString();

    final rawPrice = item['price_paid'] ?? item['price'] ?? item['total'];
    final priceText = PriceUtils.hasValidPrice(rawPrice) ? PriceUtils.formatCurrency(rawPrice) : null;

    final serviceDate = item['service_date'] ?? item['completion_date'] ?? item['created_at'];
    final dateText = _formatDate(serviceDate?.toString());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF00C977).withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  serviceName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF252940),
                  ),
                ),
              ),
              if (priceText != null)
                Text(
                  priceText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00C977),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.event, size: 16, color: Color(0xFF00C977)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dateText,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Logo da oficina: sempre via proxy da API (evita 403 do S3)
              Builder(
                builder: (context) {
                  final rawLogo = (item['workshop_logo_url'] ?? item['workshop']?['logo_url'])?.toString().trim() ?? '';
                  final logoUrl = rawLogo.isNotEmpty && rawLogo.startsWith('http') ? rawLogo : null;
                  if (logoUrl != null) {
                    return Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C977).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          logoUrl,
                          width: 16,
                          height: 16,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.store,
                            size: 16,
                            color: Color(0xFF00C977),
                          ),
                        ),
                      ),
                    );
                  }
                  return const Icon(Icons.store, size: 16, color: Color(0xFF00C977));
                },
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  workshopName,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          if (status.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00C977).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00C977),
                ),
              ),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              notes,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'Data não informada';
    try {
      final parsed = DateTime.parse(date);
      final local = DateTime(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute);
      return DateFormat('dd/MM/yyyy HH:mm').format(local);
    } catch (_) {
      return date;
    }
  }
}


