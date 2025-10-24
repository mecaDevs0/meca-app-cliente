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
          _maintenanceHistory = List<Map<String, dynamic>>.from(result['data']['maintenanceHistory'] ?? []);
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
    return Scaffold(
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
              _buildStatCard('Total Gasto', _calculateTotalSpent()),
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
    final completionDate = DateTime.tryParse(record['completion_date'] ?? '');
    final formattedDate = completionDate != null 
        ? DateFormat('dd/MM/yyyy').format(completionDate)
        : 'Data não disponível';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                    'R\$ ${(record['price_paid'] ?? 0).toStringAsFixed(2)}',
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF252940),
                  ),
                ),
                const SizedBox(height: 8),
                if (record['service_description'] != null) ...[
                  Text(
                    record['service_description'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
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
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  String _calculateTotalSpent() {
    double total = 0;
    for (var record in _maintenanceHistory) {
      total += (record['price_paid'] ?? 0).toDouble();
    }
    return 'R\$ ${total.toStringAsFixed(2)}';
  }
}
