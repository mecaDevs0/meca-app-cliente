import 'package:flutter/material.dart';

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
  bool _loading = false;
  String _error = '';

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
        setState(() {
          _workshop = result['data']?['workshop'] ?? result['data'] ?? {};
          _loading = false;
          _error = '';
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

    return CustomScrollView(
      slivers: [
        // Header melhorado com imagem da fachada
        SliverAppBar(
          expandedHeight: 250,
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
                        child: _workshop!['logo'] != null && 
                               _workshop!['logo'].isNotEmpty && 
                               _workshop!['logo'] != '' &&
                               _workshop!['logo'].startsWith('http')
                            ? Image.network(
                                _workshop!['logo'],
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
                      _workshop!['name'] ?? 'Oficina',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
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
                            '${_workshop!['rating'] ?? 4.5}',
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
            _buildInfoRow(Icons.star, 'Avaliação', '${_workshop!['rating'] ?? 4.5} ⭐'),
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
    final services = _workshop!['services'] ?? [];
    
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
            ...servicesList.map<Widget>((service) {
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
                            serviceId: service['id'],
                            workshopId: widget.workshopId,
                            serviceName: service['name'] ?? 'Serviço',
                            servicePrice: service['price']?.toString() ?? '0',
                            serviceDuration: service['duration']?.toString() ?? '',
                            workshopName: _workshop?['name'] ?? 'Oficina',
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
                                  service['name'] ?? 'Serviço',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  service['description'] ?? 'Descrição do serviço',
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (service['price'] != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00C977).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'R\$ ${service['price'].toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Color(0xFF00C977),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    if (service['duration'] != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${service['duration']} min',
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
}










