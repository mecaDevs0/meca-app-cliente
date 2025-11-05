import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import 'booking_evidence_screen.dart';
import '../review/review_screen.dart';
import '../payment/payment_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  
  const OrderDetailScreen({Key? key, required this.booking}) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();
  Map<String, dynamic>? _bookingDetails;

  @override
  void initState() {
    super.initState();
    _loadBookingDetails();
    _checkBookingStatus();
    _setupBookingStatusListener();
  }

  Future<void> _loadBookingDetails() async {
    try {
      final result = await _apiService.getBookingDetails(widget.booking['id']?.toString() ?? '');
      
      if (mounted && result['success'] && result['data'] != null) {
        setState(() {
          _bookingDetails = result['data'];
        });
      }
    } catch (e) {
      print('Erro ao carregar detalhes do agendamento: $e');
    }
  }

  void _checkBookingStatus() {
    // Verificar se o status mudou para finalizado e redirecionar para pagamento
    final status = widget.booking['status'] ?? 'pending';
    if (status == 'finalizado' || status == 'finalizado_cliente' || status == 'completed') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _redirectToPayment();
      });
    }
  }

  void _setupBookingStatusListener() {
    // Verificar periodicamente se o status mudou para finalizado
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _pollBookingStatus();
      }
    });
  }

  Future<void> _pollBookingStatus() async {
    try {
      final bookingId = widget.booking['id']?.toString() ?? '';
      if (bookingId.isEmpty) return;
      
      final bookingResult = await _apiService.getBookingDetails(bookingId);
      
      if (bookingResult['success'] && bookingResult['data'] != null) {
        final updatedBooking = bookingResult['data'];
        
        // Garantir que updatedBooking é um Map
        if (updatedBooking is! Map<String, dynamic>) {
          print('Erro: updatedBooking não é um Map');
          return;
        }
        
        final status = (updatedBooking['status'] ?? 'pending').toString();
        final previousStatus = (widget.booking['status'] ?? 'pending').toString();
        
        // Notificar quando serviço iniciado
        if (status == 'iniciado' && previousStatus != 'iniciado') {
          await _notificationService.showServiceStarted(
            workshopName: updatedBooking['workshop_name'] ?? widget.booking['workshop_name'] ?? 'Oficina',
            serviceName: updatedBooking['service_name'] ?? widget.booking['service_name'] ?? 'Serviço',
          );
        }
        
        // Notificar quando serviço finalizado
        if ((status == 'finalizado' || status == 'finalizado_cliente' || status == 'completed') && 
            previousStatus != 'finalizado' && previousStatus != 'finalizado_cliente' && previousStatus != 'completed') {
          await _notificationService.showServiceFinished(
            workshopName: updatedBooking['workshop_name'] ?? widget.booking['workshop_name'] ?? 'Oficina',
            serviceName: updatedBooking['service_name'] ?? widget.booking['service_name'] ?? 'Serviço',
          );
        }
        
        if ((status == 'finalizado' || status == 'finalizado_cliente' || status == 'completed') && 
            widget.booking['status'] != status) {
          _redirectToPayment();
        }
      }
    } catch (e) {
      print('Erro ao verificar status do agendamento: $e');
    }
  }

  void _redirectToPayment() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          service: widget.booking['service'] ?? {
            'name': widget.booking['service_name'] ?? 'Serviço',
            'price': widget.booking['service_price'] ?? 0.0,
          },
          workshop: widget.booking['workshop'] ?? {
            'name': widget.booking['workshop_name'] ?? 'Oficina',
            'accepts_installment': widget.booking['workshop_accepts_installment'] ?? false,
          },
          booking: widget.booking,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.booking['status'] ?? 'pending';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final canCancel = status == 'pending' || status == 'confirmed';

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F0F0F) : Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : const Color(0xFF252940),
        title: const Text(
          'Detalhes do Agendamento',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : const Color(0xFF252940)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getStatusGradient(status),
                ),
              ),
              child: Column(
                children: [
                  Icon(_getStatusIcon(status), color: Colors.white, size: 50),
                  const SizedBox(height: 10),
                  Text(
                    _getStatusText(status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Pedido #${widget.booking['id']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Workshop Info
                  _buildSection(
                    'Oficina',
                    [
                      // Logo e Nome da Oficina
                      if (_bookingDetails?['workshop_logo_url'] != null || widget.booking['workshop_logo_url'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  (_bookingDetails?['workshop_logo_url'] ?? widget.booking['workshop_logo_url'] ?? '').toString(),
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00C977).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.build, color: Color(0xFF00C977)),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (_bookingDetails?['workshop_name'] ?? widget.booking['workshop_name'] ?? 'Oficina').toString(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    if (_bookingDetails?['workshop_rating'] != null)
                                      Row(
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            (_bookingDetails?['workshop_rating'] ?? 0).toString(),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                                            ),
                                          ),
                                          if (_bookingDetails?['workshop_total_reviews'] != null)
                                            Text(
                                              ' (${_bookingDetails?['workshop_total_reviews']} avaliações)',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                              ),
                                            ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      _buildInfoRow(
                        Icons.build_circle, 
                        (_bookingDetails?['workshop_name'] ?? widget.booking['workshop_name'] ?? 'Oficina').toString()
                      ),
                      
                      // Componente de Mapa
                      if ((_bookingDetails?['latitude'] ?? widget.booking['latitude']) != null &&
                          (_bookingDetails?['longitude'] ?? widget.booking['longitude']) != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: GestureDetector(
                            onTap: () => _showMapOptionsDialog(
                              _bookingDetails?['latitude'] ?? widget.booking['latitude'],
                              _bookingDetails?['longitude'] ?? widget.booking['longitude'],
                            ),
                            child: Container(
                              height: 180,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF00C977),
                                  width: 2,
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDarkMode
                                      ? [
                                          const Color(0xFF1E1E1E),
                                          const Color(0xFF2A2A2A),
                                        ]
                                      : [
                                          const Color(0xFFF5F5F5),
                                          const Color(0xFFE8E8E8),
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00C977).withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // Visualização do mapa
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            const Color(0xFF00C977).withOpacity(0.1),
                                            const Color(0xFF00B369).withOpacity(0.05),
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF00C977).withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.location_on,
                                                size: 48,
                                                color: Color(0xFF00C977),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Localização da Oficina',
                                              style: TextStyle(
                                                color: isDarkMode ? Colors.white : Colors.black87,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Toque para abrir no Waze ou Maps',
                                              style: TextStyle(
                                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Botão de ação
                                  Positioned(
                                    bottom: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00C977),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF00C977).withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.navigation,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Abrir',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
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
                      
                      _buildLocationRow(
                        Icons.location_on, 
                        (_bookingDetails?['workshop_address'] ?? widget.booking['workshop_address'] ?? 'Endereço não informado').toString(),
                        _bookingDetails?['latitude'] ?? widget.booking['latitude'],
                        _bookingDetails?['longitude'] ?? widget.booking['longitude'],
                      ),
                      
                      if (_bookingDetails?['workshop_city'] != null || _bookingDetails?['workshop_state'] != null)
                        _buildInfoRow(
                          Icons.location_city,
                          '${_bookingDetails?['workshop_city'] ?? ''}, ${_bookingDetails?['workshop_state'] ?? ''}'.replaceAll(RegExp(r'^,\s*|,\s*$'), ''),
                        ),
                      
                      _buildInfoRow(
                        Icons.phone, 
                        (_bookingDetails?['workshop_phone'] ?? widget.booking['workshop_phone'] ?? 'Telefone não informado').toString()
                      ),
                      
                      if (_bookingDetails?['workshop_email'] != null)
                        _buildInfoRow(
                          Icons.email,
                          (_bookingDetails?['workshop_email'] ?? '').toString(),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Date & Time
                  _buildSection(
                    'Data e Horário',
                    [
                      _buildInfoRow(
                        Icons.calendar_today,
                        widget.booking['appointment_date'] != null
                            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.booking['appointment_date']))
                            : (widget.booking['scheduled_date'] != null
                                ? DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.booking['scheduled_date']))
                                : 'Data não definida'),
                      ),
                      _buildInfoRow(
                        Icons.access_time, 
                        widget.booking['appointment_date'] != null
                            ? DateFormat('HH:mm').format(DateTime.parse(widget.booking['appointment_date']))
                            : (widget.booking['scheduled_time'] ?? '00:00'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Vehicle Info
                  _buildSection(
                    'Veículo',
                    [
                      _buildInfoRow(
                        Icons.directions_car,
                        '${widget.booking['vehicle_brand'] ?? widget.booking['brand'] ?? ''} ${widget.booking['vehicle_model'] ?? widget.booking['model'] ?? ''}'.trim(),
                      ),
                      _buildInfoRow(
                        Icons.pin, 
                        widget.booking['vehicle_plate'] ?? widget.booking['plate'] ?? 'ABC-1234',
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Services
                  Text(
                    'Serviço',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : const Color(0xFF252940),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Builder(
                    builder: (context) {
                      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                      
                      // Verificar se há um serviço na resposta (priorizar dados carregados)
                      final serviceName = (_bookingDetails?['service_name'] ?? widget.booking['service_name'] ?? widget.booking['product_id'] ?? 'Serviço').toString();
                      final servicePrice = _bookingDetails?['service_price'] ?? widget.booking['service_price'] ?? 0;
                      final serviceDuration = _bookingDetails?['service_duration'] ?? widget.booking['service_duration'] ?? 0;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C977).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.build, color: Color(0xFF00C977), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      serviceName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    if (serviceDuration != null && serviceDuration > 0)
                                      Text(
                                        '$serviceDuration minutos',
                                        style: TextStyle(
                                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            if (servicePrice != null && servicePrice > 0)
                              Text(
                                'R\$ ${(servicePrice / 100).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF00C977),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Total - Só exibir se houver preço e tempo disponíveis
                  if (_shouldShowPrice(widget.booking)) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C977), Color(0xFF00B369)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'R\$ ${_formatPrice(widget.booking)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (widget.booking['notes'] != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Observações',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFF252940),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        widget.booking['notes'],
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Botões de ação conforme o fluxo
            _buildActionButtons(status),
          ],
        ),
      ),
      bottomNavigationBar: canCancel
          ? Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => _cancelBooking(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Cancelar Agendamento',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF252940),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00C977), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String text, dynamic latitude, dynamic longitude) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hasLocation = latitude != null && longitude != null;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: hasLocation ? () => _openLocation(latitude, longitude) : null,
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF00C977), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: hasLocation 
                      ? const Color(0xFF00C977) 
                      : (isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                  fontSize: 15,
                  decoration: hasLocation ? TextDecoration.underline : null,
                ),
              ),
            ),
            if (hasLocation)
              const Icon(
                Icons.open_in_new,
                color: Color(0xFF00C977),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  void _showMapOptionsDialog(dynamic latitude, dynamic longitude) async {
    final lat = latitude is String ? double.tryParse(latitude) : (latitude is num ? latitude.toDouble() : null);
    final lng = longitude is String ? double.tryParse(longitude) : (longitude is num ? longitude.toDouble() : null);
    
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coordenadas inválidas'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Abrir Localização',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Escolha como deseja abrir a localização da oficina:',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        actions: [
          // Botão Waze
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _openInWaze(lat, lng);
            },
            icon: const Icon(Icons.navigation, color: Color(0xFF00C977)),
            label: const Text(
              'Waze',
              style: TextStyle(
                color: Color(0xFF00C977),
                fontWeight: FontWeight.bold,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFF00C977), width: 1.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Botão Google Maps
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _openInGoogleMaps(lat, lng);
            },
            icon: const Icon(Icons.map, color: Colors.white),
            label: const Text(
              'Google Maps',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C977),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInWaze(double lat, double lng) async {
    try {
      // Waze URL scheme: waze://?ll=latitude,longitude&navigate=yes
      final wazeUrl = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
      final wazeFallbackUrl = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
      
      if (await canLaunchUrl(wazeUrl)) {
        await launchUrl(wazeUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(wazeFallbackUrl)) {
        await launchUrl(wazeFallbackUrl, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Waze não está instalado. Abrindo no Google Maps...'),
            backgroundColor: Colors.orange,
          ),
        );
        await _openInGoogleMaps(lat, lng);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao abrir no Waze: $e'),
          backgroundColor: Colors.red,
        ),
      );
      await _openInGoogleMaps(lat, lng);
    }
  }

  Future<void> _openInGoogleMaps(double lat, double lng) async {
    try {
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o Google Maps'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao abrir no Google Maps: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openLocation(dynamic latitude, dynamic longitude) {
    // Mantido para compatibilidade com _buildLocationRow
    _showMapOptionsDialog(latitude, longitude);
  }

  List<Color> _getStatusGradient(String status) {
    switch (status) {
      case 'confirmed':
        return [const Color(0xFF7896D8), const Color(0xFF5C7BC4)];
      case 'in_progress':
        return [const Color(0xFF00C977), const Color(0xFF00B369)];
      case 'completed':
        return [const Color(0xFF2FD65C), const Color(0xFF1FC04D)];
      case 'cancelled':
        return [const Color(0xFFE8867C), const Color(0xFFD8766C)];
      default:
        return [const Color(0xFFDBA800), const Color(0xFFC99800)];
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'confirmed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.build_circle;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmado';
      case 'in_progress':
        return 'Em Andamento';
      case 'completed':
        return 'Concluído';
      case 'cancelled':
        return 'Cancelado';
      default:
        return 'Aguardando Confirmação';
    }
  }

  Future<void> _cancelBooking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Agendamento'),
        content: const Text('Tem certeza que deseja cancelar este agendamento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Não'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sim, Cancelar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _apiService.cancelBooking(widget.booking['id']);
      
      if (result['success']) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agendamento cancelado com sucesso'),
            backgroundColor: Color(0xFF00C977),
          ),
        );
      }
    }
  }

  Widget _buildActionButtons(String status) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          
          // Botão "Ver Provas" - quando status = "completed" ou "in_progress"
          if (status == 'completed' || status == 'in_progress') ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _viewEvidence,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Ver Provas da Oficina'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00C977)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Botão "Avaliar Serviço" - quando status = "completed"
          if (status == 'completed') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _rateService,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C977),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Avaliar Serviço',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Botão de Lembretes - quando status é confirmado ou pendente e tem data futura
          if (_shouldShowReminderButton()) ...[
            Builder(
              builder: (context) {
                final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: (_bookingDetails?['reminder_enabled'] ?? widget.booking['reminder_enabled'] == true)
                          ? [const Color(0xFF00C977), const Color(0xFF00B369)]
                          : [
                              isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8),
                              isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFD0D0D0),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_bookingDetails?['reminder_enabled'] ?? widget.booking['reminder_enabled'] == true)
                          ? const Color(0xFF00C977)
                          : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                      width: 1.5,
                    ),
                    boxShadow: (_bookingDetails?['reminder_enabled'] ?? widget.booking['reminder_enabled'] == true)
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00C977).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _toggleReminder(!((_bookingDetails?['reminder_enabled'] ?? widget.booking['reminder_enabled']) == true)),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          (_bookingDetails?['reminder_enabled'] ?? widget.booking['reminder_enabled'] == true)
                              ? Icons.notifications_active 
                              : Icons.notifications_off,
                          color: (_bookingDetails?['reminder_enabled'] ?? widget.booking['reminder_enabled'] == true)
                              ? Colors.white
                              : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (_bookingDetails?['reminder_enabled'] ?? widget.booking['reminder_enabled'] == true)
                                    ? 'Lembretes Ativados'
                                    : 'Ativar Lembretes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: (_bookingDetails?['reminder_enabled'] ?? widget.booking['reminder_enabled'] == true)
                                      ? Colors.white
                                      : (isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (_bookingDetails?['reminder_enabled'] ?? widget.booking['reminder_enabled'] == true)
                                    ? 'Você receberá notificações 1 dia antes, no dia e 1 hora antes'
                                    : 'Receba notificações 1 dia antes, no dia e 1 hora antes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: (_bookingDetails?['reminder_enabled'] ?? widget.booking['reminder_enabled'] == true)
                                      ? Colors.white.withOpacity(0.9)
                                      : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          (_bookingDetails?['reminder_enabled'] ?? widget.booking['reminder_enabled'] == true)
                              ? Icons.toggle_on
                              : Icons.toggle_off,
                          color: (_bookingDetails?['reminder_enabled'] ?? widget.booking['reminder_enabled'] == true)
                              ? Colors.white
                              : (isDarkMode ? Colors.grey[500] : Colors.grey[400]),
                          size: 32,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }


  Future<void> _rateService() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewScreen(
          bookingId: widget.booking['id'],
          workshopId: widget.booking['workshop_id'] ?? widget.booking['oficina_id'] ?? '',
        ),
      ),
    ).then((result) async {
      if (result == true) {
        // Recarregar dados do agendamento
        if (mounted) {
          setState(() {
            // Forçar rebuild para atualizar UI
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avaliação enviada com sucesso!'),
            backgroundColor: Color(0xFF00C977),
          ),
        );
      }
    });
  }


  Future<void> _viewEvidence() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingEvidenceScreen(
          bookingId: widget.booking['id'],
          booking: widget.booking,
        ),
      ),
    );
  }

  bool _shouldShowPrice(Map<String, dynamic> booking) {
    // Só exibir preço se a oficina forneceu tempo E preço (não null, não vazio, não 0)
    final price = booking['service_price'] ?? booking['total'] ?? booking['estimated_price'] ?? 0;
    final hasPrice = price != null && price != 0 && price.toString().trim().isNotEmpty;
    
    final duration = booking['service_duration'] ?? booking['duration'] ?? booking['duration_minutes'] ?? 0;
    final hasDuration = duration != null && duration != 0 && duration.toString().trim().isNotEmpty;
    
    return hasPrice && hasDuration;
  }

  String _formatPrice(Map<String, dynamic> booking) {
    final price = booking['total'] ?? 
                  booking['service_price'] ?? 
                  booking['estimated_price'] ?? 
                  0;
    
    // Se o preço está em centavos (valor muito alto), dividir por 100
    if (price is int && price > 10000) {
      return (price / 100).toStringAsFixed(2);
    }
    
    // Se o preço está como String, converter
    if (price is String) {
      final parsed = double.tryParse(price);
      return parsed?.toStringAsFixed(2) ?? '0.00';
    }
    
    // Se já está em formato double
    if (price is num) {
      return price.toDouble().toStringAsFixed(2);
    }
    
    return '0.00';
  }

  bool _shouldShowReminderButton() {
    // Só mostrar se o agendamento está confirmado ou pendente e tem data futura
    final status = widget.booking['status'] ?? '';
    final isConfirmedOrPending = status == 'confirmado' || 
                                 status == 'confirmed' || 
                                 status == 'confirmado_oficina' ||
                                 status == 'pendente_oficina';
    
    if (!isConfirmedOrPending) return false;
    
    final appointmentDate = widget.booking['appointment_date'] ?? widget.booking['scheduled_date'];
    if (appointmentDate == null) return false;
    
    try {
      final date = DateTime.parse(appointmentDate);
      return date.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  Future<void> _toggleReminder(bool enabled) async {
    try {
      final bookingId = widget.booking['id']?.toString() ?? '';
      if (bookingId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ID do agendamento não encontrado'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final result = await _apiService.toggleBookingReminder(bookingId, enabled);
      
      if (result['success']) {
        setState(() {
          _bookingDetails = _bookingDetails ?? {};
          _bookingDetails!['reminder_enabled'] = enabled;
          widget.booking['reminder_enabled'] = enabled;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Lembretes ativados! Você receberá notificações 1 dia antes, no dia e 1 hora antes do agendamento.'
                  : 'Lembretes desativados',
            ),
            backgroundColor: const Color(0xFF00C977),
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Se ativou, agendar as notificações locais também
        if (enabled) {
          final appointmentDateStr = _bookingDetails?['appointment_date'] ?? 
                                    widget.booking['appointment_date'] ?? 
                                    widget.booking['scheduled_date'] ?? '';
          
          if (appointmentDateStr.isNotEmpty) {
            final appointmentDate = DateTime.tryParse(appointmentDateStr);
            
            if (appointmentDate != null) {
              await _notificationService.scheduleBookingReminders(
                workshopName: _bookingDetails?['workshop_name'] ?? 
                             widget.booking['workshop_name'] ?? 
                             widget.booking['workshop']?['name'] ?? 
                             'Oficina',
                serviceName: _bookingDetails?['service_name'] ?? 
                           widget.booking['service_name'] ?? 
                           widget.booking['service']?['name'] ?? 
                           'Serviço',
                scheduledDate: appointmentDate,
              );
            }
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Erro ao atualizar lembretes'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar lembretes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
