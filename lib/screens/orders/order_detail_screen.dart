import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../utils/price_utils.dart';
import '../../widgets/app_alerts.dart';
import '../payment/payment_screen.dart';
import '../review/review_screen.dart';
import 'booking_evidence_screen.dart';

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
      return raw.whereType<Object>().map<Map<String, dynamic>?>((item) {
        if (item is Map<String, dynamic>) {
          // Extrair URL e key
          String url = item['url']?.toString() ?? '';
          final key = item['s3_key']?.toString() ?? item['s3Key']?.toString() ?? item['key']?.toString() ?? '';
          
          // VALIDAÇÃO CRÍTICA: URL deve começar com http:// ou https://
          // Se não for uma URL válida, não podemos usar
          if (url.isNotEmpty && !url.startsWith('http://') && !url.startsWith('https://')) {
            debugPrint('⚠️ [OrderDetail] URL inválida em _coerceUploads (não é http/https): $url');
            debugPrint('⚠️ [OrderDetail] Key disponível: $key');
            // Se a URL não é válida, retornar null para filtrar
            // A API deve sempre retornar URLs válidas - se não retornou, há problema na API
            url = '';
          }
          
          // Se não tiver URL válida, retornar null
          // NÃO tentar construir URL no app - a API deve fazer isso
          if (url.isEmpty) {
            debugPrint('⚠️ [OrderDetail] Imagem sem URL válida - será ignorada');
            debugPrint('⚠️ [OrderDetail] A API deve retornar URL assinada completa. Key: $key');
            return null;
          }
          
          // Log para debug
          debugPrint('✅ [OrderDetail] URL válida encontrada: ${url.substring(0, 60)}...');
          
          return {
            'url': url,
            'file_name': item['file_name']?.toString() ?? item['fileName']?.toString() ?? 'imagem.jpg',
            's3_key': key,
            'uploaded_by': item['uploaded_by']?.toString() ?? item['uploadedBy']?.toString() ?? 'unknown',
          };
        }
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
        return null;
      }).whereType<Map<String, dynamic>>().toList();
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

  // Buscar todas as imagens do agendamento (customer_uploads + provas_oficina + booking_images)
  List<Map<String, dynamic>> _getAllBookingImages() {
    final allImages = <Map<String, dynamic>>[];
    
    // 1. Imagens do cliente (customer_uploads) - PRIMEIRO, pois são as mais importantes
    final customerUploads = _getCustomerUploads();
    if (customerUploads.isNotEmpty) {
      debugPrint('📸 [OrderDetail] Encontradas ${customerUploads.length} imagens em customer_uploads');
      allImages.addAll(customerUploads);
    }
    
    // 2. Imagens da tabela booking_images (inclui as que foram salvas pelo upload)
    final bookingImagesRaw = _bookingDetails?['booking_images'] ?? widget.booking['booking_images'];
    if (bookingImagesRaw != null) {
      if (bookingImagesRaw is List) {
        debugPrint('📸 [OrderDetail] Encontradas ${bookingImagesRaw.length} imagens em booking_images');
        for (final img in bookingImagesRaw) {
          if (img is Map<String, dynamic>) {
            String url = img['url']?.toString() ?? '';
            
            // Validar que a URL é completa (http/https)
            if (url.isNotEmpty && !url.startsWith('http://') && !url.startsWith('https://')) {
              debugPrint('⚠️ [OrderDetail] URL inválida em booking_images (não é http/https): $url');
              // Tentar usar s3_key se disponível, mas a API deve sempre retornar URL assinada
              final key = img['s3_key'] ?? img['s3Key'] ?? img['key'] ?? '';
              if (key.isNotEmpty) {
                debugPrint('⚠️ [OrderDetail] Tentando usar key como fallback: $key');
              }
              url = ''; // Invalidar URL
            }
            
            if (url.isNotEmpty) {
              allImages.add({
                'url': url,
                'file_name': img['file_name'] ?? img['fileName'] ?? 'imagem.jpg',
                's3_key': img['s3_key'] ?? img['s3Key'] ?? img['key'] ?? '',
                'uploaded_by': img['uploaded_by'] ?? img['uploadedBy'] ?? 'unknown',
              });
            } else {
              debugPrint('⚠️ [OrderDetail] Imagem em booking_images sem URL válida');
            }
          }
        }
      } else if (bookingImagesRaw is Map) {
        // Se for um único objeto, converter para lista
        String url = bookingImagesRaw['url']?.toString() ?? '';
        final key = bookingImagesRaw['s3_key']?.toString() ?? bookingImagesRaw['s3Key']?.toString() ?? bookingImagesRaw['key']?.toString() ?? '';
        
        // VALIDAÇÃO CRÍTICA: URL deve começar com http:// ou https://
        if (url.isNotEmpty && !url.startsWith('http://') && !url.startsWith('https://')) {
          debugPrint('⚠️ [OrderDetail] URL inválida em booking_images (Map único) (não é http/https): $url');
          debugPrint('⚠️ [OrderDetail] Key disponível: $key');
          url = ''; // Invalidar URL
        }
        
        if (url.isNotEmpty) {
          allImages.add({
            'url': url,
            'file_name': bookingImagesRaw['file_name']?.toString() ?? bookingImagesRaw['fileName']?.toString() ?? 'imagem.jpg',
            's3_key': key,
            'uploaded_by': bookingImagesRaw['uploaded_by']?.toString() ?? bookingImagesRaw['uploadedBy']?.toString() ?? 'unknown',
          });
        } else {
          debugPrint('⚠️ [OrderDetail] Imagem em booking_images (Map único) sem URL válida - será ignorada');
        }
      }
    }
    
    // 3. Evidências da oficina (provas_oficina)
    final workshopEvidenceRaw = _bookingDetails?['provas_oficina'] ?? widget.booking['provas_oficina'];
    if (workshopEvidenceRaw != null) {
      final workshopEvidence = _coerceUploads(workshopEvidenceRaw);
      if (workshopEvidence.isNotEmpty) {
        debugPrint('📸 [OrderDetail] Encontradas ${workshopEvidence.length} evidências da oficina');
        allImages.addAll(workshopEvidence);
      }
    }
    
    // Remover duplicatas baseado na URL
    final seenUrls = <String>{};
    final uniqueImages = allImages.where((img) {
      final url = img['url']?.toString() ?? '';
      if (url.isEmpty || seenUrls.contains(url)) {
        return false;
      }
      seenUrls.add(url);
      return true;
    }).toList();
    
    debugPrint('📸 [OrderDetail] Total de ${uniqueImages.length} imagens únicas após remoção de duplicatas');
    
    return uniqueImages;
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
    
    // IMPORTANTE: Se há sugestão de horário pendente, garantir que o status seja 'pendente_cliente'
    final suggestedBy = combined['suggested_by'] ?? combined['sugerido_por'];
    final hasSuggestedDate = combined['suggested_date'] != null || combined['data_sugerida'] != null;
    final isTimeSuggestion = (suggestedBy == 'oficina' || suggestedBy == 'workshop') && hasSuggestedDate;
    
    if (isTimeSuggestion) {
      // Forçar status para 'pendente_cliente' quando há sugestão pendente
      combined['status'] = 'pendente_cliente';
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
        normalized == 'finalizado_aguardando_pagamento' ||
        normalized == 'aguardando_pagamento' ||
        normalized == 'awaiting_payment';
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
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        // Cache de alta qualidade para visualização em tela cheia
                        memCacheWidth: null, // Não limitar para tela cheia
                        memCacheHeight: null,
                        httpHeaders: {
                          'Accept': 'image/*',
                        },
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) {
                          debugPrint('❌ [OrderDetail] Erro ao carregar imagem em tela cheia: $error');
                          return Container(
                            color: Colors.black,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image, color: Colors.white, size: 40),
                          );
                        },
                        fadeInDuration: const Duration(milliseconds: 200),
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

      final result = await _apiService.getBookingDetails(bookingId, forceRefresh: true);

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

  Future<void> _loadBookingDetails({bool forceRefresh = false}) async {
    try {
      final bookingId = widget.booking['id']?.toString() ?? '';
      if (bookingId.isEmpty) {
        debugPrint('Erro: ID do agendamento não encontrado');
        return;
      }

      // IMPORTANTE: Invalidar cache se forçar refresh
      if (forceRefresh) {
        _apiService.invalidateBookingCache(bookingId);
        _apiService.invalidateBookingsCache();
      }

      final result = await _apiService.getBookingDetails(bookingId, forceRefresh: forceRefresh);

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

      final bookingResult = await _apiService.getBookingDetails(bookingId, forceRefresh: true);
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
      // Invalidar cache e recarregar booking imediatamente
      final bookingId = widget.booking['id']?.toString();
      if (bookingId != null) {
        _apiService.invalidateBookingCache(bookingId);
        _apiService.invalidateBookingsCache();
      }
      // Recarregar detalhes do booking para atualizar status
      await _loadBookingDetails(forceRefresh: true);
      if (!mounted) return;
      AppAlerts.showSuccess(
        context,
        message: 'Pagamento registrado! Obrigado por usar o MECA.',
      );
      // Atualizar UI
      setState(() {});
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
    // final customerUploads = _getCustomerUploads(); // Removido: variável não utilizada
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
                      Builder(
                        builder: (context) {
                          final merged = _mergeBookingData();
                          final scheduleType = merged['schedule_type']?.toString() ?? 'specific_time';
                          final isTimeWindow = scheduleType == 'time_window';
                          
                          if (isTimeWindow && merged['time_window_start'] != null && merged['time_window_end'] != null) {
                            // Exibir janela de horários
                            try {
                              final startTime = DateTime.parse(merged['time_window_start'].toString());
                              final endTime = DateTime.parse(merged['time_window_end'].toString());
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoRow(
                                    Icons.calendar_today,
                                    DateFormat('dd/MM/yyyy').format(startTime),
                                  ),
                                  _buildInfoRow(
                                    Icons.schedule,
                                    '${DateFormat('HH:mm').format(startTime)} até ${DateFormat('HH:mm').format(endTime)}',
                                  ),
                                ],
                              );
                            } catch (e) {
                              // Fallback para exibição padrão
                            }
                          }
                          
                          // Exibição padrão para horário específico
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(
                                Icons.calendar_today,
                                merged['appointment_date'] != null
                                    ? DateFormat('dd/MM/yyyy').format(DateTime.parse(merged['appointment_date'].toString()))
                                    : (merged['scheduled_date'] != null
                                        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(merged['scheduled_date'].toString()))
                                        : 'Data não definida'),
                              ),
                              _buildInfoRow(
                                Icons.access_time,
                                merged['appointment_date'] != null
                                    ? DateFormat('HH:mm').format(DateTime.parse(merged['appointment_date'].toString()))
                                    : (merged['scheduled_time'] ?? '00:00'),
                              ),
                            ],
                          );
                        },
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
                  // Exibir todas as imagens do agendamento (em todos os status)
                  Builder(
                    builder: (context) {
                      final allImages = _getAllBookingImages();
                      if (allImages.isEmpty) return const SizedBox.shrink();
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          Text(
                            'Imagens do Agendamento',
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
                            children: allImages.map((img) {
                              final url = img['url']?.toString();
                              if (url == null || url.isEmpty) return const SizedBox.shrink();
                              
                              // Determinar se é imagem do cliente ou da oficina
                              final uploadedBy = img['uploaded_by']?.toString() ?? '';
                              final s3Key = img['s3_key']?.toString() ?? img['key']?.toString() ?? '';
                              final isFromWorkshop = uploadedBy == 'workshop' || 
                                                    s3Key.contains('/workshop/') ||
                                                    s3Key.contains('workshop');
                              
                              return GestureDetector(
                                onTap: () => _openUploadPreview(img),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 90,
                                        height: 90,
                                        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
                                        child: CachedNetworkImage(
                                          imageUrl: url,
                                          fit: BoxFit.cover,
                                          width: 90,
                                          height: 90,
                                          // Cache de alta qualidade - 2x para retina
                                          memCacheWidth: 180,
                                          memCacheHeight: 180,
                                          // Headers para garantir que a imagem seja carregada corretamente
                                          httpHeaders: {
                                            'Accept': 'image/*',
                                          },
                                          // Placeholder enquanto carrega
                                          placeholder: (context, url) => const Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                          // Erro ao carregar
                                          errorWidget: (context, url, error) {
                                            debugPrint('❌ [OrderDetail] Erro ao carregar imagem: $error');
                                            debugPrint('❌ [OrderDetail] URL: $url');
                                            return Container(
                                              color: Colors.grey.shade300,
                                              alignment: Alignment.center,
                                              child: Icon(Icons.broken_image, color: Colors.grey.shade600),
                                            );
                                          },
                                          // Fade in suave quando carregar
                                          fadeInDuration: const Duration(milliseconds: 200),
                                          fadeOutDuration: const Duration(milliseconds: 100),
                                        ),
                                      ),
                                    ),
                                    // Badge indicando origem da imagem
                                    if (isFromWorkshop)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00C977),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Oficina',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                  ),
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
    final merged = _mergeBookingData();
    final serviceStartPending = merged['service_start_pending'] == true || merged['service_start_pending'] == 'true';
    
    // CRITICAL: Se service_start_pending = true e não há orçamento, NÃO mostrar card de orçamento
    if (serviceStartPending) {
      final hasQuote = (merged['final_price'] != null && (merged['final_price'] is num ? merged['final_price'] > 0 : false)) ||
                      (merged['estimated_price'] != null && (merged['estimated_price'] is num ? merged['estimated_price'] > 0 : false)) ||
                      (merged['quote_items'] != null && merged['quote_items'] is List && (merged['quote_items'] as List).isNotEmpty);
      if (!hasQuote) {
        return const SizedBox.shrink(); // Não mostrar orçamento se apenas iniciou serviço sem orçamento
      }
    }
    
    final quoteValue = _extractFinalPrice();
    if (quoteValue == null) return const SizedBox.shrink();
    final status = (merged['status'] ?? widget.booking['status'] ?? '').toString();
    final normalizedStatus = _normalizeStatusKey(status);
    final hasCompletedAt = merged['completed_at'] != null || widget.booking['completed_at'] != null;
    final quoteStatus = merged['quote_status'] ?? widget.booking['quote_status'];
    final isFinalQuote = quoteStatus == 'final';
    
    // Buscar items do orçamento
    final quoteItemsRaw = merged['quote_items'] ?? widget.booking['quote_items'];
    final quoteItems = quoteItemsRaw is List ? quoteItemsRaw : null;
    final diagnosticValueRaw = merged['diagnostic_value'] ?? widget.booking['diagnostic_value'];
    final diagnosticValue = _parseDiagnosticValue(diagnosticValueRaw);
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

    // Verificar se é orçamento editado durante serviço
    final statusHistoryRaw = merged['status_history'] ?? widget.booking['status_history'];
    bool isEditedQuote = false;
    try {
      if (statusHistoryRaw != null) {
        final statusHistory = statusHistoryRaw is String 
            ? jsonDecode(statusHistoryRaw) 
            : statusHistoryRaw;
        isEditedQuote = statusHistory is Map && statusHistory['previous_quote'] != null;
      }
    } catch (e) {
      // Ignorar erro de parsing
    }

    // Verificar se há orçamento pendente de aprovação
    final isQuotePending = normalizedStatus == 'pending' || 
                          normalizedStatus == 'pendente_cliente' ||
                          (merged['quote_status'] ?? widget.booking['quote_status']) == 'pending';

    // Ajustar título e subtítulo se for orçamento editado
    if (isQuotePending && isEditedQuote && title == 'Orçamento aprovado') {
      title = '⚠️ Orçamento Atualizado Durante o Serviço';
      subtitle = 'A oficina alterou o orçamento durante o serviço. Revise o novo valor e aprove ou rejeite.';
    } else if (isEditedQuote && normalizedStatus == 'em_andamento' && title == 'Orçamento aprovado') {
      title = 'Orçamento atualizado e aprovado';
      subtitle = 'Você aprovou o novo orçamento. O serviço continua com o valor atualizado.';
    }
    
    return GestureDetector(
      onTap: hasDetailedQuote && isQuotePending ? () {
        // Abrir tela de detalhes do orçamento para seleção de peças
        _showQuoteDetailModal(merged, quoteItems, diagnosticValue, isDarkMode);
      } : null,
      child: Container(
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatPriceLabel() ?? '—',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
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
                  ...List<Widget>.from(quoteItems.asMap().entries.map<Widget>((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final description = item['description'] ?? 'Item sem descrição';
                    final quantityRaw = item['quantity'] ?? 1;
                    final quantity = quantityRaw is int ? quantityRaw : (quantityRaw is String ? int.tryParse(quantityRaw) ?? 1 : 1);
                    final unitPriceRaw = item['unit_price'] ?? 0;
                    final unitPriceCents = unitPriceRaw is int ? unitPriceRaw : (unitPriceRaw is String ? int.tryParse(unitPriceRaw) ?? 0 : (unitPriceRaw is double ? unitPriceRaw.toInt() : 0));
                    final unitPrice = unitPriceCents / 100.0;
                    final totalItem = unitPrice * quantity;
                    return Container(
                      margin: EdgeInsets.only(bottom: index < quoteItems.length - 1 ? 12 : 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  description,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 6,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shopping_cart_outlined, size: 12, color: Colors.white.withOpacity(0.8)),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Quantidade: $quantity',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.9),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.attach_money, size: 12, color: Colors.white.withOpacity(0.8)),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Unitário: ${PriceUtils.formatCurrency(unitPrice)}',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.9),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                          Text(
                            PriceUtils.formatCurrency(totalItem) ?? 'R\$ 0,00',
                            style: const TextStyle(
                              color: Colors.white,
                                  fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                              ),
                              Text(
                                'Subtotal',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  })),
                  
                  // Valor do diagnóstico (se houver)
                  if (diagnosticValue != null && diagnosticValue > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Row(
                                  children: [
                                    Icon(Icons.search, color: Colors.white.withOpacity(0.9), size: 16),
                                    const SizedBox(width: 6),
                              const Text(
                                'Diagnóstico',
                                style: TextStyle(
                                  color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                ),
                              ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                              Text(
                                  'Análise inicial do veículo para identificar problemas',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            PriceUtils.formatCurrency(diagnosticValue > 1000 ? diagnosticValue / 100.0 : diagnosticValue) ?? 'R\$ 0,00',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _formatPriceLabel() ?? '—',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
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
      case 'aguardando_aprovacao_orcamento':
      case 'awaiting_quote_approval':
        return 'awaiting_quote_approval';
      case 'aguardando_autorizacao_inicio':
      case 'awaiting_service_start':
        return 'awaiting_service_start';
      case 'veiculo_na_oficina':
      case 'vehicle_at_workshop':
        return 'vehicle_at_workshop';
      case 'aguardando_aprovacao_finalizacao':
      case 'awaiting_finalization_approval':
        return 'awaiting_finalization_approval';
      case 'em_disputa':
      case 'in_dispute':
        return 'in_dispute';
      case 'confirmado':
      case 'confirmed':
      case 'confirmado_oficina':
        return 'confirmed';
      case 'em_andamento':
      case 'in_progress':
      case 'started':
        return 'in_progress';
      case 'finalizado_aguardando_pagamento':
      case 'aguardando_pagamento':
      case 'awaiting_payment':
      case 'finalizado':
      case 'concluido':
      case 'concluído':
      case 'completed':
        return 'awaiting_payment';
      case 'pago':
      case 'paid':
      case 'finalizado_cliente':
        return 'paid';
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
      case 'paid':
        return [const Color(0xFF2FD65C), const Color(0xFF1FC04D)];
      case 'awaiting_payment':
        return [const Color(0xFF00B4D8), const Color(0xFF0077B6)];
      case 'awaiting_quote_approval':
        return [const Color(0xFFFAD961), const Color(0xFFF76B1C)];
      case 'awaiting_service_start':
        return [const Color(0xFF4A90E2), const Color(0xFF357ABD)];
      case 'vehicle_at_workshop':
        return [const Color(0xFF5BC0DE), const Color(0xFF46A8CC)];
      case 'awaiting_finalization_approval':
        return [const Color(0xFF00CED1), const Color(0xFF00A8AA)];
      case 'in_dispute':
        return [const Color(0xFFE8867C), const Color(0xFFD8766C)];
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
      case 'paid':
        return Icons.done_all;
      case 'awaiting_payment':
        return Icons.payments;
      case 'awaiting_quote_approval':
        return Icons.receipt_long;
      case 'awaiting_service_start':
        return Icons.play_circle_outline;
      case 'vehicle_at_workshop':
        return Icons.local_parking;
      case 'awaiting_finalization_approval':
        return Icons.check_circle_outline;
      case 'in_dispute':
        return Icons.warning_amber_rounded;
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
      case 'awaiting_quote_approval':
        return 'Aguardando Aprovação do Orçamento';
      case 'awaiting_service_start':
        return 'Aguardando Autorização de Início';
      case 'vehicle_at_workshop':
        return 'Veículo na Oficina';
      case 'awaiting_finalization_approval':
        return 'Aguardando Aprovação da Finalização';
      case 'in_dispute':
        return 'Em Disputa';
      case 'completed':
      case 'paid':
        return 'Pago';
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
    final merged = _mergeBookingData();
    // IMPORTANTE: Usar status do merged (que já foi corrigido se há sugestão pendente)
    final finalStatus = merged['status'] ?? status;
    final finalNormalizedStatus = _normalizeStatusKey(finalStatus);
    final rawStatus = finalStatus.toLowerCase();
    
    String title = '';
    String description = '';
    String nextStep = '';
    IconData icon = Icons.info;
    Color cardColor = Colors.blue.shade50;
    Color borderColor = Colors.blue.shade200;
    Color iconColor = Colors.blue.shade700;
    
    if (rawStatus == 'pendente_oficina' || finalNormalizedStatus == 'pending') {
      title = 'Aguardando a oficina';
      description = 'Seu pedido já chegou lá. Eles vão responder em instantes.';
      nextStep = 'Fique atento às notificações para aprovação ou sugestão de horário.';
      icon = Icons.schedule;
      cardColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade200;
      iconColor = Colors.orange.shade700;
    } else if (rawStatus == 'confirmado' || finalNormalizedStatus == 'confirmed') {
      title = 'Agendamento confirmado';
      description = 'Dia e horário reservados pra você.';
      nextStep = 'A oficina vai enviar um orçamento ou iniciar no dia combinado.';
      icon = Icons.check_circle;
      cardColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade200;
      iconColor = Colors.blue.shade700;
    } else if (rawStatus == 'aguardando_autorizacao_inicio' || finalNormalizedStatus == 'awaiting_service_start') {
      // Estado explícito: aguardando autorização de início de serviço
      title = 'Serviço Iniciado - Aguardando sua confirmação';
      description = 'A oficina iniciou o atendimento do seu veículo. Por favor, confirme para prosseguir.';
      nextStep = 'Confirme o início do serviço usando o botão abaixo. Após confirmar, o serviço será iniciado oficialmente.';
      icon = Icons.play_circle_outline;
      cardColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade200;
      iconColor = Colors.blue.shade700;
    } else if (rawStatus == 'aguardando_aprovacao_orcamento' || finalNormalizedStatus == 'awaiting_quote_approval') {
      // Estado explícito: aguardando aprovação de orçamento
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
    } else if (rawStatus == 'veiculo_na_oficina' || finalNormalizedStatus == 'vehicle_at_workshop') {
      // Estado explícito: veículo está na oficina (check-in realizado)
      title = 'Veículo na Oficina';
      description = 'Seu veículo está na oficina e pronto para atendimento.';
      nextStep = 'A oficina iniciará o serviço em breve.';
      icon = Icons.local_parking;
      cardColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade200;
      iconColor = Colors.blue.shade700;
    } else if (rawStatus == 'aguardando_aprovacao_finalizacao' || finalNormalizedStatus == 'awaiting_finalization_approval') {
      // Estado explícito: aguardando aprovação da finalização
      title = 'Serviço Finalizado - Aguardando sua aprovação';
      description = 'A oficina finalizou o serviço e enviou o orçamento final.';
      nextStep = 'Revise o orçamento e aprove para liberar o pagamento.';
      icon = Icons.check_circle_outline;
      cardColor = Colors.cyan.shade50;
      borderColor = Colors.cyan.shade200;
      iconColor = Colors.cyan.shade700;
    } else if (rawStatus == 'em_disputa' || finalNormalizedStatus == 'in_dispute') {
      // Estado explícito: em disputa
      title = 'Serviço em Disputa';
      description = 'Há uma pendência que precisa ser resolvida com a oficina.';
      nextStep = 'Entre em contato com a oficina para resolver a questão.';
      icon = Icons.warning_amber_rounded;
      cardColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      iconColor = Colors.red.shade700;
    } else if (rawStatus == 'pendente_cliente' || finalNormalizedStatus == 'pending_customer') {
      // Fallback: status antigo pendente_cliente (para compatibilidade)
      // Verificar se é sugestão de horário, orçamento ou serviço iniciado pendente
      final suggestedBy = merged['suggested_by'] ?? merged['sugerido_por'];
      final hasSuggestedDate = merged['suggested_date'] != null || merged['data_sugerida'] != null;
      final isTimeSuggestion = (suggestedBy == 'oficina' || suggestedBy == 'workshop') && hasSuggestedDate;
      final serviceStartPending = merged['service_start_pending'] == true || merged['service_start_pending'] == 'true';
      
      // Verificar se há orçamento válido
      final hasQuote = _hasFinalPrice() || 
                      (merged['estimated_price'] != null && (merged['estimated_price'] is num ? merged['estimated_price'] > 0 : false)) ||
                      (merged['quote_items'] != null && merged['quote_items'] is List && (merged['quote_items'] as List).isNotEmpty);
      
      // CRITICAL: Se service_start_pending = true E não há orçamento, mostrar card azul de início
      if (serviceStartPending && !hasQuote) {
        // É serviço iniciado pela oficina SEM orçamento, aguardando confirmação do cliente
        title = 'Serviço Iniciado - Aguardando sua confirmação';
        description = 'A oficina iniciou o atendimento do seu veículo. Por favor, confirme para prosseguir.';
        nextStep = 'Confirme o início do serviço usando o botão abaixo. Após confirmar, o serviço será iniciado oficialmente.';
        icon = Icons.play_circle_outline;
        cardColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade200;
        iconColor = Colors.blue.shade700;
      } else if (isTimeSuggestion) {
        // É sugestão de horário da oficina
        title = 'Nova sugestão de horário';
        description = 'A oficina sugeriu um novo horário para o agendamento.';
        nextStep = 'Aceite o horário sugerido ou sugira outro horário.';
        icon = Icons.schedule;
        cardColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade200;
        iconColor = Colors.blue.shade700;
      } else {
        // É orçamento pendente (há orçamento OU service_start_pending = false)
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
    } else if (finalNormalizedStatus == 'in_progress') {
      title = 'Serviço em andamento';
      description = 'Seu veículo está sendo atendido agora.';
      nextStep = 'Avisaremos quando finalizarem para você aprovar.';
      icon = Icons.build_circle;
      cardColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
      iconColor = Colors.green.shade700;
    } else if (finalNormalizedStatus == 'awaiting_payment') {
      title = 'Pagamento pendente';
      description = 'Orçamento aprovado e serviço finalizado.';
      nextStep = 'Use o botão abaixo para pagar agora.';
      icon = Icons.payments;
      cardColor = Colors.cyan.shade50;
      borderColor = Colors.cyan.shade200;
      iconColor = Colors.cyan.shade700;
    } else if (finalNormalizedStatus == 'completed' || finalNormalizedStatus == 'paid' || rawStatus == 'pago') {
      title = 'Pagamento confirmado';
      description = 'Seu pagamento foi processado com sucesso e o serviço está finalizado.';
      nextStep = 'Avalie a experiência quando puder. Obrigado por usar o MECA!';
      icon = Icons.check_circle;
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
    final merged = _mergeBookingData();
    // IMPORTANTE: Usar status do merged (que já foi corrigido se há sugestão pendente)
    final finalStatus = merged['status'] ?? status;
    final normalizedStatus = _normalizeStatusKey(finalStatus);
    final rawStatus = finalStatus.toLowerCase();
    
    // DEBUG: Log para verificar detecção de sugestão
    debugPrint('🔍 [OrderDetail] _buildActionButtons:');
    debugPrint('  - status original: $status');
    debugPrint('  - finalStatus: $finalStatus');
    debugPrint('  - rawStatus: $rawStatus');
    debugPrint('  - merged[sugerido_por]: ${merged['sugerido_por']}');
    debugPrint('  - merged[suggested_by]: ${merged['suggested_by']}');
    debugPrint('  - merged[data_sugerida]: ${merged['data_sugerida']}');
    debugPrint('  - merged[suggested_date]: ${merged['suggested_date']}');
    debugPrint('  - merged[status]: ${merged['status']}');
    debugPrint('  - _bookingDetails[sugerido_por]: ${_bookingDetails?['sugerido_por']}');
    debugPrint('  - _bookingDetails[suggested_by]: ${_bookingDetails?['suggested_by']}');
    debugPrint('  - _bookingDetails[data_sugerida]: ${_bookingDetails?['data_sugerida']}');
    debugPrint('  - _bookingDetails[suggested_date]: ${_bookingDetails?['suggested_date']}');
    debugPrint('  - _bookingDetails[status]: ${_bookingDetails?['status']}');
    
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
    final isTimeSuggestion = (suggestedBy == 'oficina' || suggestedBy == 'workshop') && hasSuggestedDate;
    
    debugPrint('  - suggestedBy: $suggestedBy');
    debugPrint('  - hasSuggestedDate: $hasSuggestedDate');
    debugPrint('  - isTimeSuggestion: $isTimeSuggestion');
    
    final hasQuote = (merged['final_price'] != null && merged['final_price'] > 0) ||
                     (_bookingDetails?['final_price'] != null && _bookingDetails!['final_price'] > 0);
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Card para sugestão de horário da oficina (apenas se não estiver confirmado)
          // IMPORTANTE: Verificar status antes de exibir
          Builder(
            builder: (context) {
              final currentStatus = (merged['status'] ?? '').toString().toLowerCase().trim();
              if (isTimeSuggestion && currentStatus != 'confirmado' && currentStatus != 'confirmed') {
                return Column(
                  children: [
                    _buildTimeSuggestionCard(merged),
                    const SizedBox(height: 20),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Botão para confirmar início do serviço quando serviço foi iniciado pela oficina
          Builder(
            builder: (context) {
              final merged = _mergeBookingData();
              final serviceStartPending = merged['service_start_pending'] == true || merged['service_start_pending'] == 'true';
              final status = merged['status']?.toString() ?? widget.booking['status']?.toString() ?? 'pending';
              final normalizedStatus = _normalizeStatusKey(status);
              final isDarkMode = Theme.of(context).brightness == Brightness.dark;
              
              final rawStatusCheck = status.toLowerCase().trim();
              // Verificar se é estado de aguardando autorização de início OU status antigo pendente_cliente com service_start_pending
              final isAwaitingServiceStart = rawStatusCheck == 'aguardando_autorizacao_inicio' || 
                                            normalizedStatus == 'awaiting_service_start' ||
                                            (serviceStartPending && (rawStatusCheck == 'pendente_cliente' || normalizedStatus == 'pending_customer'));
              if (isAwaitingServiceStart) {
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDarkMode 
                            ? Colors.blue[900]!.withOpacity(0.2) 
                            : Colors.blue[50]!,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue[300]!,
                          width: 2,
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
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.blue,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Serviço Iniciado pela Oficina',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode ? Colors.white : Colors.blue[900]!,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'A oficina iniciou o atendimento',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDarkMode ? Colors.grey[300] : Colors.blue[700]!,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'A oficina iniciou o atendimento do seu veículo. Por favor, confirme para prosseguir oficialmente.',
                            style: TextStyle(
                              fontSize: 15,
                              color: isDarkMode ? Colors.grey[300] : Colors.blue[800]!,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Botões de ACEITAR e REJEITAR início do serviço
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _rejectServiceStart(),
                                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                  label: const Text(
                                    'Rejeitar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[600]!,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 4,
                                    shadowColor: Colors.red.withOpacity(0.4),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _confirmServiceStart(),
                                  icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                  label: const Text(
                                    'Aceitar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[600]!,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 4,
                                    shadowColor: Colors.blue.withOpacity(0.4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Botão para aprovar orçamento quando status for pendente_cliente E não for sugestão de horário E não for serviço iniciado
          Builder(
            builder: (context) {
              final merged = _mergeBookingData();
              final serviceStartPending = merged['service_start_pending'] == true || merged['service_start_pending'] == 'true';
              final status = merged['status']?.toString() ?? widget.booking['status']?.toString() ?? 'pending';
              final normalizedStatus = _normalizeStatusKey(status);
              final isDarkMode = Theme.of(context).brightness == Brightness.dark;
              final rawStatus = status.toLowerCase().trim();
              final isTimeSuggestion = merged['suggested_time'] != null || widget.booking['suggested_time'] != null;
              
              // IMPORTANTE: Verificar se há orçamento válido (final_price OU estimated_price OU quote_items)
              final finalPriceRaw = merged['final_price'] ?? merged['finalPrice'] ?? widget.booking['final_price'] ?? widget.booking['finalPrice'];
              final estimatedPriceRaw = merged['estimated_price'] ?? widget.booking['estimated_price'];
              final finalPrice = finalPriceRaw != null 
                  ? (finalPriceRaw is int ? finalPriceRaw : (finalPriceRaw is double ? finalPriceRaw : (finalPriceRaw is String ? double.tryParse(finalPriceRaw) ?? 0 : 0)))
                  : 0;
              final estimatedPrice = estimatedPriceRaw != null
                  ? (estimatedPriceRaw is int ? estimatedPriceRaw : (estimatedPriceRaw is double ? estimatedPriceRaw : (estimatedPriceRaw is String ? double.tryParse(estimatedPriceRaw) ?? 0 : 0)))
                  : 0;
              
              final quoteItemsRaw = merged['quote_items'] ?? widget.booking['quote_items'];
              final hasQuoteItems = quoteItemsRaw != null && 
                  ((quoteItemsRaw is List && quoteItemsRaw.isNotEmpty) ||
                   (quoteItemsRaw is String && quoteItemsRaw.trim().isNotEmpty && quoteItemsRaw != '[]'));
              
              // IMPORTANTE: Considerar estimated_price também como orçamento válido
              final hasQuote = (finalPrice > 0) || (estimatedPrice > 0) || hasQuoteItems;
              
              // CRITICAL: Se service_start_pending = true, NÃO mostrar botões de orçamento
              // Nesse caso, os botões de ACEITAR/REJEITAR início já estão sendo mostrados no Builder anterior
              if (serviceStartPending) {
                return const SizedBox.shrink();
              }
              
              // Log para debug
              debugPrint('🔍 [OrderDetail] Verificando exibição de orçamento:');
              debugPrint('  - rawStatus: $rawStatus');
              debugPrint('  - finalPriceRaw: $finalPriceRaw');
              debugPrint('  - estimatedPriceRaw: $estimatedPriceRaw');
              debugPrint('  - finalPrice: $finalPrice');
              debugPrint('  - estimatedPrice: $estimatedPrice');
              debugPrint('  - quoteItemsRaw: $quoteItemsRaw');
              debugPrint('  - hasQuoteItems: $hasQuoteItems');
              debugPrint('  - hasQuote: $hasQuote');
              debugPrint('  - isTimeSuggestion: $isTimeSuggestion');
              debugPrint('  - serviceStartPending: $serviceStartPending');
              
              // CRITICAL: Só exibir orçamento se:
              // 1. Status for "aguardando_aprovacao_orcamento" OU "aguardando_aprovacao_finalizacao"
              //    OU "pendente_cliente" com orçamento (compatibilidade)
              // 2. NÃO for sugestão de horário
              // 3. NÃO for service_start_pending sem orçamento (nesse caso, mostrar apenas botões de início)
              // 4. HÁ orçamento válido
              final isAwaitingFinalizationApproval = rawStatus == 'aguardando_aprovacao_finalizacao' ||
                  normalizedStatus == 'awaiting_finalization_approval';
              final isAwaitingQuoteApproval = rawStatus == 'aguardando_aprovacao_orcamento' || 
                                             normalizedStatus == 'awaiting_quote_approval' ||
                                             (rawStatus == 'pendente_cliente' && !isTimeSuggestion && hasQuote && !serviceStartPending);
              final shouldShowQuote = (isAwaitingQuoteApproval || isAwaitingFinalizationApproval) && hasQuote;
              
              debugPrint('  - shouldShowQuote: $shouldShowQuote');
              
              if (!shouldShowQuote) {
                return const SizedBox.shrink();
              }
              
              // Se chegou aqui, significa que deve exibir o card de orçamento
              if (shouldShowQuote) {
                // Card principal de orçamento - DESIGN MODERNO E ELEGANTE
                return Builder(
                  builder: (context) {
                    final merged = _mergeBookingData();
                final quoteItemsRaw = merged['quote_items'] ?? widget.booking['quote_items'];
                
                // Processar quoteItems de forma robusta
                List<dynamic>? quoteItems;
                if (quoteItemsRaw != null) {
                  if (quoteItemsRaw is List) {
                    quoteItems = quoteItemsRaw;
                  } else if (quoteItemsRaw is String) {
                    try {
                      final parsed = jsonDecode(quoteItemsRaw);
                      if (parsed is List) {
                        quoteItems = parsed;
                      }
                    } catch (e) {
                      debugPrint('⚠️ [OrderDetail] Erro ao fazer parse de quote_items (String): $e');
                    }
                  }
                }
                
                final diagnosticValueRaw = merged['diagnostic_value'] ?? widget.booking['diagnostic_value'];
                final diagnosticValue = _parseDiagnosticValue(diagnosticValueRaw);
                final hasDetailedQuote = quoteItems != null && quoteItems.isNotEmpty;
                final hasDiagnostic = diagnosticValue != null && diagnosticValue > 0;
                final finalPriceRaw = _bookingDetails?['final_price'] ?? widget.booking['final_price'];
                final finalPrice = finalPriceRaw != null ? (finalPriceRaw is int ? finalPriceRaw / 100.0 : finalPriceRaw is double ? finalPriceRaw : (finalPriceRaw is String ? double.tryParse(finalPriceRaw) ?? 0.0 : 0.0)) : 0.0;
                final hasCompletedAt = _bookingDetails?['completed_at'] != null || widget.booking['completed_at'] != null;
                
                // Debug: Log para verificar items
                debugPrint('🔍 [OrderDetail] Quote Items Debug:');
                debugPrint('  - quoteItemsRaw type: ${quoteItemsRaw.runtimeType}');
                debugPrint('  - quoteItemsRaw: $quoteItemsRaw');
                debugPrint('  - quoteItems: $quoteItems');
                debugPrint('  - hasDetailedQuote: $hasDetailedQuote');
                debugPrint('  - quoteItems length: ${quoteItems?.length ?? 0}');
                if (quoteItems != null && quoteItems.isNotEmpty) {
                  debugPrint('  - First item: ${quoteItems[0]}');
                  debugPrint('  - First item type: ${quoteItems[0].runtimeType}');
                  debugPrint('  - First item keys: ${quoteItems[0] is Map ? (quoteItems[0] as Map).keys.toList() : 'N/A'}');
                } else {
                  debugPrint('  ⚠️ Nenhum item encontrado!');
                }
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? const Color(0xFF1C1C1E)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                      // Header elegante
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF00C977).withOpacity(0.1),
                              const Color(0xFF00C977).withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                    children: [
                      Container(
                              width: 56,
                              height: 56,
                        decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00C977), Color(0xFF00B369)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00C977).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                                  Text(
                              'Orçamento Disponível',
                              style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.white
                                          : Colors.black87,
                                      letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                                  Text(
                                    hasCompletedAt
                                    ? 'Orçamento final - Aprove para pagar'
                                        : 'Orçamento inicial - Aprove para iniciar',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                      ),
                      
                      // Valor total destacado
                      Container(
                        padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? const Color(0xFF2C2C2E)
                              : Colors.grey[50],
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.grey[800]!
                                  : Colors.grey[200]!,
                              width: 1,
                            ),
                            bottom: BorderSide(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.grey[800]!
                                  : Colors.grey[200]!,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Valor Total',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.grey[300]
                                      : Colors.grey[700],
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  PriceUtils.formatCurrency(finalPrice) ?? 'R\$ 0,00',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF00C977),
                                  letterSpacing: -1,
                                ),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                              ),
                            ),
                          ),
                          ],
                        ),
                      ),
                      
                      // Breakdown detalhado - DESIGN MODERNO
                      if (hasDetailedQuote || hasDiagnostic) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.grey[800]!
                                    : Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                      ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              Text(
                                'Detalhamento',
                                  style: TextStyle(
                                    fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.grey[300]
                                      : Colors.grey[700],
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                                // Items do orçamento
                              if (hasDetailedQuote && quoteItems != null) ...[
                                ...List<Widget>.from(quoteItems!.asMap().entries.map<Widget>((entry) {
                                  final index = entry.key;
                                  final item = entry.value;
                                  final description = item['description'] ?? 'Item sem descrição';
                                  final quantityRaw = item['quantity'] ?? 1;
                                  final quantity = quantityRaw is int ? quantityRaw : (quantityRaw is String ? int.tryParse(quantityRaw) ?? 1 : 1);
                                  final unitPriceRaw = item['unit_price'] ?? 0;
                                  final unitPriceCents = unitPriceRaw is int ? unitPriceRaw : (unitPriceRaw is String ? int.tryParse(unitPriceRaw) ?? 0 : (unitPriceRaw is double ? unitPriceRaw.toInt() : 0));
                                  final unitPrice = unitPriceCents / 100.0;
                                  final totalItem = unitPrice * quantity;
                                  
                                  return Container(
                                    margin: EdgeInsets.only(bottom: index < (quoteItems?.length ?? 0) - 1 ? 12 : 0),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? const Color(0xFF2C2C2E)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Theme.of(context).brightness == Brightness.dark 
                                            ? Colors.grey[700]!
                                            : Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Conteúdo principal - título e detalhes
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Título do item - destaque principal
                                              Text(
                                                description,
                                                style: TextStyle(
                                                  color: Theme.of(context).brightness == Brightness.dark 
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -0.4,
                                                  height: 1.3,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              // Linha simples e limpa: "1x R$ 10,00"
                                              Text(
                                                '$quantity${quantity > 1 ? 'x' : 'x'} ${PriceUtils.formatCurrency(unitPrice)}',
                                                style: TextStyle(
                                                  color: Theme.of(context).brightness == Brightness.dark 
                                                      ? Colors.grey[400]
                                                      : Colors.grey[600],
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  letterSpacing: -0.2,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Valor total - destaque verde à direita
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                        Text(
                                          PriceUtils.formatCurrency(totalItem) ?? 'R\$ 0,00',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFF00C977),
                                                  letterSpacing: -0.6,
                                                  height: 1.2,
                                                ),
                                                textAlign: TextAlign.end,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                })),
                                if (hasDiagnostic) const SizedBox(height: 12),
                              ],
                                
                                // Valor do diagnóstico (se houver)
                              if (hasDiagnostic) ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark 
                                        ? const Color(0xFF2C2C2E)
                                        : Colors.blue[50],
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.blue[800]!
                                          : Colors.blue[200]!,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blue[400]!,
                                              Colors.blue[600]!,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Diagnóstico',
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                          Text(
                                              'Análise inicial do veículo',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w400,
                                                color: Theme.of(context).brightness == Brightness.dark 
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          PriceUtils.formatCurrency(diagnosticValue > 1000 ? diagnosticValue / 100.0 : diagnosticValue) ?? 'R\$ 0,00',
                                      style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.blue[700],
                                            letterSpacing: -0.5,
                                          ),
                                          textAlign: TextAlign.end,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                      ),
                                    ),
                                  ],
                            ],
                          ),
                        ),
                      ],
                        ],
                      ),
                          );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Exibir motivo do orçamento (se houver)
          Builder(
              builder: (context) {
                final merged = _mergeBookingData();
                final quoteReason = merged['quote_reason'] ?? widget.booking['quote_reason'];
                
                if (quoteReason == null || (quoteReason is String && quoteReason.trim().isEmpty)) {
                  return const SizedBox.shrink();
                }
                
                return Container(
                  margin: const EdgeInsets.only(top: 24, bottom: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? const Color(0xFF2C2C2E)
                        : Colors.purple[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.purple[800]!
                          : Colors.purple[200]!,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple[400]!,
                                  Colors.purple[600]!,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.note_alt_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Motivo do Orçamento',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.white
                                    : Colors.purple[900],
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        quoteReason.toString(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.grey[300]
                              : Colors.grey[800],
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          // Botões de ação - DESIGN MODERNO E ELEGANTE
          // IMPORTANTE: Só exibir se houver orçamento válido e status correto
          Builder(
            builder: (context) {
              final merged = _mergeBookingData();
              final serviceStartPending = merged['service_start_pending'] == true || merged['service_start_pending'] == 'true';
              final status = merged['status']?.toString() ?? widget.booking['status']?.toString() ?? 'pending';
              final rawStatus = status.toLowerCase().trim();
              final isTimeSuggestion = merged['suggested_time'] != null || widget.booking['suggested_time'] != null;
              
              // IMPORTANTE: Verificar se há orçamento válido (final_price OU estimated_price OU quote_items)
              final finalPriceRaw = merged['final_price'] ?? merged['finalPrice'] ?? widget.booking['final_price'] ?? widget.booking['finalPrice'];
              final estimatedPriceRaw = merged['estimated_price'] ?? widget.booking['estimated_price'];
              final finalPrice = finalPriceRaw != null 
                  ? (finalPriceRaw is int ? finalPriceRaw : (finalPriceRaw is double ? finalPriceRaw : (finalPriceRaw is String ? double.tryParse(finalPriceRaw) ?? 0 : 0)))
                  : 0;
              final estimatedPrice = estimatedPriceRaw != null
                  ? (estimatedPriceRaw is int ? estimatedPriceRaw : (estimatedPriceRaw is double ? estimatedPriceRaw : (estimatedPriceRaw is String ? double.tryParse(estimatedPriceRaw) ?? 0 : 0)))
                  : 0;
              
              final quoteItemsRaw = merged['quote_items'] ?? widget.booking['quote_items'];
              final hasQuoteItems = quoteItemsRaw != null && 
                  ((quoteItemsRaw is List && quoteItemsRaw.isNotEmpty) ||
                   (quoteItemsRaw is String && quoteItemsRaw.trim().isNotEmpty && quoteItemsRaw != '[]'));
              
              // IMPORTANTE: Considerar estimated_price também como orçamento válido
              final hasQuote = (finalPrice > 0) || (estimatedPrice > 0) || hasQuoteItems;
              
              // CRITICAL: Se service_start_pending = true, NÃO mostrar botões de orçamento
              // Nesse caso, os botões de ACEITAR/REJEITAR início já estão sendo mostrados no Builder anterior
              if (serviceStartPending) {
                return const SizedBox.shrink();
              }
              
              // IMPORTANTE: Quando status é 'aguardando_aprovacao_orcamento' OU 'pendente_cliente' com orçamento, mostrar botões de aprovar/rejeitar orçamento
              // A lógica correta é: mostrar se status é aguardando_aprovacao_orcamento OU (pendente_cliente E não é sugestão de horário E há orçamento)
              final isAwaitingFinalizationApproval = rawStatus == 'aguardando_aprovacao_finalizacao' ||
                  normalizedStatus == 'awaiting_finalization_approval';
              final isAwaitingQuoteApproval = rawStatus == 'aguardando_aprovacao_orcamento' || 
                                             normalizedStatus == 'awaiting_quote_approval' ||
                                             (rawStatus == 'pendente_cliente' && !isTimeSuggestion && hasQuote);
              final shouldShowQuote = (isAwaitingQuoteApproval || isAwaitingFinalizationApproval) && hasQuote;
              
              debugPrint('🔍 [OrderDetail] Verificando exibição de BOTÕES de orçamento:');
              debugPrint('  - rawStatus: $rawStatus');
              debugPrint('  - finalPrice: $finalPrice');
              debugPrint('  - hasQuoteItems: $hasQuoteItems');
              debugPrint('  - hasQuote: $hasQuote');
              debugPrint('  - shouldShowQuote: $shouldShowQuote');
              
              if (!shouldShowQuote) {
                return const SizedBox.shrink();
              }
              
              return Column(
                children: [
                  const SizedBox(height: 24),
                  // Botão de aprovar
                  Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C977), Color(0xFF00B369)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C977).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isAwaitingFinalizationApproval ? _approveFinalization : _approveQuote,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isAwaitingFinalizationApproval ? 'Aprovar finalização' : 'Aprovar Orçamento',
                    style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                      color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Botão de rejeitar
            Builder(
              builder: (context) {
                final merged = _mergeBookingData();
                final quoteStatus = merged['quote_status'] ?? widget.booking['quote_status'];
                final isFinalQuote = quoteStatus == 'final';
                
                // IMPORTANTE: na aprovação da finalização, sempre permitir rejeição (vira disputa)
                if (!isAwaitingFinalizationApproval && isFinalQuote) {
                  return const SizedBox.shrink();
                }
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[700]!
                          : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => isAwaitingFinalizationApproval ? _rejectFinalization() : _rejectQuote(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                            Icon(
                              Icons.close_rounded,
                              color: Colors.red[600],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isAwaitingFinalizationApproval ? 'Rejeitar finalização' : 'Rejeitar Orçamento',
                          style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.red[600],
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                          ),
                        ),
                      ),
                    ),
                );
              },
            ),
            
            // Mensagem informativa - DESIGN MODERNO
            Builder(
              builder: (context) {
                final merged = _mergeBookingData();
                final hasCompletedAt = _bookingDetails?['completed_at'] != null || widget.booking['completed_at'] != null;
                final quoteStatus = merged['quote_status'] ?? widget.booking['quote_status'];
                final isFinalQuote = quoteStatus == 'final';
                final diagnosticValueRaw = merged['diagnostic_value'] ?? widget.booking['diagnostic_value'];
                final diagnosticValue = _parseDiagnosticValue(diagnosticValueRaw);
                final hasDiagnostic = diagnosticValue != null && diagnosticValue > 0;
                
                String message;
                Color bgColor;
                Color textColor;
                Color iconBgColor;
                
                if (isFinalQuote) {
                  message = 'Este é o orçamento final após o serviço. Aprove para realizar o pagamento.';
                  bgColor = Theme.of(context).brightness == Brightness.dark 
                      ? Colors.green[900]!.withOpacity(0.2)
                      : Colors.green[50]!;
                  textColor = Theme.of(context).brightness == Brightness.dark 
                      ? Colors.green[300]!
                      : Colors.green[900]!;
                  iconBgColor = Colors.green[600]!;
                } else if (hasCompletedAt) {
                  message = 'Após aprovar, você poderá realizar o pagamento do serviço.';
                  bgColor = Theme.of(context).brightness == Brightness.dark 
                      ? Colors.blue[900]!.withOpacity(0.2)
                      : Colors.blue[50]!;
                  textColor = Theme.of(context).brightness == Brightness.dark 
                      ? Colors.blue[300]!
                      : Colors.blue[900]!;
                  iconBgColor = Colors.blue[600]!;
                } else {
                  final diagnosticInReais = diagnosticValue != null 
                      ? (diagnosticValue > 1000 ? diagnosticValue / 100.0 : diagnosticValue)
                      : 0.0;
                  message = hasDiagnostic
                      ? 'Ao aprovar, a oficina iniciará o serviço. Se rejeitar, você pagará apenas o diagnóstico (${PriceUtils.formatCurrency(diagnosticInReais)}).'
                      : 'Após aprovar, a oficina poderá iniciar o serviço.';
                  bgColor = Theme.of(context).brightness == Brightness.dark 
                      ? Colors.blue[900]!.withOpacity(0.2)
                      : Colors.blue[50]!;
                  textColor = Theme.of(context).brightness == Brightness.dark 
                      ? Colors.blue[300]!
                      : Colors.blue[900]!;
                  iconBgColor = Colors.blue[600]!;
                }
                
                return Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[800]!
                          : Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: iconBgColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: iconBgColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
                ],
              );
            },
          ),
          Builder(
            builder: (context) {
              final merged = _mergeBookingData();
              final finalStatus = merged['status'] ?? widget.booking['status'] ?? 'pending';
              final normalizedStatus = _normalizeStatusKey(finalStatus);
              if (normalizedStatus == 'in_progress' ||
                  normalizedStatus == 'awaiting_finalization_approval' ||
                  normalizedStatus == 'in_dispute' ||
                  normalizedStatus == 'awaiting_payment' ||
                  normalizedStatus == 'completed' ||
                  normalizedStatus == 'paid') {
                return Column(
                  children: [
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
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Builder(
            builder: (context) {
              final merged = _mergeBookingData();
              final finalStatus = merged['status'] ?? widget.booking['status'] ?? 'pending';
              final normalizedStatus = _normalizeStatusKey(finalStatus);
              
              // NÃO mostrar botão de pagamento se status for 'pago' ou 'paid'
              final rawStatus = finalStatus.toString().toLowerCase().trim();
              final isPaid = rawStatus == 'pago' || rawStatus == 'paid' || normalizedStatus == 'paid';
              
              // Só mostrar botão se realmente estiver aguardando pagamento E não estiver pago
              if (normalizedStatus == 'awaiting_payment' && !isPaid) {
                return Column(
                  children: [
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
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Builder(
            builder: (context) {
              final merged = _mergeBookingData();
              final finalStatus = merged['status'] ?? widget.booking['status'] ?? 'pending';
              final normalizedStatus = _normalizeStatusKey(finalStatus);
              if (normalizedStatus == 'completed' || normalizedStatus == 'paid') {
                return Column(
                  children: [
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
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  void _showQuoteDetailModal(Map<String, dynamic> merged, List quoteItems, dynamic diagnosticValue, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuoteDetailModal(
        booking: merged,
        quoteItems: quoteItems,
        diagnosticValue: diagnosticValue,
        isDarkMode: isDarkMode,
        onApprove: (selectedItems) => _approveQuoteWithItems(selectedItems),
        onReject: () => _rejectQuote(),
      ),
    );
  }

  Future<void> _approveQuoteWithItems(List<Map<String, dynamic>>? selectedItems) async {
    // Por enquanto, aprovar tudo - depois podemos implementar seleção parcial
    await _approveQuote();
  }

  /// Confirmar início do serviço quando a oficina iniciou
  Future<void> _confirmServiceStart() async {
    final bookingId = widget.booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) {
      AppAlerts.showError(context, message: 'Erro: ID do agendamento não encontrado.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.play_circle_outline, color: Colors.blue, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Confirmar Início do Serviço',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deseja confirmar o início do serviço?',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Após confirmar, o serviço será iniciado oficialmente e você poderá acompanhar o progresso.',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400]! : Colors.grey[700]!,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600]!,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Confirmar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await _apiService.confirmServiceStart(bookingId);
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        _apiService.invalidateBookingsCache();
        _apiService.invalidateBookingCache(bookingId);
        
        await _loadBookingDetails(forceRefresh: true);
        
        AppAlerts.showSuccess(
          context,
          message: 'Serviço confirmado com sucesso! O atendimento do seu veículo foi iniciado oficialmente.',
        );
        
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });
      } else {
        AppAlerts.showError(
          context,
          message: result['error']?.toString() ?? 'Erro ao confirmar início do serviço.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppAlerts.showError(
        context,
        message: 'Erro: ${e.toString()}',
      );
    }
  }

  /// Rejeitar início do serviço quando a oficina iniciou
  Future<void> _rejectServiceStart() async {
    final bookingId = widget.booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) {
      AppAlerts.showError(context, message: 'Erro: ID do agendamento não encontrado.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Rejeitar Início do Serviço',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deseja rejeitar o início do serviço?',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ao rejeitar, o agendamento voltará ao status confirmado e a oficina precisará aguardar sua aprovação novamente.',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400]! : Colors.grey[700]!,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600]!,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Rejeitar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await _apiService.rejectServiceStart(bookingId);
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        _apiService.invalidateBookingsCache();
        _apiService.invalidateBookingCache(bookingId);
        
        await _loadBookingDetails(forceRefresh: true);
        
        AppAlerts.showSuccess(
          context,
          message: 'Início do serviço rejeitado. O agendamento voltou ao status confirmado.',
        );
        
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });
      } else {
        AppAlerts.showError(
          context,
          message: result['error']?.toString() ?? 'Erro ao rejeitar início do serviço.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppAlerts.showError(
        context,
        message: 'Erro: ${e.toString()}',
      );
    }
  }

  Future<void> _approveQuote() async {
    final bookingId = widget.booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) {
      AppAlerts.showError(context, message: 'Erro: ID do agendamento não encontrado.');
      return;
    }

    // Verificar se é orçamento editado
    final merged = _mergeBookingData();
    final statusHistoryRaw = merged['status_history'] ?? widget.booking['status_history'];
    bool isEditedQuote = false;
    Map<String, dynamic>? previousQuote = null;
    try {
      if (statusHistoryRaw != null) {
        final statusHistory = statusHistoryRaw is String 
            ? jsonDecode(statusHistoryRaw) 
            : statusHistoryRaw;
        if (statusHistory is Map && statusHistory['previous_quote'] != null) {
          isEditedQuote = true;
          previousQuote = statusHistory['previous_quote'] is Map 
              ? Map<String, dynamic>.from(statusHistory['previous_quote'])
              : null;
        }
      }
    } catch (e) {
      // Ignorar erro de parsing
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditedQuote ? '⚠️ Aprovar Orçamento Atualizado' : 'Aprovar Orçamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEditedQuote 
                ? 'A oficina alterou o orçamento durante o serviço. Você confirma a aprovação do novo valor?'
                : 'Você confirma a aprovação deste orçamento?'),
            if (isEditedQuote && previousQuote != null) ...[
              const SizedBox(height: 16),
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
                        Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Valor anterior: ${PriceUtils.formatCurrency(previousQuote['final_price']) ?? 'R\$ 0,00'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade700,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.attach_money, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Novo valor: ${PriceUtils.formatCurrency(_bookingDetails?['final_price'] ?? widget.booking['final_price']) ?? 'R\$ 0,00'}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (_bookingDetails?['final_price'] != null || widget.booking['final_price'] != null) ...[
              const SizedBox(height: 16),
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
                      'Valor: ${PriceUtils.formatCurrency(_bookingDetails?['final_price'] ?? widget.booking['final_price']) ?? 'R\$ 0,00'}',
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
            if (isEditedQuote) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ao aprovar, o serviço continuará com o novo valor. Se rejeitar, o orçamento anterior será restaurado.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
        // IMPORTANTE: Invalidar cache de bookings para forçar reload
        _apiService.invalidateBookingsCache();
        _apiService.invalidateBookingCache(bookingId);
        
        // Recarregar detalhes do agendamento
        await _loadBookingDetails(forceRefresh: true);
        
        // Verificar se é orçamento inicial ou final
        final hasCompletedAt = _bookingDetails?['completed_at'] != null || widget.booking['completed_at'] != null;
        final newStatus = result['data']?['status']?.toString().toLowerCase() ?? 
                         (hasCompletedAt ? 'finalizado_aguardando_pagamento' : 'confirmado');
        
        String message;
        if (isEditedQuote) {
          message = 'Orçamento atualizado aprovado com sucesso! O serviço continuará com o novo valor.';
        } else {
          message = hasCompletedAt
              ? 'Orçamento aprovado com sucesso! Agora você pode realizar o pagamento.'
              : 'Orçamento aprovado com sucesso! A oficina pode iniciar o serviço agora.';
        }
        
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
        
        // IMPORTANTE: Retornar true para indicar que houve atualização
        // Navegar de volta após um delay para permitir que a tela anterior atualize
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.of(context).pop(true); // Passar true para indicar refresh necessário
          }
        });
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
    
    // IMPORTANTE: Não exibir card se já está confirmado
    final status = (merged['status'] ?? '').toString().toLowerCase().trim();
    if (status == 'confirmado' || status == 'confirmed') {
      return const SizedBox.shrink();
    }
    
    final suggestedDateStr = merged['suggested_date'] ?? merged['data_sugerida'];
    if (suggestedDateStr == null) return const SizedBox.shrink();
    
    // IMPORTANTE: Verificar se há sugestão pendente da oficina
    final suggestedBy = merged['suggested_by'] ?? merged['sugerido_por'];
    if (suggestedBy != 'oficina' && suggestedBy != 'workshop') {
      return const SizedBox.shrink();
    }
    
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
        // IMPORTANTE: Atualizar dados antes de mostrar sucesso (forçar refresh)
        await _loadBookingDetails(forceRefresh: true);
        setState(() {
          widget.booking['status'] = 'confirmado';
          widget.booking['data_sugerida'] = null;
          widget.booking['sugerido_por'] = null;
          widget.booking['suggested_date'] = null;
          widget.booking['suggested_by'] = null;
          if (_bookingDetails != null) {
            _bookingDetails!['status'] = 'confirmado';
            _bookingDetails!['data_sugerida'] = null;
            _bookingDetails!['sugerido_por'] = null;
            _bookingDetails!['suggested_date'] = null;
            _bookingDetails!['suggested_by'] = null;
          }
        });
        AppAlerts.showSuccess(
          context,
          message: 'Horário aceito com sucesso! O agendamento está confirmado.',
        );
        // IMPORTANTE: Retornar true para indicar que houve atualização
        // Navegar de volta após um delay para permitir que a tela anterior atualize
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.of(context).pop(true); // Passar true para indicar refresh necessário
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
        // IMPORTANTE: Invalidar cache de bookings para forçar reload
        _apiService.invalidateBookingsCache();
        _apiService.invalidateBookingCache(bookingId);
        
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
    final diagnosticValueRaw = merged['diagnostic_value'] ?? widget.booking['diagnostic_value'];
    final diagnosticValue = _parseDiagnosticValue(diagnosticValueRaw);
    final hasDiagnostic = diagnosticValue != null && diagnosticValue > 0;
    
    // Verificar se é orçamento editado
    final statusHistoryRaw = merged['status_history'] ?? widget.booking['status_history'];
    bool isEditedQuote = false;
    Map<String, dynamic>? previousQuote = null;
    try {
      if (statusHistoryRaw != null) {
        final statusHistory = statusHistoryRaw is String 
            ? jsonDecode(statusHistoryRaw) 
            : statusHistoryRaw;
        if (statusHistory is Map && statusHistory['previous_quote'] != null) {
          isEditedQuote = true;
          previousQuote = statusHistory['previous_quote'] is Map 
              ? Map<String, dynamic>.from(statusHistory['previous_quote'])
              : null;
        }
      }
    } catch (e) {
      // Ignorar erro de parsing
    }
    
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
        title: Text(isEditedQuote ? '⚠️ Rejeitar Orçamento Atualizado' : 'Rejeitar Orçamento'),
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEditedQuote 
                ? 'Você confirma a rejeição do orçamento atualizado? O orçamento anterior será restaurado automaticamente e o serviço continuará com o valor original.'
                : 'Você confirma a rejeição deste orçamento?'),
            if (isEditedQuote && previousQuote != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Orçamento anterior será restaurado:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.attach_money, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Valor original: ${PriceUtils.formatCurrency(previousQuote['final_price']) ?? 'R\$ 0,00'}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
                      'Valor: ${PriceUtils.formatCurrency(_bookingDetails?['final_price'] ?? widget.booking['final_price']) ?? 'R\$ 0,00'}',
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
          message: isEditedQuote 
              ? 'Orçamento atualizado rejeitado. O orçamento anterior foi restaurado e o serviço continuará com o valor original. A oficina foi notificada.'
              : 'Orçamento rejeitado com sucesso. A oficina foi notificada e poderá enviar um novo orçamento.',
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

  Future<void> _approveFinalization() async {
    final bookingId = widget.booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) {
      AppAlerts.showError(context, message: 'Erro: ID do agendamento não encontrado.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprovar finalização'),
        content: const Text(
          'A oficina informou que o serviço foi finalizado e enviou o orçamento final.\n\n'
          'Ao aprovar, você libera o pagamento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aprovar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await _apiService.approveFinalization(bookingId);
      if (!mounted) return;

      if (result['success'] == true) {
        _apiService.invalidateBookingsCache();
        _apiService.invalidateBookingCache(bookingId);

        await _loadBookingDetails(forceRefresh: true);

        setState(() {
          widget.booking['status'] = 'finalizado_aguardando_pagamento';
          if (_bookingDetails != null) {
            _bookingDetails!['status'] = 'finalizado_aguardando_pagamento';
          }
        });

        AppAlerts.showSuccess(
          context,
          message: 'Finalização aprovada. Agora você pode prosseguir com o pagamento.',
        );
      } else {
        AppAlerts.showError(
          context,
          message: result['error']?.toString() ?? 'Erro ao aprovar finalização.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppAlerts.showError(
        context,
        message: 'Erro ao aprovar finalização: ${e.toString()}',
      );
    }
  }

  Future<void> _rejectFinalization() async {
    final bookingId = widget.booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) {
      AppAlerts.showError(context, message: 'Erro: ID do agendamento não encontrado.');
      return;
    }

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeitar finalização'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se você rejeitar, o agendamento entrará em disputa para a oficina revisar.\n\n'
                'Você pode informar um motivo (opcional).',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Motivo (opcional)',
                  hintText: 'Ex.: itens/valores não conferem…',
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rejeitar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await _apiService.rejectFinalization(
        bookingId,
        reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      );
      if (!mounted) return;

      if (result['success'] == true) {
        _apiService.invalidateBookingsCache();
        _apiService.invalidateBookingCache(bookingId);

        await _loadBookingDetails(forceRefresh: true);

        setState(() {
          widget.booking['status'] = 'em_disputa';
          if (_bookingDetails != null) {
            _bookingDetails!['status'] = 'em_disputa';
          }
        });

        AppAlerts.showSuccess(
          context,
          message: 'Finalização rejeitada. O agendamento entrou em disputa.',
        );
      } else {
        AppAlerts.showError(
          context,
          message: result['error']?.toString() ?? 'Erro ao rejeitar finalização.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppAlerts.showError(
        context,
        message: 'Erro ao rejeitar finalização: ${e.toString()}',
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
    final merged = _mergeBookingData();
    final serviceStartPending = merged['service_start_pending'] == true || merged['service_start_pending'] == 'true';
    
    // CRITICAL: Se service_start_pending = true e não há orçamento, NÃO mostrar card de orçamento
    if (serviceStartPending) {
      final hasQuote = _hasFinalPrice() || 
                      (merged['estimated_price'] != null && (merged['estimated_price'] is num ? merged['estimated_price'] > 0 : false)) ||
                      (merged['quote_items'] != null && merged['quote_items'] is List && (merged['quote_items'] as List).isNotEmpty);
      if (!hasQuote) {
        return false; // Não mostrar orçamento se apenas iniciou serviço sem orçamento
      }
    }
    
    return _hasFinalPrice() && !_isAwaitingClientQuote();
  }

  bool _shouldShowEstimateNotice() {
    final merged = _mergeBookingData();
    final serviceStartPending = merged['service_start_pending'] == true || merged['service_start_pending'] == 'true';
    
    // CRITICAL: Se service_start_pending = true e não há orçamento, NÃO mostrar card de estimativa
    if (serviceStartPending) {
      final hasQuote = _hasFinalPrice() || 
                      (merged['estimated_price'] != null && (merged['estimated_price'] is num ? merged['estimated_price'] > 0 : false)) ||
                      (merged['quote_items'] != null && merged['quote_items'] is List && (merged['quote_items'] as List).isNotEmpty);
      if (!hasQuote) {
        return false; // Não mostrar estimativa se apenas iniciou serviço sem orçamento
      }
    }
    
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
      
      // DEBUG: Log para verificar valor bruto
      debugPrint('💰 [OrderDetail] _extractFinalPriceFromMap: key=$key, raw=$candidate, type=${candidate.runtimeType}');
      
      final parsed = _parseBackendPrice(candidate);
      
      // DEBUG: Log para verificar valor convertido
      if (parsed != null && parsed > 0) {
        debugPrint('💰 [OrderDetail] _extractFinalPriceFromMap: parsed=$parsed (R\$ ${parsed.toStringAsFixed(2)})');
        return parsed;
      }
    }
    return null;
  }

  /// Converte diagnostic_value para número (pode vir como String, int ou double)
  double? _parseDiagnosticValue(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      return double.tryParse(raw);
    } else if (raw is int) {
      return raw.toDouble();
    } else if (raw is double) {
      return raw;
    }
    return null;
  }

  double? _parseBackendPrice(dynamic raw) {
    if (raw == null) return null;

    if (raw is num) {
      final value = raw.toDouble();
      if (value == 0) return null;
      
      // IMPORTANTE: A API sempre salva valores em centavos (inteiros)
      // Se o valor é um inteiro, SEMPRE assumir que está em centavos e converter para reais
      // A API nunca retorna valores em reais como inteiros, sempre em centavos
      if (value % 1 == 0) {
        // DEBUG: Log para verificar conversão
        final converted = value / 100;
        debugPrint('💰 [OrderDetail] _parseBackendPrice: integer $value (centavos) -> $converted (reais)');
        return converted;
      }
      // Se já tem decimais, assumir que já está em reais (caso raro, mas possível)
      debugPrint('💰 [OrderDetail] _parseBackendPrice: decimal $value (já em reais)');
      return value;
    }

    if (raw is String) {
      final cleaned = raw.trim();
      if (cleaned.isEmpty) return null;
      final parsed = double.tryParse(cleaned.replaceAll(',', '.'));
      if (parsed == null || parsed == 0) return null;
      
      // Se a string contém ponto ou vírgula, assumir que já está formatado em reais
      if (cleaned.contains('.') || cleaned.contains(',')) {
        debugPrint('💰 [OrderDetail] _parseBackendPrice: string "$cleaned" (já em reais) -> $parsed');
        return parsed;
      }
      
      // Se é um inteiro sem decimais, assumir centavos
      if (parsed % 1 == 0) {
        final converted = parsed / 100;
        debugPrint('💰 [OrderDetail] _parseBackendPrice: string integer "$cleaned" (centavos) -> $converted (reais)');
        return converted;
      }
      return parsed;
    }

    return null;
  }

  Widget _buildEstimateInfoCard(bool isDarkMode) {
    final merged = _mergeBookingData();
    final serviceStartPending = merged['service_start_pending'] == true || merged['service_start_pending'] == 'true';
    
    // CRITICAL: Se service_start_pending = true e não há orçamento, NÃO mostrar card de estimativa
    if (serviceStartPending) {
      final hasQuote = _hasFinalPrice() || 
                      (merged['estimated_price'] != null && (merged['estimated_price'] is num ? merged['estimated_price'] > 0 : false)) ||
                      (merged['quote_items'] != null && merged['quote_items'] is List && (merged['quote_items'] as List).isNotEmpty);
      if (!hasQuote) {
        return const SizedBox.shrink(); // Não mostrar estimativa se apenas iniciou serviço sem orçamento
      }
    }
    
    final awaitingQuote = _isAwaitingClientQuote();
    final estimatedPrice = _resolveServiceAmount(merged);
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

// Widget Modal para detalhes do orçamento com seleção de peças
class QuoteDetailModal extends StatefulWidget {
  final Map<String, dynamic> booking;
  final List quoteItems;
  final dynamic diagnosticValue;
  final bool isDarkMode;
  final Function(List<Map<String, dynamic>>?) onApprove;
  final VoidCallback onReject;

  const QuoteDetailModal({
    Key? key,
    required this.booking,
    required this.quoteItems,
    required this.diagnosticValue,
    required this.isDarkMode,
    required this.onApprove,
    required this.onReject,
  }) : super(key: key);

  @override
  State<QuoteDetailModal> createState() => _QuoteDetailModalState();
}

class _QuoteDetailModalState extends State<QuoteDetailModal> {
  final Map<String, bool> _selectedItems = {};
  bool _allSelected = true;

  @override
  void initState() {
    super.initState();
    // Inicializar todos os itens como selecionados
    for (var i = 0; i < widget.quoteItems.length; i++) {
      _selectedItems[i.toString()] = true;
    }
  }

  void _toggleItem(int index) {
    setState(() {
      _selectedItems[index.toString()] = !(_selectedItems[index.toString()] ?? false);
      _allSelected = _selectedItems.values.every((selected) => selected);
    });
  }

  void _toggleAll() {
    setState(() {
      _allSelected = !_allSelected;
      for (var i = 0; i < widget.quoteItems.length; i++) {
        _selectedItems[i.toString()] = _allSelected;
      }
    });
  }

  List<Map<String, dynamic>> _getSelectedItems() {
    final selected = <Map<String, dynamic>>[];
    for (var entry in _selectedItems.entries) {
      if (entry.value) {
        final index = int.parse(entry.key);
        if (index < widget.quoteItems.length) {
          selected.add(Map<String, dynamic>.from(widget.quoteItems[index]));
        }
      }
    }
    return selected;
  }

  double? _parseDiagnosticValue(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      return double.tryParse(raw);
    } else if (raw is int) {
      return raw.toDouble();
    } else if (raw is double) {
      return raw;
    }
    return null;
  }

  double _calculateSelectedTotal() {
    double total = 0;
    for (var entry in _selectedItems.entries) {
      if (entry.value) {
        final index = int.parse(entry.key);
        if (index < widget.quoteItems.length) {
          final item = widget.quoteItems[index];
          final quantityRaw = item['quantity'] ?? 1;
          final quantity = quantityRaw is int ? quantityRaw : (quantityRaw is String ? int.tryParse(quantityRaw) ?? 1 : 1);
          final unitPriceRaw = item['unit_price'] ?? 0;
          final unitPriceCents = unitPriceRaw is int ? unitPriceRaw : (unitPriceRaw is String ? int.tryParse(unitPriceRaw) ?? 0 : (unitPriceRaw is double ? unitPriceRaw.toInt() : 0));
          final unitPrice = unitPriceCents / 100.0;
          total += unitPrice * quantity;
        }
      }
    }
    final diagnosticValue = _parseDiagnosticValue(widget.diagnosticValue);
    if (diagnosticValue != null && diagnosticValue > 0) {
      // Se > 1000, provavelmente está em centavos, converter para reais
      total += diagnosticValue > 1000 ? diagnosticValue / 100.0 : diagnosticValue;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final selectedTotal = _calculateSelectedTotal();
    final allSelected = _selectedItems.values.every((selected) => selected);
    final hasSelection = _selectedItems.values.any((selected) => selected);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00C977), Color(0xFF00B369)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detalhes do Orçamento',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Selecione os itens que deseja aprovar',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Lista de itens
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Checkbox para selecionar todos
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _allSelected,
                        onChanged: (_) => _toggleAll(),
                        activeColor: const Color(0xFF00C977),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Selecionar todos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: widget.isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Lista de itens do orçamento
                ...widget.quoteItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = _selectedItems[index.toString()] ?? false;
                  final description = item['description'] ?? 'Item sem descrição';
                  final quantityRaw = item['quantity'] ?? 1;
                  final quantity = quantityRaw is int ? quantityRaw : (quantityRaw is String ? int.tryParse(quantityRaw) ?? 1 : 1);
                  final unitPriceRaw = item['unit_price'] ?? 0;
                  final unitPriceCents = unitPriceRaw is int ? unitPriceRaw : (unitPriceRaw is String ? int.tryParse(unitPriceRaw) ?? 0 : (unitPriceRaw is double ? unitPriceRaw.toInt() : 0));
                  final unitPrice = unitPriceCents / 100.0;
                  final totalItem = unitPrice * quantity;
                  final reason = item['reason'] ?? item['motivo'] ?? '';
                  final importance = item['importance'] ?? item['importancia'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? const Color(0xFF00C977) 
                            : (widget.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: const Color(0xFF00C977).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _toggleItem(index),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleItem(index),
                                activeColor: const Color(0xFF00C977),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      description,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: widget.isDarkMode ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    if (reason.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 14,
                                            color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Motivo: $reason',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (importance.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: importance.toLowerCase() == 'alta' || importance.toLowerCase() == 'high'
                                              ? Colors.red.withOpacity(0.1)
                                              : importance.toLowerCase() == 'média' || importance.toLowerCase() == 'medium'
                                                  ? Colors.orange.withOpacity(0.1)
                                                  : Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Importância: $importance',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: importance.toLowerCase() == 'alta' || importance.toLowerCase() == 'high'
                                                ? Colors.red[700]
                                                : importance.toLowerCase() == 'média' || importance.toLowerCase() == 'medium'
                                                    ? Colors.orange[700]
                                                    : Colors.green[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      'Quantidade: $quantity × ${PriceUtils.formatCurrency(unitPrice)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                PriceUtils.formatCurrency(totalItem) ?? 'R\$ 0,00',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                // Valor do diagnóstico
                Builder(
                  builder: (context) {
                    final diagnosticValue = _parseDiagnosticValue(widget.diagnosticValue);
                    if (diagnosticValue == null || diagnosticValue <= 0) {
                      return const SizedBox.shrink();
                    }
                    final diagnosticInReais = diagnosticValue > 1000 ? diagnosticValue / 100.0 : diagnosticValue;
                    return Column(
                      children: [
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                              color: widget.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                              width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      Row(
                                        children: [
                                        Icon(Icons.search, size: 16, color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                                        const SizedBox(width: 6),
                                    Text(
                                          'Diagnóstico',
                                      style: TextStyle(
                                            fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                                    const SizedBox(height: 4),
                            Text(
                                      'Análise inicial do veículo para identificar problemas',
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                              ),
                              const SizedBox(width: 12),
                        Text(
                                PriceUtils.formatCurrency(diagnosticInReais) ?? 'R\$ 0,00',
                          style: TextStyle(
                                  fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: widget.isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                // Total selecionado
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00C977).withOpacity(0.1),
                        const Color(0xFF00B369).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00C977).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Selecionado:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: widget.isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        PriceUtils.formatCurrency(selectedTotal) ?? 'R\$ 0,00',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00C977),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Botões de ação
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: widget.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: hasSelection ? () {
                      Navigator.of(context).pop();
                      final selected = _getSelectedItems();
                      widget.onApprove(allSelected ? null : selected);
                    } : null,
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: Text(
                      allSelected ? 'Confirmar Orçamento Completo' : 'Confirmar Itens Selecionados',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C977),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onReject();
                    },
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text(
                      'Rejeitar Orçamento',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

