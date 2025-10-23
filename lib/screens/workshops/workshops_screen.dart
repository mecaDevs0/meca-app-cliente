import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/api_service.dart';
import '../../widgets/meca_loading_widget.dart';
import 'workshop_detail_screen.dart';

class WorkshopsScreen extends StatefulWidget {
  const WorkshopsScreen({Key? key}) : super(key: key);

  @override
  State<WorkshopsScreen> createState() => _WorkshopsScreenState();
}

class _WorkshopsScreenState extends State<WorkshopsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _workshops = [];
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadNearbyWorkshops();
  }

  Future<void> _loadNearbyWorkshops() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    
    try {
      // Verificar se o serviço de localização está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Serviço de localização desabilitado. Por favor, ative o GPS nas configurações do dispositivo.';
          _loading = false;
        });
        return;
      }

      // Verificar permissões
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = 'Permissão de localização negada. Por favor, permita o acesso à localização nas configurações do dispositivo.';
            _loading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Permissão de localização permanentemente negada. Por favor, permita o acesso à localização nas configurações do dispositivo.';
          _loading = false;
        });
        return;
      }

      // Obter localização atual
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      final result = await _apiService.getNearbyWorkshops(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      
      if (result['success']) {
        setState(() {
          _workshops = result['data']['workshops'] ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _error = result['error'] ?? 'Erro ao carregar oficinas';
          _loading = false;
        });
      }
    } catch (e) {
      String errorMessage = 'Erro ao carregar oficinas';
      if (e.toString().contains('permission')) {
        errorMessage = 'Erro ao obter localização: Permissão de localização negada. Por favor, permita o acesso à localização nas configurações do dispositivo.';
      } else if (e.toString().contains('location')) {
        errorMessage = 'Erro ao obter localização: Não foi possível acessar sua localização atual. Verifique se o GPS está ativado.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Timeout ao obter localização. Verifique se o GPS está ativado e tente novamente.';
      } else {
        errorMessage = 'Erro ao carregar oficinas: $e';
      }
      
      setState(() {
        _error = errorMessage;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oficinas Próximas'),
        backgroundColor: const Color(0xFF00C977),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const MecaApiLoadingWidget(message: 'Buscando oficinas...')
          : _error.isNotEmpty
              ? _buildErrorView()
              : _buildWorkshopsList(),
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
              'Erro ao carregar oficinas',
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
              onPressed: _loadNearbyWorkshops,
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

  Widget _buildWorkshopsList() {
    if (_workshops.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma oficina encontrada próxima a você',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _workshops.length,
      itemBuilder: (context, index) {
        final workshop = _workshops[index];
        return _buildWorkshopCard(workshop);
      },
    );
  }

  Widget _buildWorkshopCard(Map<String, dynamic> workshop) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WorkshopDetailScreen(workshopId: workshop['id']),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: const Color(0xFF00C977).withOpacity(0.1),
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
                          workshop['name'] ?? 'Oficina',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          workshop['address'] ?? '',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${workshop['rating'] ?? 0}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.location_on,
                              color: Colors.grey,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              workshop['distance'] ?? '',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (workshop['services'] != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: (workshop['services'] as List).take(3).map((service) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C977).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        service,
                        style: const TextStyle(
                          color: Color(0xFF00C977),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}