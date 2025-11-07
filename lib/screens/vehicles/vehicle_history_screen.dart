import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../widgets/meca_loading_widget.dart';

class VehicleHistoryScreen extends StatefulWidget {
  final String vehicleId;
  final Map<String, dynamic> vehicle;

  const VehicleHistoryScreen({
    Key? key,
    required this.vehicleId,
    required this.vehicle,
  }) : super(key: key);

  @override
  State<VehicleHistoryScreen> createState() => _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends State<VehicleHistoryScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _maintenanceHistory = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadMaintenanceHistory();
  }

  Future<void> _loadMaintenanceHistory() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final result = await _apiService.getMaintenanceHistory(widget.vehicleId);
      
      if (result['success']) {
        setState(() {
          // A API retorna data diretamente como lista
          final data = result['data'];
          if (data is List) {
            _maintenanceHistory = List<Map<String, dynamic>>.from(data);
          } else if (data is Map && data['maintenanceHistory'] != null) {
            _maintenanceHistory = List<Map<String, dynamic>>.from(data['maintenanceHistory'] ?? []);
          } else {
            _maintenanceHistory = [];
          }
          _loading = false;
        });
      } else {
        setState(() {
          _error = result['error'] ?? 'Erro ao carregar histórico';
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: Text(
          'Histórico - ${widget.vehicle['brand']} ${widget.vehicle['model']}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF00C977),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const MecaApiLoadingWidget(message: 'Carregando histórico...')
          : _error.isNotEmpty
              ? _buildErrorView()
              : _buildHistoryContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMaintenanceHistory,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C977)),
              child: const Text('Tentar Novamente', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryContent() {
    if (_maintenanceHistory.isEmpty) {
      return _buildEmptyHistory();
    }

    return Column(
      children: [
        _buildVehicleInfo(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _maintenanceHistory.length,
            itemBuilder: (context, index) {
              final record = _maintenanceHistory[index];
              return _buildHistoryCard(record);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00C977), Color(0xFF00B369)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C977).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.vehicle['brand']} ${widget.vehicle['model']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${widget.vehicle['year']} • ${widget.vehicle['plate']}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard('Serviços', _maintenanceHistory.length.toString()),
              const SizedBox(width: 16),
              _buildStatCard('Total Investido', _calculateTotalSpent()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF00C977).withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.history,
                size: 60,
                color: Color(0xFF00C977),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nenhum serviço realizado',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00C977),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'O histórico de manutenção aparecerá aqui\napós a realização de serviços.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C977),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Agendar Serviço',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> record) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Tentar múltiplos formatos de data
    DateTime? completionDate;
    final dateStr = record['completion_date']?.toString() ?? record['completed_at']?.toString() ?? record['created_at']?.toString() ?? '';
    if (dateStr.isNotEmpty) {
      completionDate = DateTime.tryParse(dateStr);
    }
    final formattedDate = completionDate != null 
        ? DateFormat('dd/MM/yyyy').format(completionDate)
        : 'Data não disponível';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com data e preço
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00C977).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00C977),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record['workshop_name'] ?? 'Oficina',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C977),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'R\$ ${_formatPrice(record['price_paid'] ?? record['price'] ?? 0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Conteúdo do serviço
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['service_name'] ?? 'Serviço',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF252940),
                  ),
                ),
                const SizedBox(height: 8),
                if (record['service_description'] != null) ...[
                  Text(
                    record['service_description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Observações do cliente
                if (record['notes'] != null && record['notes'].isNotEmpty) ...[
                  _buildNotesSection('Suas observações', record['notes']),
                  const SizedBox(height: 12),
                ],
                
                // Observações da oficina
                if (record['workshop_notes'] != null && record['workshop_notes'].isNotEmpty) ...[
                  _buildNotesSection('Observações da oficina', record['workshop_notes']),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(String title, String content) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF00C977),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0.00';
    if (price is String) {
      final parsed = double.tryParse(price);
      return parsed?.toStringAsFixed(2) ?? '0.00';
    }
    if (price is num) {
      return price.toDouble().toStringAsFixed(2);
    }
    return '0.00';
  }

  String _calculateTotalSpent() {
    double total = 0;
    for (var record in _maintenanceHistory) {
      final pricePaid = record['price_paid'] ?? record['price'] ?? 0;
      if (pricePaid != null && pricePaid != 0) {
        // Converter para double corretamente, tratando tanto String quanto num
        try {
          if (pricePaid is String) {
            // Remover qualquer formatação (R$, espaços, etc)
            final cleanPrice = pricePaid.replaceAll(RegExp(r'[^\d,.-]'), '').replaceAll(',', '.').trim();
            final parsed = double.tryParse(cleanPrice);
            if (parsed != null && parsed > 0) {
              total += parsed;
            }
          } else if (pricePaid is num) {
            final price = pricePaid.toDouble();
            if (price > 0) {
              total += price;
            }
          } else {
            // Tentar converter como String caso não seja nem String nem num
            final priceStr = pricePaid.toString();
            final cleanPrice = priceStr.replaceAll(RegExp(r'[^\d,.-]'), '').replaceAll(',', '.').trim();
            final parsed = double.tryParse(cleanPrice);
            if (parsed != null && parsed > 0) {
              total += parsed;
            }
          }
        } catch (e) {
          // Ignorar erros de conversão e continuar
          print('Erro ao converter preço: $pricePaid - $e');
        }
      }
    }
    return total > 0 ? 'R\$ ${total.toStringAsFixed(2)}' : 'R\$ 0,00';
  }
}


import '../../services/api_service.dart';
import '../../widgets/meca_loading_widget.dart';

class VehicleHistoryScreen extends StatefulWidget {
  final String vehicleId;
  final Map<String, dynamic> vehicle;

  const VehicleHistoryScreen({
    Key? key,
    required this.vehicleId,
    required this.vehicle,
  }) : super(key: key);

  @override
  State<VehicleHistoryScreen> createState() => _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends State<VehicleHistoryScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _maintenanceHistory = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadMaintenanceHistory();
  }

  Future<void> _loadMaintenanceHistory() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final result = await _apiService.getMaintenanceHistory(widget.vehicleId);
      
      if (result['success']) {
        setState(() {
          // A API retorna data diretamente como lista
          final data = result['data'];
          if (data is List) {
            _maintenanceHistory = List<Map<String, dynamic>>.from(data);
          } else if (data is Map && data['maintenanceHistory'] != null) {
            _maintenanceHistory = List<Map<String, dynamic>>.from(data['maintenanceHistory'] ?? []);
          } else {
            _maintenanceHistory = [];
          }
          _loading = false;
        });
      } else {
        setState(() {
          _error = result['error'] ?? 'Erro ao carregar histórico';
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: Text(
          'Histórico - ${widget.vehicle['brand']} ${widget.vehicle['model']}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF00C977),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const MecaApiLoadingWidget(message: 'Carregando histórico...')
          : _error.isNotEmpty
              ? _buildErrorView()
              : _buildHistoryContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMaintenanceHistory,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C977)),
              child: const Text('Tentar Novamente', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryContent() {
    if (_maintenanceHistory.isEmpty) {
      return _buildEmptyHistory();
    }

    return Column(
      children: [
        _buildVehicleInfo(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _maintenanceHistory.length,
            itemBuilder: (context, index) {
              final record = _maintenanceHistory[index];
              return _buildHistoryCard(record);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00C977), Color(0xFF00B369)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C977).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.vehicle['brand']} ${widget.vehicle['model']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${widget.vehicle['year']} • ${widget.vehicle['plate']}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard('Serviços', _maintenanceHistory.length.toString()),
              const SizedBox(width: 16),
              _buildStatCard('Total Investido', _calculateTotalSpent()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF00C977).withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.history,
                size: 60,
                color: Color(0xFF00C977),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nenhum serviço realizado',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00C977),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'O histórico de manutenção aparecerá aqui\napós a realização de serviços.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C977),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Agendar Serviço',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> record) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Tentar múltiplos formatos de data
    DateTime? completionDate;
    final dateStr = record['completion_date']?.toString() ?? record['completed_at']?.toString() ?? record['created_at']?.toString() ?? '';
    if (dateStr.isNotEmpty) {
      completionDate = DateTime.tryParse(dateStr);
    }
    final formattedDate = completionDate != null 
        ? DateFormat('dd/MM/yyyy').format(completionDate)
        : 'Data não disponível';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com data e preço
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00C977).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00C977),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record['workshop_name'] ?? 'Oficina',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C977),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'R\$ ${_formatPrice(record['price_paid'] ?? record['price'] ?? 0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Conteúdo do serviço
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['service_name'] ?? 'Serviço',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF252940),
                  ),
                ),
                const SizedBox(height: 8),
                if (record['service_description'] != null) ...[
                  Text(
                    record['service_description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Observações do cliente
                if (record['notes'] != null && record['notes'].isNotEmpty) ...[
                  _buildNotesSection('Suas observações', record['notes']),
                  const SizedBox(height: 12),
                ],
                
                // Observações da oficina
                if (record['workshop_notes'] != null && record['workshop_notes'].isNotEmpty) ...[
                  _buildNotesSection('Observações da oficina', record['workshop_notes']),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(String title, String content) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF00C977),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0.00';
    if (price is String) {
      final parsed = double.tryParse(price);
      return parsed?.toStringAsFixed(2) ?? '0.00';
    }
    if (price is num) {
      return price.toDouble().toStringAsFixed(2);
    }
    return '0.00';
  }

  String _calculateTotalSpent() {
    double total = 0;
    for (var record in _maintenanceHistory) {
      final pricePaid = record['price_paid'] ?? record['price'] ?? 0;
      if (pricePaid != null && pricePaid != 0) {
        // Converter para double corretamente, tratando tanto String quanto num
        try {
          if (pricePaid is String) {
            // Remover qualquer formatação (R$, espaços, etc)
            final cleanPrice = pricePaid.replaceAll(RegExp(r'[^\d,.-]'), '').replaceAll(',', '.').trim();
            final parsed = double.tryParse(cleanPrice);
            if (parsed != null && parsed > 0) {
              total += parsed;
            }
          } else if (pricePaid is num) {
            final price = pricePaid.toDouble();
            if (price > 0) {
              total += price;
            }
          } else {
            // Tentar converter como String caso não seja nem String nem num
            final priceStr = pricePaid.toString();
            final cleanPrice = priceStr.replaceAll(RegExp(r'[^\d,.-]'), '').replaceAll(',', '.').trim();
            final parsed = double.tryParse(cleanPrice);
            if (parsed != null && parsed > 0) {
              total += parsed;
            }
          }
        } catch (e) {
          // Ignorar erros de conversão e continuar
          print('Erro ao converter preço: $pricePaid - $e');
        }
      }
    }
    return total > 0 ? 'R\$ ${total.toStringAsFixed(2)}' : 'R\$ 0,00';
  }
}


import '../../services/api_service.dart';
import '../../widgets/meca_loading_widget.dart';

class VehicleHistoryScreen extends StatefulWidget {
  final String vehicleId;
  final Map<String, dynamic> vehicle;

  const VehicleHistoryScreen({
    Key? key,
    required this.vehicleId,
    required this.vehicle,
  }) : super(key: key);

  @override
  State<VehicleHistoryScreen> createState() => _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends State<VehicleHistoryScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _maintenanceHistory = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadMaintenanceHistory();
  }

  Future<void> _loadMaintenanceHistory() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final result = await _apiService.getMaintenanceHistory(widget.vehicleId);
      
      if (result['success']) {
        setState(() {
          // A API retorna data diretamente como lista
          final data = result['data'];
          if (data is List) {
            _maintenanceHistory = List<Map<String, dynamic>>.from(data);
          } else if (data is Map && data['maintenanceHistory'] != null) {
            _maintenanceHistory = List<Map<String, dynamic>>.from(data['maintenanceHistory'] ?? []);
          } else {
            _maintenanceHistory = [];
          }
          _loading = false;
        });
      } else {
        setState(() {
          _error = result['error'] ?? 'Erro ao carregar histórico';
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: Text(
          'Histórico - ${widget.vehicle['brand']} ${widget.vehicle['model']}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF00C977),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const MecaApiLoadingWidget(message: 'Carregando histórico...')
          : _error.isNotEmpty
              ? _buildErrorView()
              : _buildHistoryContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMaintenanceHistory,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C977)),
              child: const Text('Tentar Novamente', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryContent() {
    if (_maintenanceHistory.isEmpty) {
      return _buildEmptyHistory();
    }

    return Column(
      children: [
        _buildVehicleInfo(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _maintenanceHistory.length,
            itemBuilder: (context, index) {
              final record = _maintenanceHistory[index];
              return _buildHistoryCard(record);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00C977), Color(0xFF00B369)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C977).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.vehicle['brand']} ${widget.vehicle['model']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${widget.vehicle['year']} • ${widget.vehicle['plate']}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard('Serviços', _maintenanceHistory.length.toString()),
              const SizedBox(width: 16),
              _buildStatCard('Total Investido', _calculateTotalSpent()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF00C977).withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.history,
                size: 60,
                color: Color(0xFF00C977),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nenhum serviço realizado',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00C977),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'O histórico de manutenção aparecerá aqui\napós a realização de serviços.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C977),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Agendar Serviço',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> record) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Tentar múltiplos formatos de data
    DateTime? completionDate;
    final dateStr = record['completion_date']?.toString() ?? record['completed_at']?.toString() ?? record['created_at']?.toString() ?? '';
    if (dateStr.isNotEmpty) {
      completionDate = DateTime.tryParse(dateStr);
    }
    final formattedDate = completionDate != null 
        ? DateFormat('dd/MM/yyyy').format(completionDate)
        : 'Data não disponível';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com data e preço
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00C977).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00C977),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record['workshop_name'] ?? 'Oficina',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C977),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'R\$ ${_formatPrice(record['price_paid'] ?? record['price'] ?? 0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Conteúdo do serviço
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['service_name'] ?? 'Serviço',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF252940),
                  ),
                ),
                const SizedBox(height: 8),
                if (record['service_description'] != null) ...[
                  Text(
                    record['service_description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Observações do cliente
                if (record['notes'] != null && record['notes'].isNotEmpty) ...[
                  _buildNotesSection('Suas observações', record['notes']),
                  const SizedBox(height: 12),
                ],
                
                // Observações da oficina
                if (record['workshop_notes'] != null && record['workshop_notes'].isNotEmpty) ...[
                  _buildNotesSection('Observações da oficina', record['workshop_notes']),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(String title, String content) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF00C977),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0.00';
    if (price is String) {
      final parsed = double.tryParse(price);
      return parsed?.toStringAsFixed(2) ?? '0.00';
    }
    if (price is num) {
      return price.toDouble().toStringAsFixed(2);
    }
    return '0.00';
  }

  String _calculateTotalSpent() {
    double total = 0;
    for (var record in _maintenanceHistory) {
      final pricePaid = record['price_paid'] ?? record['price'] ?? 0;
      if (pricePaid != null && pricePaid != 0) {
        // Converter para double corretamente, tratando tanto String quanto num
        try {
          if (pricePaid is String) {
            // Remover qualquer formatação (R$, espaços, etc)
            final cleanPrice = pricePaid.replaceAll(RegExp(r'[^\d,.-]'), '').replaceAll(',', '.').trim();
            final parsed = double.tryParse(cleanPrice);
            if (parsed != null && parsed > 0) {
              total += parsed;
            }
          } else if (pricePaid is num) {
            final price = pricePaid.toDouble();
            if (price > 0) {
              total += price;
            }
          } else {
            // Tentar converter como String caso não seja nem String nem num
            final priceStr = pricePaid.toString();
            final cleanPrice = priceStr.replaceAll(RegExp(r'[^\d,.-]'), '').replaceAll(',', '.').trim();
            final parsed = double.tryParse(cleanPrice);
            if (parsed != null && parsed > 0) {
              total += parsed;
            }
          }
        } catch (e) {
          // Ignorar erros de conversão e continuar
          print('Erro ao converter preço: $pricePaid - $e');
        }
      }
    }
    return total > 0 ? 'R\$ ${total.toStringAsFixed(2)}' : 'R\$ 0,00';
  }
}


import '../../services/api_service.dart';
import '../../widgets/meca_loading_widget.dart';

class VehicleHistoryScreen extends StatefulWidget {
  final String vehicleId;
  final Map<String, dynamic> vehicle;

  const VehicleHistoryScreen({
    Key? key,
    required this.vehicleId,
    required this.vehicle,
  }) : super(key: key);

  @override
  State<VehicleHistoryScreen> createState() => _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends State<VehicleHistoryScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _maintenanceHistory = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadMaintenanceHistory();
  }

  Future<void> _loadMaintenanceHistory() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final result = await _apiService.getMaintenanceHistory(widget.vehicleId);
      
      if (result['success']) {
        setState(() {
          // A API retorna data diretamente como lista
          final data = result['data'];
          if (data is List) {
            _maintenanceHistory = List<Map<String, dynamic>>.from(data);
          } else if (data is Map && data['maintenanceHistory'] != null) {
            _maintenanceHistory = List<Map<String, dynamic>>.from(data['maintenanceHistory'] ?? []);
          } else {
            _maintenanceHistory = [];
          }
          _loading = false;
        });
      } else {
        setState(() {
          _error = result['error'] ?? 'Erro ao carregar histórico';
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: Text(
          'Histórico - ${widget.vehicle['brand']} ${widget.vehicle['model']}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF00C977),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const MecaApiLoadingWidget(message: 'Carregando histórico...')
          : _error.isNotEmpty
              ? _buildErrorView()
              : _buildHistoryContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMaintenanceHistory,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C977)),
              child: const Text('Tentar Novamente', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryContent() {
    if (_maintenanceHistory.isEmpty) {
      return _buildEmptyHistory();
    }

    return Column(
      children: [
        _buildVehicleInfo(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _maintenanceHistory.length,
            itemBuilder: (context, index) {
              final record = _maintenanceHistory[index];
              return _buildHistoryCard(record);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00C977), Color(0xFF00B369)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C977).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.vehicle['brand']} ${widget.vehicle['model']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${widget.vehicle['year']} • ${widget.vehicle['plate']}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard('Serviços', _maintenanceHistory.length.toString()),
              const SizedBox(width: 16),
              _buildStatCard('Total Investido', _calculateTotalSpent()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF00C977).withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.history,
                size: 60,
                color: Color(0xFF00C977),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nenhum serviço realizado',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00C977),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'O histórico de manutenção aparecerá aqui\napós a realização de serviços.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C977),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Agendar Serviço',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> record) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Tentar múltiplos formatos de data
    DateTime? completionDate;
    final dateStr = record['completion_date']?.toString() ?? record['completed_at']?.toString() ?? record['created_at']?.toString() ?? '';
    if (dateStr.isNotEmpty) {
      completionDate = DateTime.tryParse(dateStr);
    }
    final formattedDate = completionDate != null 
        ? DateFormat('dd/MM/yyyy').format(completionDate)
        : 'Data não disponível';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com data e preço
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00C977).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00C977),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record['workshop_name'] ?? 'Oficina',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C977),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'R\$ ${_formatPrice(record['price_paid'] ?? record['price'] ?? 0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Conteúdo do serviço
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['service_name'] ?? 'Serviço',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF252940),
                  ),
                ),
                const SizedBox(height: 8),
                if (record['service_description'] != null) ...[
                  Text(
                    record['service_description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Observações do cliente
                if (record['notes'] != null && record['notes'].isNotEmpty) ...[
                  _buildNotesSection('Suas observações', record['notes']),
                  const SizedBox(height: 12),
                ],
                
                // Observações da oficina
                if (record['workshop_notes'] != null && record['workshop_notes'].isNotEmpty) ...[
                  _buildNotesSection('Observações da oficina', record['workshop_notes']),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(String title, String content) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF00C977),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0.00';
    if (price is String) {
      final parsed = double.tryParse(price);
      return parsed?.toStringAsFixed(2) ?? '0.00';
    }
    if (price is num) {
      return price.toDouble().toStringAsFixed(2);
    }
    return '0.00';
  }

  String _calculateTotalSpent() {
    double total = 0;
    for (var record in _maintenanceHistory) {
      final pricePaid = record['price_paid'] ?? record['price'] ?? 0;
      if (pricePaid != null && pricePaid != 0) {
        // Converter para double corretamente, tratando tanto String quanto num
        try {
          if (pricePaid is String) {
            // Remover qualquer formatação (R$, espaços, etc)
            final cleanPrice = pricePaid.replaceAll(RegExp(r'[^\d,.-]'), '').replaceAll(',', '.').trim();
            final parsed = double.tryParse(cleanPrice);
            if (parsed != null && parsed > 0) {
              total += parsed;
            }
          } else if (pricePaid is num) {
            final price = pricePaid.toDouble();
            if (price > 0) {
              total += price;
            }
          } else {
            // Tentar converter como String caso não seja nem String nem num
            final priceStr = pricePaid.toString();
            final cleanPrice = priceStr.replaceAll(RegExp(r'[^\d,.-]'), '').replaceAll(',', '.').trim();
            final parsed = double.tryParse(cleanPrice);
            if (parsed != null && parsed > 0) {
              total += parsed;
            }
          }
        } catch (e) {
          // Ignorar erros de conversão e continuar
          print('Erro ao converter preço: $pricePaid - $e');
        }
      }
    }
    return total > 0 ? 'R\$ ${total.toStringAsFixed(2)}' : 'R\$ 0,00';
  }
}


import '../../services/api_service.dart';
import '../../widgets/meca_loading_widget.dart';

class VehicleHistoryScreen extends StatefulWidget {
  final String vehicleId;
  final Map<String, dynamic> vehicle;

  const VehicleHistoryScreen({
    Key? key,
    required this.vehicleId,
    required this.vehicle,
  }) : super(key: key);

  @override
  State<VehicleHistoryScreen> createState() => _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends State<VehicleHistoryScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _maintenanceHistory = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadMaintenanceHistory();
  }

  Future<void> _loadMaintenanceHistory() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final result = await _apiService.getMaintenanceHistory(widget.vehicleId);
      
      if (result['success']) {
        setState(() {
          // A API retorna data diretamente como lista
          final data = result['data'];
          if (data is List) {
            _maintenanceHistory = List<Map<String, dynamic>>.from(data);
          } else if (data is Map && data['maintenanceHistory'] != null) {
            _maintenanceHistory = List<Map<String, dynamic>>.from(data['maintenanceHistory'] ?? []);
          } else {
            _maintenanceHistory = [];
          }
          _loading = false;
        });
      } else {
        setState(() {
          _error = result['error'] ?? 'Erro ao carregar histórico';
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: Text(
          'Histórico - ${widget.vehicle['brand']} ${widget.vehicle['model']}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF00C977),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const MecaApiLoadingWidget(message: 'Carregando histórico...')
          : _error.isNotEmpty
              ? _buildErrorView()
              : _buildHistoryContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMaintenanceHistory,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C977)),
              child: const Text('Tentar Novamente', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryContent() {
    if (_maintenanceHistory.isEmpty) {
      return _buildEmptyHistory();
    }

    return Column(
      children: [
        _buildVehicleInfo(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _maintenanceHistory.length,
            itemBuilder: (context, index) {
              final record = _maintenanceHistory[index];
              return _buildHistoryCard(record);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00C977), Color(0xFF00B369)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C977).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.vehicle['brand']} ${widget.vehicle['model']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${widget.vehicle['year']} • ${widget.vehicle['plate']}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard('Serviços', _maintenanceHistory.length.toString()),
              const SizedBox(width: 16),
              _buildStatCard('Total Investido', _calculateTotalSpent()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF00C977).withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.history,
                size: 60,
                color: Color(0xFF00C977),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nenhum serviço realizado',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00C977),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'O histórico de manutenção aparecerá aqui\napós a realização de serviços.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C977),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Agendar Serviço',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> record) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Tentar múltiplos formatos de data
    DateTime? completionDate;
    final dateStr = record['completion_date']?.toString() ?? record['completed_at']?.toString() ?? record['created_at']?.toString() ?? '';
    if (dateStr.isNotEmpty) {
      completionDate = DateTime.tryParse(dateStr);
    }
    final formattedDate = completionDate != null 
        ? DateFormat('dd/MM/yyyy').format(completionDate)
        : 'Data não disponível';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com data e preço
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00C977).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00C977),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record['workshop_name'] ?? 'Oficina',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C977),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'R\$ ${_formatPrice(record['price_paid'] ?? record['price'] ?? 0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Conteúdo do serviço
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['service_name'] ?? 'Serviço',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF252940),
                  ),
                ),
                const SizedBox(height: 8),
                if (record['service_description'] != null) ...[
                  Text(
                    record['service_description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Observações do cliente
                if (record['notes'] != null && record['notes'].isNotEmpty) ...[
                  _buildNotesSection('Suas observações', record['notes']),
                  const SizedBox(height: 12),
                ],
                
                // Observações da oficina
                if (record['workshop_notes'] != null && record['workshop_notes'].isNotEmpty) ...[
                  _buildNotesSection('Observações da oficina', record['workshop_notes']),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(String title, String content) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF00C977),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0.00';
    if (price is String) {
      final parsed = double.tryParse(price);
      return parsed?.toStringAsFixed(2) ?? '0.00';
    }
    if (price is num) {
      return price.toDouble().toStringAsFixed(2);
    }
    return '0.00';
  }

  String _calculateTotalSpent() {
    double total = 0;
    for (var record in _maintenanceHistory) {
      final pricePaid = record['price_paid'] ?? record['price'] ?? 0;
      if (pricePaid != null && pricePaid != 0) {
        // Converter para double corretamente, tratando tanto String quanto num
        try {
          if (pricePaid is String) {
            // Remover qualquer formatação (R$, espaços, etc)
            final cleanPrice = pricePaid.replaceAll(RegExp(r'[^\d,.-]'), '').replaceAll(',', '.').trim();
            final parsed = double.tryParse(cleanPrice);
            if (parsed != null && parsed > 0) {
              total += parsed;
            }
          } else if (pricePaid is num) {
            final price = pricePaid.toDouble();
            if (price > 0) {
              total += price;
            }
          } else {
            // Tentar converter como String caso não seja nem String nem num
            final priceStr = pricePaid.toString();
            final cleanPrice = priceStr.replaceAll(RegExp(r'[^\d,.-]'), '').replaceAll(',', '.').trim();
            final parsed = double.tryParse(cleanPrice);
            if (parsed != null && parsed > 0) {
              total += parsed;
            }
          }
        } catch (e) {
          // Ignorar erros de conversão e continuar
          print('Erro ao converter preço: $pricePaid - $e');
        }
      }
    }
    return total > 0 ? 'R\$ ${total.toStringAsFixed(2)}' : 'R\$ 0,00';
  }
}
