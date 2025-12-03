import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../utils/price_utils.dart';
import '../../widgets/app_alerts.dart';
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
  bool _paymentPromptDisplayed = false;
  bool _isLoadingDetails = false;

  List<Map<String, dynamic>> _coerceUploads(dynamic raw) {
    if (raw == null) return const [];

    if (raw is List) {
      return raw.whereType<Object>().map<Map<String, dynamic>>((item) {
        if (item is Map<String, dynamic>) {
          return Map<String, dynamic>.from(item);
        }
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
        return <String, dynamic>{};
      }).where((item) => item.isNotEmpty).toList();
    }

    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        return _coerceUploads(decoded);
      } catch (_) {
        return const [];
      }
    }

    return const [];
  }

  List<Map<String, dynamic>> _getCustomerUploads() {
    final primary = _bookingDetails?['customer_uploads'] ?? _bookingDetails?['customerUploads'];
    final fallback = widget.booking['customer_uploads'] ?? widget.booking['customerUploads'];
    final uploads = _coerceUploads(primary);
    if (uploads.isNotEmpty) {
      return uploads;
    }
    return _coerceUploads(fallback);
  }

  Map<String, dynamic> _mergeBookingData([Map<String, dynamic>? overrides]) {
    final combined = <String, dynamic>{};
    combined.addAll(widget.booking);
    if (_bookingDetails != null) {
      combined.addAll(_bookingDetails!);
    }
    if (overrides != null) {
      combined.addAll(overrides);
    }
    return combined;
  }

  double? _resolveServiceAmount(Map<String, dynamic> bookingData) {
    final candidates = [
      bookingData['service_price'],
      bookingData['service']?['price'],
      bookingData['price'],
      bookingData['estimated_price'],
      bookingData['estimatedPrice'],
    ];
    for (final candidate in candidates) {
      final price = PriceUtils.extractPrice(candidate);
      if (price != null) return price;
    }
    return null;
  }

  double? _resolveTotalAmount(Map<String, dynamic> bookingData) {
    final confirmedQuote = _extractFinalPriceFromMap(bookingData);
    if (confirmedQuote != null) {
      return confirmedQuote;
    }

    final fallbackCandidates = [
      bookingData['total_amount'],
      bookingData['total'],
      bookingData['service_price'],
      bookingData['service']?['price'],
      bookingData['estimated_price'],
      bookingData['estimatedPrice'],
    ];
    for (final candidate in fallbackCandidates) {
      final price = PriceUtils.extractPrice(candidate);
      if (price != null) return price;
    }
    return null;
  }

  bool _isPaymentPendingStatus(String status) {
    final normalized = status.toLowerCase();
    return normalized == 'finalizado' ||
        normalized == 'finalizado_cliente' ||
        normalized == 'completed' ||
        normalized == 'finalizado_aguardando_pagamento';
  }

  Future<void> _showPaymentPrompt(Map<String, dynamic> bookingData) async {
    if (_paymentPromptDisplayed || !mounted) {
      return;
    }
    _paymentPromptDisplayed = true;

    final totalAmount = _resolveTotalAmount(bookingData);
    final serviceName = bookingData['service_name'] ?? bookingData['service']?['name'] ?? 'Serviço';
    final workshopName = bookingData['workshop_name'] ?? bookingData['workshop']?['name'] ?? 'Oficina';

    await Future<void>.delayed(Duration.zero);

    if (!mounted) return;

    final shouldProceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text('Serviço finalizado'),
              content: Text(
                [
                  'A oficina "$workshopName" sinalizou que o serviço "$serviceName" foi concluído.',
                  if (totalAmount != null)
                    'Valor informado: R\$ ${totalAmount.toStringAsFixed(2)}.',
                  'Confirme para seguir com o pagamento agora.'
                ].join('\n\n'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Fazer depois'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Pagar agora'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!mounted) return;

    if (shouldProceed) {
      _redirectToPayment(bookingData: bookingData);
    }
  }

  void _openUploadPreview(Map<String, dynamic> upload) {
    final url = upload['url']?.toString();
    if (url == null || url.isEmpty) return;

    final fileName = upload['file_name']?.toString() ?? 'Foto do agendamento';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InteractiveViewer(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.black,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image, color: Colors.white, size: 40),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      fileName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Se recebeu apenas ID (vindo de notificação), carregar dados primeiro
    if (widget.booking.containsKey('id') && widget.booking.length == 1) {
      _loadBookingDetailsFromId();
    } else {
      _loadBookingDetails();
    }
    _checkBookingStatus();
    _setupBookingStatusListener();
  }

  Future<void> _loadBookingDetailsFromId() async {
    if (_isLoadingDetails) return;
    
    setState(() {
      _isLoadingDetails = true;
    });

    try {
      final bookingId = widget.booking['id']?.toString() ?? '';
      if (bookingId.isEmpty) {
        debugPrint('Erro: ID do agendamento não encontrado');
        if (mounted) {
          setState(() {
            _isLoadingDetails = false;
          });
          AppAlerts.showError(
            context,
            message: 'ID do agendamento não encontrado.',
          );
        }
        return;
      }

      final result = await _apiService.getBookingDetails(bookingId);

      if (!mounted) return;

      if (result['success'] && result['data'] != null) {
        final details = Map<String, dynamic>.from(result['data'] as Map);
        setState(() {
          _bookingDetails = details;
          _isLoadingDetails = false;
          // Atualizar widget.booking com todos os dados carregados
          widget.booking.clear();
          widget.booking.addAll(details);
        });
        // Verificar status após carregar dados
        _checkBookingStatus();
        // Forçar rebuild para atualizar botões de ação
        if (mounted) {
          setState(() {});
        }
      } else {
        debugPrint('Erro ao carregar detalhes: ${result['error']}');
        if (mounted) {
          setState(() {
            _isLoadingDetails = false;
          });
          AppAlerts.showError(
            context,
            message: result['error'] ?? 'Erro ao carregar detalhes do agendamento.',
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar detalhes do agendamento: $e');
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
        AppAlerts.showError(
          context,
          message: 'Erro ao carregar detalhes do agendamento.',
        );
      }
    }
  }

  Future<void> _loadBookingDetails() async {
    try {
      final bookingId = widget.booking['id']?.toString() ?? '';
      if (bookingId.isEmpty) {
        debugPrint('Erro: ID do agendamento não encontrado');
        return;
      }

      final result = await _apiService.getBookingDetails(bookingId);

      if (!mounted) return;

      if (result['success'] && result['data'] != null) {
        final details = Map<String, dynamic>.from(result['data'] as Map);
        setState(() {
          _bookingDetails = details;
          widget.booking.addAll(details);
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar detalhes do agendamento: $e');
    }
  }

  void _checkBookingStatus() {
    final status = (widget.booking['status'] ?? 'pending').toString();
    if (_isPaymentPendingStatus(status)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPaymentPrompt(_mergeBookingData());
      });
    }
  }

  void _setupBookingStatusListener() {
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
        if (updatedBooking is! Map<String, dynamic>) {
          debugPrint('Erro: updatedBooking não é um Map');
          return;
        }

        final status = (updatedBooking['status'] ?? 'pending').toString();
        final previousStatus = (widget.booking['status'] ?? 'pending').toString();

        if (status == 'iniciado' && previousStatus != 'iniciado') {
          await _notificationService.showServiceStarted(
            workshopName: updatedBooking['workshop_name'] ?? widget.booking['workshop_name'] ?? 'Oficina',
            serviceName: updatedBooking['service_name'] ?? widget.booking['service_name'] ?? 'Serviço',
          );
        }

        final normalizedBooking = Map<String, dynamic>.from(updatedBooking);
        normalizedBooking['status'] = status;

        widget.booking.addAll(normalizedBooking);
        setState(() {
          _bookingDetails = _bookingDetails == null
              ? normalizedBooking
              : {
                  ..._bookingDetails!,
                  ...normalizedBooking,
                };
        });

        final isCompleted = _isPaymentPendingStatus(status);
        final wasCompleted = _isPaymentPendingStatus(previousStatus);

        if (isCompleted && !wasCompleted) {
          await _notificationService.showServiceFinished(
            workshopName: normalizedBooking['workshop_name'] ?? widget.booking['workshop_name'] ?? 'Oficina',
            serviceName: normalizedBooking['service_name'] ?? widget.booking['service_name'] ?? 'Serviço',
            bookingId: normalizedBooking['id']?.toString() ?? widget.booking['id']?.toString(),
          );
          _showPaymentPrompt(_mergeBookingData(normalizedBooking));
        }
      }
    } catch (e) {
      debugPrint('Erro ao verificar status do agendamento: $e');
    }
  }

  Future<void> _redirectToPayment({Map<String, dynamic>? bookingData}) async {
    final mergedBooking = _mergeBookingData(bookingData);
    final double? finalQuote = _extractFinalPrice();
    final double? fallbackAmount = _resolveTotalAmount(mergedBooking) ?? _resolveServiceAmount(mergedBooking);
    final double? paymentAmount = finalQuote ?? fallbackAmount;

    if (paymentAmount == null) {
      if (!mounted) return;
      AppAlerts.showWarning(
        context,
        title: 'Valor indisponível',
        message: 'A oficina ainda não informou o valor final deste serviço.',
      );
      return;
    }
    final double serviceAmount = paymentAmount;

    final workshopData = Map<String, dynamic>.from(
      (mergedBooking['workshop'] as Map?) ??
          {
            'name': mergedBooking['workshop_name'] ?? 'Oficina',
          },
    );
    workshopData['name'] = workshopData['name'] ?? mergedBooking['workshop_name'] ?? 'Oficina';
    workshopData['accepts_installment'] = workshopData['accepts_installment'] ??
        mergedBooking['workshop_accepts_installment'] ??
        false;

    final serviceData = Map<String, dynamic>.from(
      (mergedBooking['service'] as Map?) ??
          {
            'name': mergedBooking['service_name'] ?? 'Serviço',
          },
    );
    serviceData['name'] = serviceData['name'] ?? mergedBooking['service_name'] ?? 'Serviço';
    serviceData['price'] = serviceAmount;

    final updatedBooking = Map<String, dynamic>.from(mergedBooking);
    updatedBooking['total'] = paymentAmount;
    updatedBooking['final_amount'] = paymentAmount;
    updatedBooking['final_price'] = (paymentAmount * 100).round();

    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          service: serviceData,
          workshop: workshopData,
          booking: updatedBooking,
        ),
      ),
    );

    if (paid == true) {
      _paymentPromptDisplayed = false;
      await _pollBookingStatus();
      if (!mounted) return;
      AppAlerts.showSuccess(
        context,
        message: 'Pagamento registrado! Obrigado por usar o MECA.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se está carregando dados (vindo de notificação), mostrar loading
    if (_isLoadingDetails) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F0F0F) : Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
          foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF252940),
          title: const Text(
            'Detalhes do Agendamento',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Usar status dos dados carregados ou do widget.booking
    final merged = _mergeBookingData();
    final status = merged['status']?.toString() ?? widget.booking['status']?.toString() ?? 'pending';
    final normalizedStatus = _normalizeStatusKey(status);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final canCancel = normalizedStatus == 'pending' || normalizedStatus == 'pending_customer' || normalizedStatus == 'confirmed';
    final customerUploads = _getCustomerUploads();
    final bookingNotes = (_bookingDetails?['customer_notes'] ??
            _bookingDetails?['notes'] ??
            widget.booking['notes'] ??
            widget.booking['customer_notes'])
        ?.toString();

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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _getStatusGradient(status)),
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
            // Card informativo sobre situação atual e próximos passos
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _buildStatusInfoCard(status, normalizedStatus),
            ),
            if (_shouldShowReminderButton())
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _buildReminderCard(),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    'Oficina',
                    [
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
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00C977).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.build, color: Color(0xFF00C977)),
                                  ),
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
                        (_bookingDetails?['workshop_name'] ?? widget.booking['workshop_name'] ?? 'Oficina').toString(),
                      ),
                  _buildWorkshopMapCard(isDarkMode),
                      Builder(
                        builder: (context) {
                          final workshop = _bookingDetails?['workshop'] ?? widget.booking['workshop'];
                          return _buildLocationRow(
                        Icons.location_on,
                        _formatWorkshopAddress(_bookingDetails?['workshop_address'] ?? widget.booking['workshop_address']),
                            workshop?['latitude'] ?? _bookingDetails?['latitude'] ?? widget.booking['latitude'],
                            workshop?['longitude'] ?? _bookingDetails?['longitude'] ?? widget.booking['longitude'],
                          );
                        },
                      ),
                      if (_bookingDetails?['workshop_city'] != null || _bookingDetails?['workshop_state'] != null)
                        _buildInfoRow(
                          Icons.location_city,
                          '${_bookingDetails?['workshop_city'] ?? ''}, ${_bookingDetails?['workshop_state'] ?? ''}'
                              .replaceAll(RegExp(r'^,\s*|,\s*$'), ''),
                        ),
                      _buildInfoRow(
                        Icons.phone,
                        (_bookingDetails?['workshop_phone'] ?? widget.booking['workshop_phone'] ?? 'Telefone não informado').toString(),
                      ),
                      if (_bookingDetails?['workshop_email'] != null)
                        _buildInfoRow(
                          Icons.email,
                          (_bookingDetails?['workshop_email'] ?? '').toString(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                  _buildSection(
                    'Veículo',
                    [
                      _buildInfoRow(
                        Icons.directions_car,
                        '${widget.booking['vehicle_brand'] ?? widget.booking['brand'] ?? ''} '
                                '${widget.booking['vehicle_model'] ?? widget.booking['model'] ?? ''}'
                            .trim(),
                      ),
                      _buildInfoRow(
                        Icons.pin,
                        widget.booking['vehicle_plate'] ?? widget.booking['plate'] ?? 'ABC-1234',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                      final serviceName =
                          (_bookingDetails?['service_name'] ?? widget.booking['service_name'] ?? widget.booking['product_id'] ?? 'Serviço')
                              .toString();
                      // Removido: cálculo de servicePriceLabel
                      // O preço total já é exibido no card "Total" abaixo

                      final serviceDurationRaw = _bookingDetails?['service_duration'] ?? widget.booking['service_duration'];
                      double? serviceDuration;
                      if (serviceDurationRaw is num) {
                        serviceDuration = serviceDurationRaw.toDouble();
                      } else if (serviceDurationRaw is String) {
                        serviceDuration = double.tryParse(serviceDurationRaw);
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Row(
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
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          serviceName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDarkMode ? Colors.white : Colors.black,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (serviceDuration != null && serviceDuration > 0)
                                          Text(
                                            '${serviceDuration.toStringAsFixed(serviceDuration % 1 == 0 ? 0 : 1)} minutos',
                                            style: TextStyle(
                                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Removido: exibição de preço no card de serviço
                            // O preço total já é exibido no card "Total" abaixo
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_shouldShowEstimateNotice()) ...[
                    _buildEstimateInfoCard(isDarkMode),
                    const SizedBox(height: 16),
                  ],
                  if (_shouldShowPrice()) ...[
                    _buildQuoteCard(isDarkMode),
                  ],
                  if (bookingNotes != null && bookingNotes.isNotEmpty) ...[
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
                        bookingNotes,
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                  if (customerUploads.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Fotos enviadas por você',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFF252940),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: customerUploads.map((upload) {
                        final url = upload['url']?.toString();
                        if (url == null || url.isEmpty) return const SizedBox.shrink();
                        return GestureDetector(
                          onTap: () => _openUploadPreview(upload),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 90,
                              height: 90,
                              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey.shade300,
                                  alignment: Alignment.center,
                                  child: Icon(Icons.broken_image, color: Colors.grey.shade600),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            _buildActionButtons(status),
          ],
        ),
      ),
      bottomNavigationBar: canCancel
          ? Builder(
              builder: (context) {
                final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _cancelBooking,
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
                );
              },
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

  Widget _buildQuoteCard(bool isDarkMode) {
    final quoteValue = _extractFinalPrice();
    if (quoteValue == null) return const SizedBox.shrink();

    final merged = _mergeBookingData();
    final status = (merged['status'] ?? widget.booking['status'] ?? '').toString();
    final normalizedStatus = _normalizeStatusKey(status);
    final hasCompletedAt = merged['completed_at'] != null || widget.booking['completed_at'] != null;
    final quoteStatus = merged['quote_status'] ?? widget.booking['quote_status'];
    final isFinalQuote = quoteStatus == 'final';
    
    // Buscar items do orçamento
    final quoteItemsRaw = merged['quote_items'] ?? widget.booking['quote_items'];
    final quoteItems = quoteItemsRaw is List ? quoteItemsRaw : null;
    final diagnosticValue = merged['diagnostic_value'] ?? widget.booking['diagnostic_value'];
    final hasDetailedQuote = quoteItems != null && quoteItems.isNotEmpty;

    String title;
    String subtitle;

    if (normalizedStatus == 'awaiting_payment') {
      title = isFinalQuote ? 'Orçamento Final' : 'Orçamento aprovado';
      subtitle = isFinalQuote 
          ? 'Valor final após conclusão do serviço. Realize o pagamento.'
          : 'Finalize o pagamento para concluir o serviço.';
    } else if (hasCompletedAt) {
      title = 'Orçamento final da oficina';
      subtitle = 'Valor definido após o término do serviço.';
    } else {
      title = 'Orçamento aprovado';
      subtitle = 'A oficina iniciará o serviço com este valor.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C977), Color(0xFF00B369)],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatPriceLabel() ?? '—',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
            ),
          ),
          
          // Mostrar breakdown detalhado se houver items
          if (hasDetailedQuote) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detalhamento do Orçamento',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Items do orçamento
                  ...List<Widget>.from(quoteItems.map<Widget>((item) {
                    final description = item['description'] ?? '';
                    final quantity = item['quantity'] ?? 1;
                    final unitPrice = (item['unit_price'] ?? 0) / 100.0;
                    final totalItem = unitPrice * quantity;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  description,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (quantity > 1)
                                  Text(
                                    'Qtd: $quantity × ${PriceUtils.formatCurrency(unitPrice)}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            PriceUtils.formatCurrency(totalItem) ?? 'R\$ 0,00',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  })),
                  
                  // Valor do diagnóstico (se houver)
                  if (diagnosticValue != null && diagnosticValue > 0) ...[
                    const Divider(color: Colors.white38, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Diagnóstico',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          PriceUtils.formatCurrency(diagnosticValue / 100) ?? 'R\$ 0,00',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  const Divider(color: Colors.white38, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatPriceLabel() ?? '—',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkshopMapCard(bool isDarkMode) {
    // Buscar latitude/longitude de múltiplas fontes: workshop object, bookingDetails, ou booking direto
    final workshop = _bookingDetails?['workshop'] ?? widget.booking['workshop'];
    final lat = _parseCoordinate(
      workshop?['latitude'] ?? 
      _bookingDetails?['latitude'] ?? 
      widget.booking['latitude']
    );
    final lng = _parseCoordinate(
      workshop?['longitude'] ?? 
      _bookingDetails?['longitude'] ?? 
      widget.booking['longitude']
    );
    final hasCoords = lat != null && lng != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: hasCoords ? () => _showMapOptionsDialog(lat, lng) : null,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00C977), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00C977).withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: hasCoords
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(lat, lng),
                            zoom: 15.0,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('workshopLocation'),
                              position: LatLng(lat, lng),
                              infoWindow: InfoWindow(
                                title: _bookingDetails?['workshop_name'] ?? widget.booking['workshop_name'] ?? 'Oficina',
                              ),
                              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                            ),
                          },
                          mapType: MapType.normal,
                          myLocationEnabled: false,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                          onMapCreated: (GoogleMapController controller) {
                            print('🗺️ [OrderDetail] Mapa interativo criado com sucesso!');
                          },
                        ),
                      )
                    : _buildMapPlaceholder(isDarkMode),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.85),
                        Colors.black.withOpacity(0.0),
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Localização da Oficina',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasCoords ? 'Toque para abrir no Waze ou Google Maps' : 'Coordenadas indisponíveis',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: hasCoords ? () => _showMapOptionsDialog(lat, lng) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C977),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.directions, size: 16),
                        label: const Text(
                          'Abrir',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
    );
  }

  Widget _buildMapPlaceholder(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [const Color(0xFF1E1E1E), const Color(0xFF2A2A2A)]
              : [const Color(0xFFF5F5F5), const Color(0xFFE8E8E8)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mapa indisponível',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
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
          ],
        ),
      ),
    );
  }

  double? _parseCoordinate(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      final parsed = value.toDouble();
      if (parsed != 0.0 && !parsed.isNaN && parsed.isFinite) return parsed;
    return null;
  }
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
                  color: hasLocation ? const Color(0xFF00C977) : (isDarkMode ? Colors.grey[300] : Colors.grey[700]),
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
      if (!mounted) return;
      AppAlerts.showError(
        context,
        message: 'Não encontramos as coordenadas da oficina. Tente novamente mais tarde.',
      );
      return;
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Abrir Localização',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Escolha como deseja abrir a localização da oficina:',
          style: TextStyle(color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _openInWaze(lat, lng);
            },
            icon: const Icon(Icons.navigation, color: Color(0xFF00C977)),
            label: const Text(
              'Waze',
              style: TextStyle(color: Color(0xFF00C977), fontWeight: FontWeight.bold),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFF00C977), width: 1.5),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _openInGoogleMaps(lat, lng);
            },
            icon: const Icon(Icons.map, color: Colors.white),
            label: const Text(
              'Google Maps',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C977),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInWaze(double lat, double lng) async {
    try {
      final wazeUrl = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
      final wazeFallbackUrl = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');

      if (await canLaunchUrl(wazeUrl)) {
        await launchUrl(wazeUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(wazeFallbackUrl)) {
        await launchUrl(wazeFallbackUrl, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        AppAlerts.showInfo(
          context,
          message: 'Não encontrei o Waze instalado. Vamos tentar abrir no Google Maps.',
          title: 'Abrindo no Maps',
        );
        await _openInGoogleMaps(lat, lng);
      }
    } catch (e) {
      if (!mounted) return;
      AppAlerts.showError(
        context,
        message: 'Não foi possível abrir o Waze. Vamos tentar pelo Google Maps.',
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
        AppAlerts.showWarning(
          context,
          message: 'Não conseguimos abrir o Google Maps neste dispositivo.',
          title: 'Ação indisponível',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppAlerts.showError(
        context,
        message: 'Não foi possível abrir o Google Maps. Tente novamente mais tarde.',
      );
    }
  }

  void _openLocation(dynamic latitude, dynamic longitude) {
    _showMapOptionsDialog(latitude, longitude);
  }

  String _normalizeStatusKey(String rawStatus) {
    final normalized = rawStatus.toLowerCase().trim();
    switch (normalized) {
      case 'pendente_cliente':
        return 'pending_customer';
      case 'pendente_oficina':
      case 'pendente':
      case 'pending':
      case 'pending_oficina':
        return 'pending';
      case 'confirmado':
      case 'confirmed':
      case 'confirmado_oficina':
        return 'confirmed';
      case 'em_andamento':
      case 'in_progress':
      case 'started':
        return 'in_progress';
      case 'finalizado_aguardando_pagamento':
      case 'finalizado':
      case 'concluido':
      case 'concluído':
      case 'completed':
        return 'awaiting_payment';
      case 'pago':
      case 'finalizado_cliente':
        return 'completed';
      case 'cancelado':
      case 'cancelled':
      case 'nao_compareceu':
        return 'cancelled';
      default:
        return 'pending';
    }
  }

  List<Color> _getStatusGradient(String status) {
    final normalized = _normalizeStatusKey(status);
    switch (normalized) {
      case 'confirmed':
        return [const Color(0xFF7896D8), const Color(0xFF5C7BC4)];
      case 'in_progress':
        return [const Color(0xFF00C977), const Color(0xFF00B369)];
      case 'completed':
        return [const Color(0xFF2FD65C), const Color(0xFF1FC04D)];
      case 'awaiting_payment':
        return [const Color(0xFF00B4D8), const Color(0xFF0077B6)];
      case 'cancelled':
        return [const Color(0xFFE8867C), const Color(0xFFD8766C)];
      case 'pending_customer':
        return [const Color(0xFFFAD961), const Color(0xFFF76B1C)];
      default:
        return [const Color(0xFFDBA800), const Color(0xFFC99800)];
    }
  }

  IconData _getStatusIcon(String status) {
    final normalized = _normalizeStatusKey(status);
    switch (normalized) {
      case 'confirmed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.build_circle;
      case 'completed':
        return Icons.done_all;
      case 'awaiting_payment':
        return Icons.payments;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getStatusText(String status) {
    final normalized = _normalizeStatusKey(status);
    switch (normalized) {
      case 'pending_customer':
        return 'Aguardando você';
      case 'pending':
        return 'Aguardando oficina';
      case 'confirmed':
        return 'Confirmado';
      case 'in_progress':
        return 'Em Andamento';
      case 'completed':
        return 'Concluído';
      case 'awaiting_payment':
        return 'Aguardando Pagamento';
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
      final bookingId = widget.booking['id']?.toString() ?? '';
      debugPrint('🔍 [OrderDetail] Cancelando agendamento ID: $bookingId');
      
      if (bookingId.isEmpty) {
        AppAlerts.showError(
          context,
          message: 'Erro: ID do agendamento não encontrado.',
        );
        return;
      }
      
      final result = await _apiService.cancelBooking(bookingId);

      if (!mounted) return;

      if (result['success']) {
        Navigator.pop(context, true);
        AppAlerts.showSuccess(
          context,
          message: 'Agendamento cancelado com sucesso.',
        );
      } else {
        debugPrint('❌ [OrderDetail] Erro ao cancelar: ${result['error']}');
        AppAlerts.showError(
          context,
          message: result['error'] ?? 'Não foi possível cancelar o agendamento agora. Tente novamente.',
        );
      }
    }
  }

  Widget _buildStatusInfoCard(String status, String normalizedStatus) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final rawStatus = status.toLowerCase();
    
    String title = '';
    String description = '';
    String nextStep = '';
    IconData icon = Icons.info;
    Color cardColor = Colors.blue.shade50;
    Color borderColor = Colors.blue.shade200;
    Color iconColor = Colors.blue.shade700;
    
    if (rawStatus == 'pendente_oficina' || normalizedStatus == 'pending') {
      title = 'Aguardando a oficina';
      description = 'Seu pedido já chegou lá. Eles vão responder em instantes.';
      nextStep = 'Fique atento às notificações para aprovação ou sugestão de horário.';
      icon = Icons.schedule;
      cardColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade200;
      iconColor = Colors.orange.shade700;
    } else if (rawStatus == 'confirmado' || normalizedStatus == 'confirmed') {
      title = 'Agendamento confirmado';
      description = 'Dia e horário reservados pra você.';
      nextStep = 'A oficina vai enviar um orçamento ou iniciar no dia combinado.';
      icon = Icons.check_circle;
      cardColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade200;
      iconColor = Colors.blue.shade700;
    } else if (rawStatus == 'pendente_cliente' || normalizedStatus == 'pending_customer') {
      // Verificar se é sugestão de horário ou orçamento
      final merged = _mergeBookingData();
      final suggestedBy = merged['suggested_by'] ?? merged['sugerido_por'];
      final hasSuggestedDate = merged['suggested_date'] != null || merged['data_sugerida'] != null;
      final isTimeSuggestion = suggestedBy == 'oficina' && hasSuggestedDate;
      
      if (isTimeSuggestion) {
        // É sugestão de horário da oficina
        title = 'Nova sugestão de horário';
        description = 'A oficina sugeriu um novo horário para o agendamento.';
        nextStep = 'Aceite o horário sugerido ou sugira outro horário.';
        icon = Icons.schedule;
        cardColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade200;
        iconColor = Colors.blue.shade700;
      } else {
        // É orçamento pendente
        final hasCompletedAt = _bookingDetails?['completed_at'] != null || widget.booking['completed_at'] != null;
        if (hasCompletedAt) {
          title = 'Revise o orçamento final';
          description = 'O serviço terminou e o valor final já está disponível.';
          nextStep = 'Aprove para liberar o pagamento ou rejeite se houver algo errado.';
        } else {
          title = 'Revise o orçamento';
          description = 'A oficina enviou o valor para iniciar o serviço.';
          nextStep = 'Aceite para liberar o início ou rejeite se precisar ajustar.';
        }
        icon = Icons.receipt_long;
        cardColor = Colors.amber.shade50;
        borderColor = Colors.amber.shade200;
        iconColor = Colors.amber.shade800;
      }
    } else if (normalizedStatus == 'in_progress') {
      title = 'Serviço em andamento';
      description = 'Seu veículo está sendo atendido agora.';
      nextStep = 'Avisaremos quando finalizarem para você aprovar.';
      icon = Icons.build_circle;
      cardColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
      iconColor = Colors.green.shade700;
    } else if (normalizedStatus == 'awaiting_payment') {
      title = 'Pagamento pendente';
      description = 'Orçamento aprovado e serviço finalizado.';
      nextStep = 'Use o botão abaixo para pagar agora.';
      icon = Icons.payments;
      cardColor = Colors.cyan.shade50;
      borderColor = Colors.cyan.shade200;
      iconColor = Colors.cyan.shade700;
    } else if (normalizedStatus == 'completed') {
      title = 'Serviço concluído';
      description = 'Pagamento confirmado e ordem encerrada.';
      nextStep = 'Avalie a experiência quando puder.';
      icon = Icons.done_all;
      cardColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
      iconColor = Colors.green.shade700;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? cardColor.withOpacity(0.1) : cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              height: 1.4,
            ),
          ),
          if (nextStep.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.arrow_forward, size: 16, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nextStep,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(String status) {
    final normalizedStatus = _normalizeStatusKey(status);
    final rawStatus = status.toLowerCase();
    final merged = _mergeBookingData();
    
    // DEBUG: Log para verificar detecção de sugestão
    debugPrint('🔍 [OrderDetail] _buildActionButtons:');
    debugPrint('  - status: $status');
    debugPrint('  - rawStatus: $rawStatus');
    debugPrint('  - merged[sugerido_por]: ${merged['sugerido_por']}');
    debugPrint('  - merged[suggested_by]: ${merged['suggested_by']}');
    debugPrint('  - merged[data_sugerida]: ${merged['data_sugerida']}');
    debugPrint('  - merged[suggested_date]: ${merged['suggested_date']}');
    debugPrint('  - _bookingDetails[sugerido_por]: ${_bookingDetails?['sugerido_por']}');
    debugPrint('  - _bookingDetails[suggested_by]: ${_bookingDetails?['suggested_by']}');
    debugPrint('  - _bookingDetails[data_sugerida]: ${_bookingDetails?['data_sugerida']}');
    debugPrint('  - _bookingDetails[suggested_date]: ${_bookingDetails?['suggested_date']}');
    
    // Verificar sugestão de horário com múltiplas variações de campos
    final suggestedBy = merged['suggested_by'] ?? 
                       merged['sugerido_por'] ?? 
                       _bookingDetails?['suggested_by'] ?? 
                       _bookingDetails?['sugerido_por'];
    final suggestedDateRaw = merged['suggested_date'] ?? 
                            merged['data_sugerida'] ?? 
                            _bookingDetails?['suggested_date'] ?? 
                            _bookingDetails?['data_sugerida'];
    final hasSuggestedDate = suggestedDateRaw != null && suggestedDateRaw.toString().isNotEmpty && suggestedDateRaw.toString() != 'null';
    final isTimeSuggestion = (suggestedBy == 'oficina' || suggestedBy == 'workshop') && hasSuggestedDate && (rawStatus == 'pendente_cliente' || rawStatus == 'pending_cliente' || normalizedStatus == 'pending_customer');
    
    debugPrint('  - suggestedBy: $suggestedBy');
    debugPrint('  - hasSuggestedDate: $hasSuggestedDate');
    debugPrint('  - isTimeSuggestion: $isTimeSuggestion');
    
    final hasQuote = (merged['final_price'] != null && merged['final_price'] > 0) ||
                     (_bookingDetails?['final_price'] != null && _bookingDetails!['final_price'] > 0);
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Card para sugestão de horário da oficina
          if (isTimeSuggestion) ...[
            _buildTimeSuggestionCard(merged),
            const SizedBox(height: 20),
          ],
          // Botão para aprovar orçamento quando status for pendente_cliente E não for sugestão de horário
          if (rawStatus == 'pendente_cliente' && !isTimeSuggestion && hasQuote) ...[
            // Card destacado com valor do orçamento
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade400, Colors.orange.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Orçamento Disponível',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Builder(
                              builder: (context) {
                                final hasCompletedAt = _bookingDetails?['completed_at'] != null || widget.booking['completed_at'] != null;
                                final message = hasCompletedAt
                                    ? 'Orçamento final - Aprove para pagar'
                                    : 'Orçamento inicial - Aprove para iniciar';
                                return Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_bookingDetails?['final_price'] != null || widget.booking['final_price'] != null) ...[
                    // Buscar items do orçamento
                    Builder(
                      builder: (context) {
                        final merged = _mergeBookingData();
                        final quoteItemsRaw = merged['quote_items'] ?? widget.booking['quote_items'];
                        final quoteItems = quoteItemsRaw is List ? quoteItemsRaw : null;
                        final diagnosticValue = merged['diagnostic_value'] ?? widget.booking['diagnostic_value'];
                        final hasDetailedQuote = quoteItems != null && quoteItems.isNotEmpty;
                        final finalPrice = (_bookingDetails?['final_price'] ?? widget.booking['final_price'] ?? 0) / 100.0;
                        
                        if (hasDetailedQuote) {
                          // Mostrar breakdown detalhado
                          return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Detalhamento do Orçamento',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Items do orçamento
                                ...List<Widget>.from(quoteItems.map<Widget>((item) {
                                  final description = item['description'] ?? '';
                                  final quantity = item['quantity'] ?? 1;
                                  final unitPrice = (item['unit_price'] ?? 0) / 100.0;
                                  final totalItem = unitPrice * quantity;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                description,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              if (quantity > 1)
                                                Text(
                                                  'Qtd: $quantity × ${PriceUtils.formatCurrency(unitPrice)}',
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.8),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          PriceUtils.formatCurrency(totalItem) ?? 'R\$ 0,00',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                })),
                                
                                // Valor do diagnóstico (se houver)
                                if (diagnosticValue != null && diagnosticValue > 0) ...[
                                  const Divider(color: Colors.white38, height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Diagnóstico',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            'Análise do veículo',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.7),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        PriceUtils.formatCurrency(diagnosticValue / 100) ?? 'R\$ 0,00',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                
                                const Divider(color: Colors.white38, height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Valor Total:',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      PriceUtils.formatCurrency(finalPrice) ?? 'R\$ 0,00',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        } else {
                          // Mostrar apenas valor total (formato antigo)
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Valor do Orçamento:',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                                  PriceUtils.formatCurrency(finalPrice) ?? 'R\$ 0,00',
                            style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            // Botão grande e destacado para aprovar
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C977).withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _approveQuote,
                  icon: const Icon(Icons.check_circle, color: Colors.white, size: 28),
                  label: const Text(
                    'APROVAR ORÇAMENTO',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C977),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Botão para rejeitar orçamento
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _rejectQuote(),
                icon: const Icon(Icons.cancel, color: Colors.red),
                label: const Text(
                  'REJEITAR ORÇAMENTO',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    letterSpacing: 0.8,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Mensagem explicativa
            Builder(
              builder: (context) {
                final merged = _mergeBookingData();
                final hasCompletedAt = _bookingDetails?['completed_at'] != null || widget.booking['completed_at'] != null;
                final quoteStatus = merged['quote_status'] ?? widget.booking['quote_status'];
                final isFinalQuote = quoteStatus == 'final';
                final diagnosticValue = merged['diagnostic_value'] ?? widget.booking['diagnostic_value'];
                final hasDiagnostic = diagnosticValue != null && diagnosticValue > 0;
                
                String message;
                Color containerColor;
                Color borderColor;
                Color iconColor;
                
                if (isFinalQuote) {
                  message = 'Este é o orçamento final após o serviço. Aprove para realizar o pagamento.';
                  containerColor = Colors.green.shade50;
                  borderColor = Colors.green.shade200;
                  iconColor = Colors.green.shade700;
                } else if (hasCompletedAt) {
                  message = 'Após aprovar, você poderá realizar o pagamento do serviço.';
                  containerColor = Colors.blue.shade50;
                  borderColor = Colors.blue.shade200;
                  iconColor = Colors.blue.shade700;
                } else {
                  message = hasDiagnostic
                      ? 'Ao aprovar, a oficina iniciará o serviço. Se rejeitar, você pagará apenas o diagnóstico (${PriceUtils.formatCurrency(diagnosticValue / 100)}).'
                      : 'Após aprovar, a oficina poderá iniciar o serviço.';
                  containerColor = Colors.blue.shade50;
                  borderColor = Colors.blue.shade200;
                  iconColor = Colors.blue.shade700;
                }
                
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: iconColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(
                            fontSize: 14,
                            color: iconColor == Colors.green.shade700 ? Colors.green.shade900 : (iconColor == Colors.blue.shade700 ? Colors.blue.shade900 : Colors.grey.shade900),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
          if (normalizedStatus == 'in_progress' || normalizedStatus == 'awaiting_payment' || normalizedStatus == 'completed') ...[
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
          if (normalizedStatus == 'awaiting_payment') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _redirectToPayment(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Realizar Pagamento',
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
          if (normalizedStatus == 'completed') ...[
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
        ],
      ),
    );
  }

  Future<void> _approveQuote() async {
    final bookingId = widget.booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) {
      AppAlerts.showError(context, message: 'Erro: ID do agendamento não encontrado.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprovar Orçamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Você confirma a aprovação deste orçamento?'),
            const SizedBox(height: 16),
            if (_bookingDetails?['final_price'] != null || widget.booking['final_price'] != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.attach_money, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Valor: R\$ ${((_bookingDetails?['final_price'] ?? widget.booking['final_price'] ?? 0) / 100).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C977),
            ),
            child: const Text('Aprovar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await _apiService.approveQuote(bookingId);
      
      if (!mounted) return;

      if (result['success'] == true) {
        // Recarregar detalhes do agendamento
        await _loadBookingDetails();
        
        // Verificar se é orçamento inicial ou final
        final hasCompletedAt = _bookingDetails?['completed_at'] != null || widget.booking['completed_at'] != null;
        final newStatus = result['data']?['status']?.toString().toLowerCase() ?? 
                         (hasCompletedAt ? 'finalizado_aguardando_pagamento' : 'confirmado');
        
        final message = hasCompletedAt
            ? 'Orçamento aprovado com sucesso! Agora você pode realizar o pagamento.'
            : 'Orçamento aprovado com sucesso! A oficina pode iniciar o serviço agora.';
        
        AppAlerts.showSuccess(
          context,
          message: message,
        );
        
        // Atualizar o status local baseado na resposta da API
        setState(() {
          widget.booking['status'] = newStatus;
          if (_bookingDetails != null) {
            _bookingDetails!['status'] = newStatus;
          }
        });
        
        // Navegar de volta para a tela de agendamentos no status CONFIRMADOS
        if (!hasCompletedAt) {
          // Aguardar um pouco para o usuário ver a mensagem de sucesso
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            // Navegar de volta e depois para a aba de confirmados
            Navigator.of(context).popUntil((route) {
              // Voltar até a tela de agendamentos
              return route.settings.name == '/orders' || route.isFirst;
            });
            // Se não encontrou a rota, apenas pop
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }
        }
      } else {
      AppAlerts.showError(
        context,
        message: result['error'] ?? 'Erro ao aprovar orçamento. Tente novamente.',
      );
    }
  } catch (e) {
    if (!mounted) return;
    AppAlerts.showError(
      context,
      message: 'Erro ao aprovar orçamento: ${e.toString()}',
    );
  }
  }

  Widget _buildTimeSuggestionCard(Map<String, dynamic> merged) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final suggestedDateStr = merged['suggested_date'] ?? merged['data_sugerida'];
    if (suggestedDateStr == null) return const SizedBox.shrink();
    
    DateTime? suggestedDate;
    try {
      suggestedDate = DateTime.parse(suggestedDateStr.toString());
    } catch (e) {
      return const SizedBox.shrink();
    }
    
    final workshopName = merged['workshop_name'] ?? merged['workshop']?['name'] ?? 'Oficina';
    final cardColor = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com gradiente
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFF59E0B),
                  const Color(0xFFF97316),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nova Sugestão de Horário',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$workshopName sugeriu um novo horário',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.95),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Conteúdo
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card de data e hora
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.calendar_today_rounded,
                          color: Color(0xFFF59E0B),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Data',
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd/MM/yyyy').format(suggestedDate),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.access_time_rounded,
                          color: Color(0xFFF59E0B),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Horário',
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('HH:mm').format(suggestedDate),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Botões
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _rejectTimeSuggestion,
                        icon: const Icon(Icons.close_rounded, size: 20),
                        label: const Text(
                          'Recusar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444), width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _acceptTimeSuggestion,
                        icon: const Icon(Icons.check_circle_rounded, size: 22),
                        label: const Text(
                          'Aceitar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C977),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptTimeSuggestion() async {
    final bookingId = widget.booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) {
      AppAlerts.showError(context, message: 'Erro: ID do agendamento não encontrado.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aceitar Sugestão de Horário'),
        content: const Text('Deseja aceitar o horário sugerido pela oficina? O agendamento será confirmado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C977),
            ),
            child: const Text('Aceitar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await _apiService.acceptSchedule(bookingId);

      if (!mounted) return;

      if (result['success'] == true) {
        await _loadBookingDetails();
        AppAlerts.showSuccess(
          context,
          message: 'Horário aceito com sucesso! O agendamento está confirmado.',
        );
        setState(() {
          widget.booking['status'] = 'confirmado';
          if (_bookingDetails != null) {
            _bookingDetails!['status'] = 'confirmado';
          }
        });
        // Navegar de volta após um delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      } else {
        AppAlerts.showError(
          context,
          message: result['error'] ?? 'Erro ao aceitar sugestão de horário.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppAlerts.showError(
        context,
        message: 'Erro ao aceitar sugestão: ${e.toString()}',
      );
    }
  }

  Future<void> _rejectTimeSuggestion() async {
    final bookingId = widget.booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) {
      AppAlerts.showError(context, message: 'Erro: ID do agendamento não encontrado.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recusar Sugestão de Horário'),
        content: const Text(
          'Ao recusar a sugestão de horário, o agendamento será cancelado. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Recusar e Cancelar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await _apiService.rejectTimeSuggestion(bookingId);

      if (!mounted) return;

      if (result['success'] == true) {
        AppAlerts.showSuccess(
          context,
          message: 'Sugestão recusada. O agendamento foi cancelado e a oficina foi notificada.',
        );
        Navigator.pop(context, true);
      } else {
        AppAlerts.showError(
          context,
          message: result['error'] ?? 'Erro ao recusar sugestão de horário.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppAlerts.showError(
        context,
        message: 'Erro ao recusar sugestão: ${e.toString()}',
      );
    }
  }

  Future<void> _rejectQuote() async {
    final bookingId = widget.booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) {
      AppAlerts.showError(context, message: 'Erro: ID do agendamento não encontrado.');
      return;
    }

    final merged = _mergeBookingData();
    final quoteStatus = merged['quote_status'] ?? widget.booking['quote_status'];
    final isFinalQuote = quoteStatus == 'final';
    final hasCompletedAt = merged['completed_at'] != null || widget.booking['completed_at'] != null;
    final diagnosticValue = merged['diagnostic_value'] ?? widget.booking['diagnostic_value'];
    final hasDiagnostic = diagnosticValue != null && diagnosticValue > 0;
    
    // Não pode rejeitar orçamento final
    if (isFinalQuote) {
      AppAlerts.showError(
        context,
        message: 'Este é o orçamento final após o serviço. Não é possível rejeitá-lo. Você deve realizar o pagamento.',
      );
      return;
    }

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeitar Orçamento'),
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Você confirma a rejeição deste orçamento?'),
            const SizedBox(height: 16),
              
              // Aviso sobre pagamento do diagnóstico
              if (!hasCompletedAt && hasDiagnostic)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Atenção',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ao rejeitar este orçamento, você precisará pagar apenas o valor do diagnóstico:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        PriceUtils.formatCurrency(diagnosticValue / 100) ?? 'R\$ 0,00',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Isso porque a oficina já analisou seu veículo e identificou os problemas.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_bookingDetails?['final_price'] != null || widget.booking['final_price'] != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.attach_money, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Valor: R\$ ${((_bookingDetails?['final_price'] ?? widget.booking['final_price'] ?? 0) / 100).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo da rejeição (opcional)',
                hintText: 'Informe o motivo da rejeição...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Rejeitar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await _apiService.rejectQuote(
        bookingId,
        reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      );
      
      if (!mounted) return;

      if (result['success'] == true) {
        // Recarregar detalhes do agendamento
        await _loadBookingDetails();
        
        AppAlerts.showSuccess(
          context,
          message: 'Orçamento rejeitado com sucesso. A oficina foi notificada e poderá enviar um novo orçamento.',
        );
        
        // Atualizar o status local
        setState(() {
          final hasCompletedAt = _bookingDetails?['completed_at'] != null || widget.booking['completed_at'] != null;
          widget.booking['status'] = hasCompletedAt ? 'em_andamento' : 'confirmado';
          if (_bookingDetails != null) {
            _bookingDetails!['status'] = hasCompletedAt ? 'em_andamento' : 'confirmado';
          }
        });
      } else {
        AppAlerts.showError(
          context,
          message: result['error'] ?? 'Erro ao rejeitar orçamento. Tente novamente.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppAlerts.showError(
        context,
        message: 'Erro ao rejeitar orçamento: ${e.toString()}',
      );
    }
  }

  Future<void> _rateService() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewScreen(
          bookingId: widget.booking['id'],
          workshopId: widget.booking['workshop_id'] ?? widget.booking['oficina_id'] ?? '',
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        AppAlerts.showSuccess(
          context,
          message: 'Obrigado pela avaliação! Ela ajuda outras pessoas a escolher a oficina certa.',
        );
      }
    });
  }

  Future<void> _viewEvidence() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingEvidenceScreen(
          bookingId: widget.booking['id'],
          booking: widget.booking,
        ),
      ),
    );
  }

  bool _shouldShowPrice() {
    return _hasFinalPrice() && !_isAwaitingClientQuote();
  }

  bool _shouldShowEstimateNotice() {
    return !_hasFinalPrice() || _isAwaitingClientQuote();
  }

  String? _formatPriceLabel() {
    final total = _extractFinalPrice();
    if (total == null) return null;
    return 'R\$ ${total.toStringAsFixed(2)}';
  }

  bool _isAwaitingClientQuote() {
    final merged = _mergeBookingData();
    final status = (merged['status'] ?? widget.booking['status'] ?? '').toString();
    return _normalizeStatusKey(status) == 'pending_customer';
  }

  bool _hasFinalPrice() {
    return _extractFinalPrice() != null;
  }

  double? _extractFinalPrice() {
    final bookingData = _mergeBookingData();
    return _extractFinalPriceFromMap(bookingData);
  }

  double? _extractFinalPriceFromMap(Map<String, dynamic> bookingData) {
    final candidateKeys = [
      'final_price',
      'finalPrice',
      'final_amount',
      'finalAmount',
      'approved_amount',
      'approvedAmount',
      'final_price_cents',
    ];

    for (final key in candidateKeys) {
      if (!bookingData.containsKey(key)) continue;
      final candidate = bookingData[key];
      final parsed = _parseBackendPrice(candidate);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    return null;
  }

  double? _parseBackendPrice(dynamic raw) {
    if (raw == null) return null;

    if (raw is num) {
      final value = raw.toDouble();
      if (value == 0) return null;
      if (value.abs() >= 100 && value % 1 == 0) {
        return value / 100;
      }
      return value;
    }

    if (raw is String) {
      final cleaned = raw.trim();
      if (cleaned.isEmpty) return null;
      final parsed = double.tryParse(cleaned.replaceAll(',', '.'));
      if (parsed == null || parsed == 0) return null;
      if (cleaned.contains('.') || cleaned.contains(',')) {
        return parsed;
      }
      if (parsed.abs() >= 100 && parsed % 1 == 0) {
        return parsed / 100;
      }
      return parsed;
    }

    return null;
  }

  Widget _buildEstimateInfoCard(bool isDarkMode) {
    final awaitingQuote = _isAwaitingClientQuote();
    final estimatedPrice = _resolveServiceAmount(_mergeBookingData());
    final baseColor = awaitingQuote ? Colors.orange : Colors.blue;

    final message = awaitingQuote
        ? 'A oficina já enviou o orçamento com o valor real. Revise os detalhes acima e aprove ou rejeite. O valor anterior era apenas uma estimativa automática.'
        : 'O valor exibido no catálogo é apenas uma estimativa. A oficina analisará seu caso e enviará o orçamento oficial antes de iniciar o serviço.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: baseColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: baseColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              awaitingQuote ? Icons.receipt_long : Icons.info_outline,
              color: baseColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  awaitingQuote ? 'Aguarde a confirmação' : 'Valor estimado',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : const Color(0xFF252940),
                  ),
                ),
                if (estimatedPrice != null && !awaitingQuote) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Estimativa do catálogo: R\$ ${estimatedPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowReminderButton() {
    final status = widget.booking['status']?.toString() ?? '';
    final normalized = _normalizeStatusKey(status);
    final isConfirmedOrPending = normalized == 'confirmed' || normalized == 'pending' || normalized == 'pending_customer';

    if (!isConfirmedOrPending) return false;

    final appointmentDate = widget.booking['appointment_date'] ?? widget.booking['scheduled_date'];
    if (appointmentDate == null) return false;

    try {
      final date = DateTime.parse(appointmentDate);
      return date.isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  Future<void> _toggleReminder(bool enabled) async {
    try {
      final bookingId = widget.booking['id']?.toString() ?? '';
      if (bookingId.isEmpty) {
        if (!mounted) return;
        AppAlerts.showError(
          context,
          message: 'Não encontramos o identificador deste agendamento. Tente novamente.',
        );
        return;
      }

      final result = await _apiService.toggleBookingReminder(bookingId, enabled);

      if (!mounted) return;

      if (result['success']) {
        setState(() {
          _bookingDetails = _bookingDetails ?? {};
          _bookingDetails!['reminder_enabled'] = enabled;
          widget.booking['reminder_enabled'] = enabled;
        });

        AppAlerts.showSuccess(
          context,
          message: enabled
              ? 'Lembretes ativados! Vamos avisar você 1 dia antes, no dia e 1 hora antes do serviço.'
              : 'Lembretes desativados para este agendamento.',
        );

        if (enabled) {
          final appointmentDateStr = _bookingDetails?['appointment_date'] ??
              widget.booking['appointment_date'] ??
              widget.booking['scheduled_date'] ??
              '';

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
        AppAlerts.showError(
          context,
          message: result['error'] ?? 'Não foi possível atualizar os lembretes agora. Tente novamente.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppAlerts.showError(
        context,
        message: 'Não foi possível atualizar os lembretes agora. Tente novamente.',
      );
    }
  }

  Widget _buildReminderCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final reminderEnabled = (_bookingDetails?['reminder_enabled'] ?? widget.booking['reminder_enabled']) == true;
    final gradient = reminderEnabled ? const LinearGradient(colors: [Color(0xFF00C977), Color(0xFF00B369)]) : null;
    final inactiveColor = isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? inactiveColor : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: reminderEnabled ? const Color(0xFF00C977) : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
          width: 1.5,
        ),
        boxShadow: reminderEnabled
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
          onTap: () => _toggleReminder(!reminderEnabled),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  reminderEnabled ? Icons.notifications_active : Icons.notifications_off,
                  color: reminderEnabled ? Colors.white : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminderEnabled ? 'Lembretes Ativados' : 'Ativar Lembretes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: reminderEnabled ? Colors.white : (isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reminderEnabled
                            ? 'Você receberá notificações 1 dia antes, no dia e 1 hora antes'
                            : 'Receba notificações 1 dia antes, no dia e 1 hora antes',
                        style: TextStyle(
                          fontSize: 12,
                          color: reminderEnabled
                              ? Colors.white.withOpacity(0.9)
                              : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  reminderEnabled ? Icons.toggle_on : Icons.toggle_off,
                  color: reminderEnabled ? Colors.white : (isDarkMode ? Colors.grey[500] : Colors.grey[400]),
                  size: 32,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatWorkshopAddress(dynamic address) {
    if (address == null) return 'Endereço não informado';
    
    // Se já é uma string válida, retornar
    if (address is String) {
      if (address.trim().isEmpty) return 'Endereço não informado';
      // Se parece ser JSON, tentar parsear
      if (address.trim().startsWith('{') || address.trim().startsWith('[')) {
        try {
          final parsed = json.decode(address);
          return _formatAddressFromMap(parsed);
        } catch (_) {
          return address;
        }
      }
      return address;
    }
    
    // Se é um Map, formatar
    if (address is Map) {
      return _formatAddressFromMap(address);
    }
    
    return address.toString();
  }

  String _formatAddressFromMap(dynamic addressMap) {
    if (addressMap == null) return 'Endereço não informado';
    
    try {
      Map<String, dynamic> map;
      if (addressMap is Map<String, dynamic>) {
        map = addressMap;
      } else if (addressMap is Map) {
        map = Map<String, dynamic>.from(addressMap);
      } else if (addressMap is String) {
        try {
          map = Map<String, dynamic>.from(json.decode(addressMap));
        } catch (_) {
          return addressMap.toString();
        }
      } else {
        return addressMap.toString();
      }

      final components = <String>[];
      
      // Tentar diferentes formatos de campos
      final street = map['logradouro'] ?? map['street'] ?? map['rua'] ?? '';
      final number = map['numero'] ?? map['number'] ?? '';
      final district = map['bairro'] ?? map['district'] ?? map['neighborhood'] ?? '';
      final city = map['cidade'] ?? map['city'] ?? '';
      final state = map['estado'] ?? map['state'] ?? map['uf'] ?? '';
      final zip = map['cep'] ?? map['zip'] ?? map['postal_code'] ?? '';
      
      if (street.isNotEmpty) {
        if (number.isNotEmpty) {
          components.add('$street, $number');
        } else {
          components.add(street);
        }
      }
      
      if (district.isNotEmpty) components.add(district);
      if (city.isNotEmpty) components.add(city);
      if (state.isNotEmpty) components.add(state);
      if (zip.isNotEmpty) components.add('CEP: $zip');
      
      if (components.isEmpty) {
        return 'Endereço não informado';
      }
      
      return components.join(', ');
    } catch (e) {
      return addressMap.toString();
    }
  }
}

