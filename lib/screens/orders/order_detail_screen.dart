import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../widgets/meca_toast.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../utils/formatters.dart';
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
  bool _shownInProgressPopup = false;

  // Interactive quote selection state
  final Map<int, bool> _quoteSelectedItems = {};
  final Map<int, String?> _quoteSelectedOptions = {};
  bool _quoteSelectionInitialized = false;

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
            if (item['comment'] != null) 'comment': item['comment'].toString(),
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
                if (img['comment'] != null) 'comment': img['comment'].toString(),
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

  /// Cliente só pode ver telefone da oficina quando serviço estiver em andamento ou adiante.
  /// Evita que o cliente pegue o contato e faça o serviço por fora da plataforma.
  bool _canShowWorkshopPhone(String? status) {
    if (status == null || status.isEmpty) return false;
    final s = status.toLowerCase().trim();
    const allowed = [
      'em_andamento', 'in_progress',
      'aguardando_aprovacao_finalizacao',
      'aguardando_aprovacao_orcamento',
      'aguardando_pagamento',
      'finalizado', 'finalizado_aguardando_pagamento', 'completed',
      'pago', 'paid',
    ];
    return allowed.contains(s);
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          fileName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        if (upload['comment'] != null && upload['comment'].toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            upload['comment'].toString(),
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
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
        // Popup quando serviço está em andamento (oficina iniciou; cliente só recebe notificação)
        final status = (details['status'] ?? widget.booking['status'] ?? '').toString().toLowerCase().trim();
        if ((status == 'em_andamento' || status == 'in_progress') && !_shownInProgressPopup && mounted) {
          _shownInProgressPopup = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            MecaToast.showSuccess(context, 'Início do serviço aprovado! Agora é só aguardar atualizações da oficina.');
          });
        }
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
        if (!mounted) return;
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

  /// Garante valor booleano para accepts_installment (API/DB podem retornar true/false, 1/0, "true"/"false").
  static bool _parseAcceptsInstallment(dynamic value, {bool defaultValue = true}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true' || v == '1' || v == 'yes') return true;
      if (v == 'false' || v == '0' || v == 'no') return false;
    }
    return defaultValue;
  }

  static int _parseMaxInstallments(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value.clamp(1, 24);
    final n = int.tryParse(value.toString());
    return n != null ? n.clamp(1, 24) : defaultValue;
  }

  Future<void> _redirectToPayment({Map<String, dynamic>? bookingData}) async {
    // Garantir dados atualizados (incl. workshop_accepts_installment / workshop_max_installments) antes de abrir pagamento
    final bookingId = widget.booking['id']?.toString();
    if (bookingId != null && bookingId.isNotEmpty) {
      _apiService.invalidateBookingCache(bookingId);
      await _loadBookingDetails(forceRefresh: true);
      if (!mounted) return;
    }
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
    workshopData['accepts_installment'] = _parseAcceptsInstallment(
      workshopData['accepts_installment'] ?? mergedBooking['workshop_accepts_installment'],
      defaultValue: true,
    );
    workshopData['max_installments'] = _parseMaxInstallments(
      workshopData['max_installments'] ?? mergedBooking['workshop_max_installments'],
      12,
    );

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
    updatedBooking['workshop_id'] = updatedBooking['workshop_id'] ?? updatedBooking['oficina_id'];

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
            // Motivo de cancelamento/recusa
            Builder(
              builder: (context) {
                final merged = _mergeBookingData();
                final cancelReason = (merged['cancel_reason'] ?? '').toString().trim();
                final cancelledBy = (merged['cancelled_by'] ?? '').toString().trim();
                if (normalizedStatus != 'cancelled' || cancelReason.isEmpty) return const SizedBox.shrink();
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3D1F1F).withOpacity(0.55) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFFFF6B6B).withOpacity(0.4) : const Color(0xFFE8867C).withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: isDark ? const Color(0xFFFF6B6B) : const Color(0xFFE8867C), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cancelledBy == 'workshop' ? 'Motivo da recusa:' : 'Motivo do cancelamento:',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFFF6B6B) : const Color(0xFFE8867C),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cancelReason,
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  fontSize: 14,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
                        Builder(
                          builder: (context) {
                            final rawLogo = (_bookingDetails?['workshop_logo_url'] ?? widget.booking['workshop_logo_url'] ?? '').toString().trim();
                            final logoUrl = rawLogo.isNotEmpty && rawLogo.startsWith('http') ? rawLogo : null;
                            if (logoUrl == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      logoUrl,
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
                            );
                          },
                        ),
                      _buildInfoRow(
                        Icons.build_circle,
                        (_bookingDetails?['workshop_name'] ?? widget.booking['workshop_name'] ?? 'Oficina').toString(),
                      ),
                  _buildWorkshopMapCard(isDarkMode),
                      Builder(
                        builder: (context) {
                          final workshop = _bookingDetails?['workshop'] ?? widget.booking['workshop'];
                          final lat = workshop?['latitude'] ?? _bookingDetails?['latitude'] ?? _bookingDetails?['workshop_latitude'] ?? widget.booking['latitude'] ?? widget.booking['workshop_latitude'];
                          final lng = workshop?['longitude'] ?? _bookingDetails?['longitude'] ?? _bookingDetails?['workshop_longitude'] ?? widget.booking['longitude'] ?? widget.booking['workshop_longitude'];
                          return _buildLocationRow(
                            Icons.location_on,
                            _formatWorkshopAddress(_bookingDetails?['workshop_address'] ?? widget.booking['workshop_address']),
                            lat,
                            lng,
                          );
                        },
                      ),
                      if (_bookingDetails?['workshop_city'] != null || _bookingDetails?['workshop_state'] != null)
                        _buildInfoRow(
                          Icons.location_city,
                          '${_bookingDetails?['workshop_city'] ?? ''}, ${_bookingDetails?['workshop_state'] ?? ''}'
                              .replaceAll(RegExp(r'^,\s*|,\s*$'), ''),
                        ),
                      Builder(
                        builder: (context) {
                          final merged = _mergeBookingData();
                          final status = merged['status']?.toString() ?? '';
                          final canShow = _canShowWorkshopPhone(status);
                          final phone = (_bookingDetails?['workshop_phone'] ?? widget.booking['workshop_phone'] ?? '').toString().trim();
                          if (canShow && phone.isNotEmpty)
                            return _buildInfoRow(Icons.phone, Formatters.formatPhone(phone));
                          return _buildInfoRow(
                            Icons.phone,
                            'Telefone disponível quando o serviço estiver em andamento',
                          );
                        },
                      ),
                      Builder(
                        builder: (context) {
                          final merged = _mergeBookingData();
                          final status = merged['status']?.toString() ?? '';
                          final canShow = _canShowWorkshopPhone(status);
                          final email = (_bookingDetails?['workshop_email'] ?? '').toString().trim();
                          if (canShow && email.isNotEmpty)
                            return _buildInfoRow(Icons.email, email);
                          return const SizedBox.shrink();
                        },
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

                      final clientImages = <Map<String, dynamic>>[];
                      final workshopImages = <Map<String, dynamic>>[];
                      for (final img in allImages) {
                        final url = img['url']?.toString();
                        if (url == null || url.isEmpty) continue;
                        final uploadedBy = img['uploaded_by']?.toString() ?? '';
                        final s3Key = img['s3_key']?.toString() ?? img['key']?.toString() ?? '';
                        final isWs = uploadedBy == 'workshop' ||
                            s3Key.contains('/workshop/') ||
                            s3Key.contains('workshop');
                        if (isWs) {
                          workshopImages.add(img);
                        } else {
                          clientImages.add(img);
                        }
                      }

                      Widget buildThumbGrid(List<Map<String, dynamic>> images) {
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: images.map((img) {
                            final url = img['url']!.toString();
                            return GestureDetector(
                              onTap: () => _openUploadPreview(img),
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    width: 80,
                                    height: 80,
                                    memCacheWidth: 160,
                                    memCacheHeight: 160,
                                    httpHeaders: const {'Accept': 'image/*'},
                                    placeholder: (context, url) => Container(
                                      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
                                      alignment: Alignment.center,
                                      child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
                                      alignment: Alignment.center,
                                      child: Icon(Icons.broken_image, size: 20, color: Colors.grey.shade500),
                                    ),
                                    fadeInDuration: const Duration(milliseconds: 200),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      }

                      Widget buildEvidenceCard(Map<String, dynamic> img) {
                        final url = img['url']!.toString();
                        final comment = img['comment']?.toString();
                        final hasComment = comment != null && comment.isNotEmpty;
                        return GestureDetector(
                          onTap: () => _openUploadPreview(img),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDarkMode ? 0.35 : 0.10),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.vertical(
                                    top: const Radius.circular(16),
                                    bottom: hasComment ? Radius.zero : const Radius.circular(16),
                                  ),
                                  child: Stack(
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: url,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 200,
                                        memCacheWidth: 600,
                                        memCacheHeight: 400,
                                        httpHeaders: const {'Accept': 'image/*'},
                                        placeholder: (context, url) => Container(
                                          height: 200,
                                          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
                                          alignment: Alignment.center,
                                          child: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          height: 200,
                                          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
                                          alignment: Alignment.center,
                                          child: Icon(Icons.broken_image, color: Colors.grey.shade500),
                                        ),
                                        fadeInDuration: const Duration(milliseconds: 200),
                                      ),
                                      Positioned(
                                        top: 8, right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00C977),
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF00C977).withOpacity(0.4),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.build_rounded, size: 10, color: Colors.white),
                                              SizedBox(width: 3),
                                              Text('Oficina', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (hasComment)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00C977).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF00C977)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Justificativa da oficina',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                comment!,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
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

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Icon(Icons.photo_library_outlined, size: 18, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                              const SizedBox(width: 8),
                              Text(
                                'Imagens do Agendamento',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : const Color(0xFF252940),
                                ),
                              ),
                            ],
                          ),
                          if (clientImages.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            buildThumbGrid(clientImages),
                          ],
                          if (workshopImages.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            ...workshopImages.map((img) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: buildEvidenceCard(img),
                            )),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Builder(
        builder: (context) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          final actionWidget = _buildActionButtons(status);
          final hasActions = actionWidget is! SizedBox;

          if (!hasActions && !canCancel) return const SizedBox.shrink();

          return Container(
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF0A0A0A) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDarkMode ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasActions) actionWidget,
                    if (canCancel && !hasActions)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _cancelBooking,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: const Text('Cancelar Agendamento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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
      title = isFinalQuote ? 'Orçamento Final' : 'Orçamento Detalhado';
      subtitle = isFinalQuote
          ? 'Valor final após conclusão do serviço. Realize o pagamento.'
          : 'Finalize o pagamento para concluir o serviço.';
    } else if (hasCompletedAt) {
      title = 'Orçamento final da oficina';
      subtitle = 'Valor definido após o término do serviço.';
    } else {
      title = 'Orçamento Detalhado';
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

    final currentQuoteStatus = (merged['quote_status'] ?? widget.booking['quote_status'])?.toString().toLowerCase() ?? '';
    final isQuotePending =
        currentQuoteStatus == 'pending' &&
        (normalizedStatus == 'awaiting_quote_approval' ||
         normalizedStatus == 'pending' ||
         normalizedStatus == 'pendente_cliente');

    if (isQuotePending && isEditedQuote && title == 'Orçamento Detalhado') {
      title = 'Revise o orçamento atualizado';
      subtitle = 'A oficina alterou o orçamento durante o serviço. Revise e aprove ou rejeite.';
    }

    // ── INTERACTIVE QUOTE VIEW (when pending + has detailed items) ──
    if (isQuotePending && hasDetailedQuote) {
      _initQuoteSelection(quoteItems!);
      final selectedTotal = _calculateQuoteSelectedTotal(quoteItems, diagnosticValue);

      return Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF00C977), Color(0xFF00B369)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Revisar Orçamento', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Selecione os itens e opções desejados', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Items
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
              border: Border.all(color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!),
            ),
            child: Column(
              children: [
                ...quoteItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = _quoteSelectedItems[index] ?? false;
                  final isRequired = _isItemRequired(item);
                  final priority = _parsePriority(item['priority']);
                  final pInfo = _priorityConfig[priority] ?? _priorityConfig[3]!;
                  final description = item['description'] ?? 'Item sem descrição';
                  final q = item['quantity'] is int ? item['quantity'] : (int.tryParse(item['quantity']?.toString() ?? '1') ?? 1);
                  final itemPrice = _getQuoteItemPrice(item, index);
                  final totalItem = itemPrice * q;
                  final options = item['options'] as List? ?? [];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF00C977) : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isRequired)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4, right: 4, top: 4),
                                  child: Icon(Icons.lock, color: Color(0xFFFF3B30), size: 20),
                                )
                              else
                                SizedBox(
                                  width: 32, height: 32,
                                  child: Checkbox(
                                    value: isSelected,
                                    onChanged: (_) async {
                                      if (isSelected && priority == 4) {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Remover item?'),
                                            content: const Text('Este item é muito importante para o funcionamento do veículo. Tem certeza que deseja removê-lo?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Manter')),
                                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover', style: TextStyle(color: Colors.red))),
                                            ],
                                          ),
                                        );
                                        if (confirm != true) return;
                                      }
                                      setState(() => _quoteSelectedItems[index] = !isSelected);
                                    },
                                    activeColor: const Color(0xFF00C977),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(description, style: TextStyle(
                                            fontSize: 15, fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? (isDarkMode ? Colors.white : Colors.black87)
                                                : Colors.grey,
                                            decoration: isSelected ? null : TextDecoration.lineThrough,
                                          )),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: pInfo.color.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(pInfo.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pInfo.color)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Qtd: $q × ${PriceUtils.formatCurrency(itemPrice)}',
                                      style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                PriceUtils.formatCurrency(totalItem) ?? 'R\$ 0,00',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87),
                              ),
                            ],
                          ),
                          // Options radio buttons (original item + alternatives)
                          if (options.isNotEmpty && isSelected) ...[
                            const Divider(height: 16),
                            Text('Escolha uma opção:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                            const SizedBox(height: 6),
                            // Original item as first radio option
                            Builder(builder: (_) {
                              final origPriceRaw = item['unit_price'] ?? 0;
                              final origPrice = (origPriceRaw is num ? origPriceRaw.toDouble() : (origPriceRaw is String ? double.tryParse(origPriceRaw) ?? 0 : 0)) / 100.0;
                              final isOrigSelected = _quoteSelectedOptions[index] == 'original';
                              return InkWell(
                                onTap: () => setState(() => _quoteSelectedOptions[index] = 'original'),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isOrigSelected ? const Color(0xFF00C977).withValues(alpha: 0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isOrigSelected ? const Color(0xFF00C977) : Colors.grey.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Radio<String>(
                                        value: 'original',
                                        groupValue: _quoteSelectedOptions[index],
                                        activeColor: const Color(0xFF00C977),
                                        onChanged: (v) => setState(() => _quoteSelectedOptions[index] = v),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text('$description (original)', style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white : Colors.black87))),
                                      Text(PriceUtils.formatCurrency(origPrice) ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            // Alternative options
                            ...options.map<Widget>((opt) {
                              final optId = opt['id']?.toString() ?? '';
                              final optDesc = opt['description']?.toString() ?? '';
                              final optPriceRaw = opt['unit_price'] ?? 0;
                              final optPrice = (optPriceRaw is num ? optPriceRaw.toDouble() : (optPriceRaw is String ? double.tryParse(optPriceRaw) ?? 0 : 0)) / 100.0;
                              final isOptSelected = _quoteSelectedOptions[index] == optId;
                              return InkWell(
                                onTap: () => setState(() => _quoteSelectedOptions[index] = optId),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isOptSelected ? const Color(0xFF00C977).withValues(alpha: 0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isOptSelected ? const Color(0xFF00C977) : Colors.grey.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Radio<String>(
                                        value: optId,
                                        groupValue: _quoteSelectedOptions[index],
                                        activeColor: const Color(0xFF00C977),
                                        onChanged: (v) => setState(() => _quoteSelectedOptions[index] = v),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(optDesc, style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white : Colors.black87))),
                                      Text(PriceUtils.formatCurrency(optPrice) ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  );
                }),

                // Diagnostic
                if (diagnosticValue != null && diagnosticValue > 0)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Icon(Icons.search, size: 16, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text('Diagnóstico', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                        ]),
                        Text(PriceUtils.formatCurrency(_diagnosticValueInReais(diagnosticValue)) ?? 'R\$ 0,00', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),
                // Total bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [const Color(0xFF00C977).withValues(alpha: 0.1), const Color(0xFF00B369).withValues(alpha: 0.1)]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00C977).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Selecionado:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                      Text(PriceUtils.formatCurrency(selectedTotal) ?? 'R\$ 0,00', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00C977))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Approve/Reject buttons inline
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _quoteSelectedItems.values.any((v) => v) ? () {
                      final responseItems = _buildQuoteResponseItems(quoteItems);
                      _approveQuoteWithItems(responseItems);
                    } : null,
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: Text(
                      _quoteSelectedItems.values.every((v) => v)
                          ? 'Aprovar Orçamento Completo'
                          : 'Enviar Resposta — ${PriceUtils.formatCurrency(selectedTotal)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C977),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectQuote(),
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text('Rejeitar Orçamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // ── STATIC QUOTE VIEW (non-pending states — read-only) ──
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
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),

          // Mostrar breakdown detalhado se houver items
          if (hasDetailedQuote) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
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
                      margin: EdgeInsets.only(bottom: index < quoteItems.length - 1 ? 12 : 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
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
                                Text(
                                  'Qtd: $quantity × ${PriceUtils.formatCurrency(unitPrice)}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            PriceUtils.formatCurrency(totalItem) ?? 'R\$ 0,00',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('Diagnóstico', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
                          Text(
                            PriceUtils.formatCurrency(_diagnosticValueInReais(diagnosticValue)) ?? 'R\$ 0,00',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Divider(color: Colors.white38, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(_formatPriceLabel() ?? '—', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
    // Buscar latitude/longitude de múltiplas fontes: workshop object, bookingDetails (inclui workshop_latitude/longitude da API), ou booking direto
    final workshop = _bookingDetails?['workshop'] ?? widget.booking['workshop'];
    final lat = _parseCoordinate(
      workshop?['latitude'] ??
      _bookingDetails?['latitude'] ??
      _bookingDetails?['workshop_latitude'] ??
      widget.booking['latitude'] ??
      widget.booking['workshop_latitude']
    );
    final lng = _parseCoordinate(
      workshop?['longitude'] ??
      _bookingDetails?['longitude'] ??
      _bookingDetails?['workshop_longitude'] ??
      widget.booking['longitude'] ??
      widget.booking['workshop_longitude']
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

  Widget _buildRejectInfoRow(IconData icon, String label, String value, Color accentColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: accentColor,
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
        return 'Aguardando Sua Resposta';
      case 'pending':
      case 'pendente':
      case 'pendente_oficina':
        return 'Aguardando Oficina';
      case 'confirmed':
      case 'confirmado':
        return 'Confirmado';
      case 'in_progress':
      case 'em_andamento':
        return 'Em Andamento';
      case 'awaiting_quote_approval':
      case 'aguardando_aprovacao_orcamento':
        return 'Orçamento - Aguardando Aprovação';
      case 'awaiting_service_start':
      case 'aguardando_autorizacao_inicio':
        return 'Aguardando Autorização de Início';
      case 'vehicle_at_workshop':
      case 'veiculo_na_oficina':
        return 'Veículo na Oficina';
      case 'awaiting_finalization_approval':
      case 'aguardando_aprovacao_finalizacao':
        return 'Aguardando Aprovação de Finalização';
      case 'in_dispute':
      case 'em_disputa':
        return 'Em Disputa';
      case 'completed':
      case 'concluido':
      case 'concluído':
        return 'Concluído';
      case 'paid':
      case 'pago':
        return 'Pago';
      case 'awaiting_payment':
      case 'aguardando_pagamento':
      case 'finalizado_aguardando_pagamento':
        return 'Aguardando Pagamento';
      case 'cancelled':
      case 'cancelado':
        return 'Cancelado';
      case 'rejected':
      case 'rejeitado':
        return 'Rejeitado';
      default:
        // Se não reconhecer, formatar o status original de forma legível
        final formatted = status
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase())
            .join(' ');
        return formatted.isEmpty ? 'Aguardando Confirmação' : formatted;
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

  /// Card de status: apenas uma frase curta e didática (sem título/subtítulo). Chefe: "quanto menos texto mais simples".
  Widget _buildStatusInfoCard(String status, String normalizedStatus) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final merged = _mergeBookingData();
    final finalStatus = merged['status'] ?? status;
    final finalNormalizedStatus = _normalizeStatusKey(finalStatus);
    final rawStatus = finalStatus.toLowerCase();

    String phrase = '';
    IconData icon = Icons.info_outline;
    Color accent = const Color(0xFF00C977);

    if (rawStatus == 'pendente_oficina' || finalNormalizedStatus == 'pending') {
      phrase = 'Sua solicitação foi recebida. Aguarde a oficina analisar e confirmar seu agendamento.';
      icon = Icons.hourglass_top_rounded;
      accent = Colors.amber.shade600;
    } else if (rawStatus == 'confirmado' || finalNormalizedStatus == 'confirmed') {
      phrase = 'Agendamento confirmado! Compareça na data e horário marcados. A oficina avaliará seu veículo e enviará o orçamento.';
      icon = Icons.event_available_rounded;
      accent = const Color(0xFF4A90D9);
    } else if (rawStatus == 'aguardando_autorizacao_inicio' || finalNormalizedStatus == 'awaiting_service_start') {
      phrase = 'A oficina está pronta para iniciar. Confirme abaixo para autorizar o início do serviço.';
      icon = Icons.play_circle_outline_rounded;
      accent = const Color(0xFF00C977);
    } else if (rawStatus == 'aguardando_aprovacao_orcamento' || finalNormalizedStatus == 'awaiting_quote_approval') {
      final hasCompletedAt = _bookingDetails?['completed_at'] != null || widget.booking['completed_at'] != null;
      phrase = hasCompletedAt
          ? 'O serviço foi concluído e o orçamento final está pronto. Revise os valores abaixo e aprove para liberar o pagamento.'
          : 'A oficina enviou o orçamento detalhado. Revise os itens e valores abaixo e aprove ou rejeite para prosseguir.';
      icon = Icons.receipt_long_rounded;
      accent = Colors.orange.shade600;
    } else if (rawStatus == 'veiculo_na_oficina' || finalNormalizedStatus == 'vehicle_at_workshop') {
      phrase = 'Seu veículo já está na oficina e será avaliado em breve. Você receberá uma notificação quando houver atualizações.';
      icon = Icons.garage_rounded;
      accent = const Color(0xFF4A90D9);
    } else if (rawStatus == 'aguardando_aprovacao_finalizacao' || finalNormalizedStatus == 'awaiting_finalization_approval') {
      phrase = 'O serviço foi concluído e o orçamento final está pronto. Revise os valores e aprove para liberar o pagamento.';
      icon = Icons.task_alt_rounded;
      accent = Colors.orange.shade600;
    } else if (rawStatus == 'em_disputa' || finalNormalizedStatus == 'in_dispute') {
      phrase = 'Existe uma pendência neste agendamento. Entre em contato com a oficina para resolver.';
      icon = Icons.warning_amber_rounded;
      accent = Colors.red.shade400;
    } else if (rawStatus == 'pendente_cliente' || finalNormalizedStatus == 'pending_customer') {
      final suggestedBy = merged['suggested_by'] ?? merged['sugerido_por'];
      final hasSuggestedDate = merged['suggested_date'] != null || merged['data_sugerida'] != null;
      final isTimeSuggestion = (suggestedBy == 'oficina' || suggestedBy == 'workshop') && hasSuggestedDate;
      final serviceStartPending = merged['service_start_pending'] == true || merged['service_start_pending'] == 'true';
      final hasQuote = _hasFinalPrice() ||
          (merged['estimated_price'] != null && (merged['estimated_price'] is num ? merged['estimated_price'] > 0 : false)) ||
          (merged['quote_items'] != null && merged['quote_items'] is List && (merged['quote_items'] as List).isNotEmpty);
      if (serviceStartPending && !hasQuote) {
        phrase = 'A oficina deu início ao atendimento. Acompanhe aqui as atualizações do serviço.';
        icon = Icons.construction_rounded;
        accent = const Color(0xFF00C977);
      } else if (isTimeSuggestion) {
        phrase = 'A oficina sugeriu um novo horário para o seu agendamento. Aceite a sugestão ou proponha outro horário.';
        icon = Icons.schedule_rounded;
        accent = Colors.amber.shade600;
      } else {
        final hasCompletedAt = _bookingDetails?['completed_at'] != null || widget.booking['completed_at'] != null;
        phrase = hasCompletedAt
            ? 'O serviço foi concluído e o orçamento final está pronto. Revise os valores abaixo e aprove para liberar o pagamento.'
            : 'A oficina enviou o orçamento detalhado. Revise os itens e valores abaixo e aprove ou rejeite para prosseguir.';
        icon = Icons.receipt_long_rounded;
        accent = Colors.orange.shade600;
      }
    } else if (finalNormalizedStatus == 'in_progress') {
      phrase = 'Seu veículo está sendo atendido pela oficina. Você será notificado assim que o serviço for concluído.';
      icon = Icons.build_rounded;
      accent = const Color(0xFF00C977);
    } else if (finalNormalizedStatus == 'awaiting_payment') {
      phrase = 'O serviço foi finalizado e o orçamento aprovado. Realize o pagamento para concluir.';
      icon = Icons.payments_rounded;
      accent = const Color(0xFF4A90D9);
    } else if (finalNormalizedStatus == 'completed' || finalNormalizedStatus == 'paid' || rawStatus == 'pago') {
      phrase = 'Seu pagamento foi confirmado! Agora você pode buscar seu veículo na oficina ou agendar um guincho para a retirada.';
      icon = Icons.check_circle_rounded;
      accent = const Color(0xFF00C977);
    }

    if (phrase.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? accent.withValues(alpha: 0.1) : accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: isDarkMode ? 0.3 : 0.25),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              phrase,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                height: 1.4,
              ),
            ),
          ),
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
    
    final hasQuote = (merged['final_price'] != null && merged['final_price'] > 0) ||
                     (_bookingDetails?['final_price'] != null && _bookingDetails!['final_price'] > 0);
    
    // Se não há nenhuma ação para o cliente (sugestão de horário, aprovar orçamento, avaliar), não exibir o bloco de ações
    final rawStatusForActions = (merged['status'] ?? status).toString().toLowerCase().trim();
    final hasTimeSuggestionCard = isTimeSuggestion && rawStatusForActions != 'confirmado' && rawStatusForActions != 'confirmed';
    final hasQuoteApproval = (rawStatusForActions == 'aguardando_aprovacao_orcamento' || _normalizeStatusKey(merged['status'] ?? status) == 'awaiting_quote_approval' ||
        (rawStatusForActions == 'pendente_cliente' && !isTimeSuggestion && hasQuote)) ||
        (rawStatusForActions == 'aguardando_aprovacao_finalizacao' || _normalizeStatusKey(merged['status'] ?? status) == 'awaiting_finalization_approval');
    final hasReview = merged['has_review'] == true || merged['has_review'] == 'true';
    final statusAllowsRate = _normalizeStatusKey(merged['status'] ?? status) == 'completed' || _normalizeStatusKey(merged['status'] ?? status) == 'paid';
    final hasRateButton = statusAllowsRate && !hasReview;
    final hasPaymentButton = rawStatusForActions == 'aguardando_pagamento' || _normalizeStatusKey(merged['status'] ?? status) == 'awaiting_payment';
    final hasServiceStartConfirm = rawStatusForActions == 'aguardando_autorizacao_inicio' || _normalizeStatusKey(merged['status'] ?? status) == 'awaiting_service_start';
    
    // CORREÇÃO: Coletar todos os widgets de ação primeiro e só renderizar o Container se houver pelo menos 1
    final actionWidgets = <Widget>[];
    
    // 0. Botão Confirmar início do serviço (PDF: após confirmar, mostrar popup)
    if (hasServiceStartConfirm) {
      actionWidgets.add(_buildConfirmServiceStartButton());
      actionWidgets.add(const SizedBox(height: 20));
    }
    
    // 1. Botão para abrir sugestão de horário como bottom sheet (evita overflow no bottom nav)
    if (hasTimeSuggestionCard) {
      final currentStatus = (merged['status'] ?? '').toString().toLowerCase().trim();
      if (currentStatus != 'confirmado' && currentStatus != 'confirmed') {
        actionWidgets.add(_buildTimeSuggestionButton(merged));
        actionWidgets.add(const SizedBox(height: 8));
      }
    }
    
    // 2. Botões de aprovação de orçamento (skip if interactive view has inline buttons)
    if (hasQuoteApproval && hasQuote) {
      final quoteItemsRaw = merged['quote_items'] ?? widget.booking['quote_items'];
      final hasInteractiveInline = (quoteItemsRaw is List && quoteItemsRaw.isNotEmpty) &&
          (rawStatusForActions == 'aguardando_aprovacao_orcamento' ||
           _normalizeStatusKey(merged['status'] ?? status) == 'awaiting_quote_approval' ||
           (merged['quote_status'] ?? widget.booking['quote_status']) == 'sent' ||
           (merged['quote_status'] ?? widget.booking['quote_status']) == 'pending');
      if (!hasInteractiveInline) {
        actionWidgets.add(_buildQuoteApprovalButtons());
        actionWidgets.add(const SizedBox(height: 20));
      }
    }
    
    // 4. Botão de pagar (status aguardando pagamento)
    if (hasPaymentButton) {
      actionWidgets.add(_buildPaymentButton());
      actionWidgets.add(const SizedBox(height: 20));
    }
    
    // 5. Botão de avaliar
    if (hasRateButton) {
      actionWidgets.add(_buildRateButton());
    }

    // 6. Botão Ver Nota Fiscal (status paid/completed)
    if (statusAllowsRate) {
      actionWidgets.add(const SizedBox(height: 12));
      actionWidgets.add(_buildInvoiceButton());
    }

    // Só renderizar o Container se houver pelo menos 1 widget de ação
    if (actionWidgets.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: actionWidgets,
      ),
    );
  }
  
  Widget _buildConfirmServiceStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _confirmServiceStart,
        icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
        label: const Text('Confirmar início do serviço', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C977),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _confirmServiceStart() async {
    final bookingId = widget.booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) {
      if (!mounted) return;
      AppAlerts.showError(context, message: 'Identificador do agendamento não encontrado.');
      return;
    }
    final result = await _apiService.confirmServiceStart(bookingId);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _bookingDetails = _bookingDetails ?? {};
        _bookingDetails!['status'] = 'em_andamento';
        widget.booking['status'] = 'em_andamento';
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Início aprovado'),
          content: const Text(
            'Início do serviço aprovado! Agora é só aguardar atualizações da oficina.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      _loadBookingDetails();
    } else {
      AppAlerts.showError(context, message: result['error'] ?? 'Não foi possível confirmar o início.');
    }
  }

  // Helper methods para construir cada ação individualmente
  Widget _buildQuoteApprovalButtons() {
    final merged = _mergeBookingData();
    final status = merged['status']?.toString() ?? widget.booking['status']?.toString() ?? 'pending';
    final rawStatus = status.toLowerCase().trim();
    final normalizedStatus = _normalizeStatusKey(status);
    final isAwaitingFinalizationApproval = rawStatus == 'aguardando_aprovacao_finalizacao' ||
        normalizedStatus == 'awaiting_finalization_approval';
    final quoteStatus = merged['quote_status'] ?? widget.booking['quote_status'];
    final isFinalQuote = quoteStatus == 'final';
    
    return Row(
      children: [
        if (isAwaitingFinalizationApproval || !isFinalQuote)
          Expanded(
            flex: 2,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.06),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.red.withValues(alpha: 0.3)
                      : Colors.red.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => isAwaitingFinalizationApproval ? _rejectFinalization() : _rejectQuote(),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.close_rounded, color: Colors.red[400], size: 18),
                      const SizedBox(width: 5),
                      Text(
                        'Rejeitar',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.red[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (isAwaitingFinalizationApproval || !isFinalQuote)
          const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFF00C977), Color(0xFF00B369)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00C977).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isAwaitingFinalizationApproval ? _approveFinalization : _openInteractiveQuoteOrApprove,
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 5),
                    const Text(
                      'Aprovar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildRateButton() {
    return SizedBox(
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
    );
  }

  Widget _buildInvoiceButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _viewInvoice,
        icon: const Icon(Icons.receipt_long, color: Color(0xFF00C977)),
        label: const Text('Ver Nota Fiscal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF00C977))),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF00C977), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _viewInvoice() async {
    final bookingId = widget.booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;
    final result = await _apiService.getInvoice(bookingId);
    if (!mounted) return;
    if (result['success'] == true && result['data'] != null) {
      final data = result['data'] as Map<String, dynamic>;
      final available = data['available'] == true;
      final url = data['url']?.toString();
      final status = data['status']?.toString() ?? '';
      if (available && url != null && url.isNotEmpty) {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else if (status == 'ERROR' || status == 'CANCELED') {
        MecaToast.showWarning(context, 'Erro na emissão da NF. Entre em contato com a oficina.');
      } else {
        MecaToast.showWarning(context, 'Nota Fiscal ainda não disponível.');
      }
    } else {
      MecaToast.showWarning(context, 'NF não disponível — emissão manual pela oficina.');
    }
  }

  Widget _buildPaymentButton() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF00C977).withOpacity(0.15)
            : const Color(0xFF00C977).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00C977),
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
                  color: const Color(0xFF00C977).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.payments,
                  color: Color(0xFF00C977),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pagamento pendente',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.green[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Realize o pagamento para concluir o serviço.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[300] : Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _redirectToPayment(bookingData: _mergeBookingData()),
              icon: const Icon(Icons.payment, color: Colors.white, size: 22),
              label: const Text(
                'Pagar agora',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C977),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  
  void _openInteractiveQuoteOrApprove() {
    final merged = _mergeBookingData();
    final quoteItemsRaw = merged['quote_items'] ?? widget.booking['quote_items'];
    final quoteItems = quoteItemsRaw is List ? quoteItemsRaw : null;
    final diagnosticValue = merged['diagnostic_value'] ?? widget.booking['diagnostic_value'];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (quoteItems != null && quoteItems.isNotEmpty) {
      _showQuoteDetailModal(merged, quoteItems, diagnosticValue, isDarkMode);
    } else {
      _approveQuote();
    }
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
    if (selectedItems != null && selectedItems.isNotEmpty && selectedItems.first.containsKey('quote_item_id')) {
      final bookingId = widget.booking['id']?.toString() ?? '';
      if (bookingId.isEmpty) return;
      final result = await _apiService.respondQuote(bookingId, items: selectedItems);
      if (!mounted) return;
      if (result['success'] == true) {
        _apiService.invalidateBookingsCache();
        _apiService.invalidateBookingCache(bookingId);
        final newStatus = result['data']?['status']?.toString() ?? 'em_andamento';
        final newQuoteStatus = result['data']?['quote_status']?.toString() ?? 'approved';

        if (!mounted) return;
        setState(() {
          _quoteSelectionInitialized = false;
          _quoteSelectedItems.clear();
          _quoteSelectedOptions.clear();
          widget.booking['quote_status'] = newQuoteStatus;
          widget.booking['status'] = newStatus;
          if (_bookingDetails != null) {
            _bookingDetails!['quote_status'] = newQuoteStatus;
            _bookingDetails!['status'] = newStatus;
          }
        });

        MecaToast.showSuccess(context, 'Orçamento aprovado com sucesso!');
        _loadBookingDetails(forceRefresh: true);
      } else {
        AppAlerts.showError(context, message: result['error']?.toString() ?? 'Erro ao enviar resposta.');
      }
      return;
    }
    await _approveQuote();
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
        _apiService.invalidateBookingsCache();
        _apiService.invalidateBookingCache(bookingId);

        final hasCompletedAt = _bookingDetails?['completed_at'] != null || widget.booking['completed_at'] != null;
        final newStatus = result['data']?['status']?.toString().toLowerCase() ??
                         (hasCompletedAt ? 'aguardando_pagamento' : 'em_andamento');

        String message;
        if (isEditedQuote) {
          message = 'Orçamento atualizado aprovado! O serviço continua em andamento.';
        } else {
          message = hasCompletedAt
              ? 'Orçamento aprovado! Agora você pode realizar o pagamento.'
              : 'Orçamento aprovado! A oficina continuará o serviço e você será notificado quando finalizar.';
        }

        if (!mounted) return;
        setState(() {
          _quoteSelectionInitialized = false;
          _quoteSelectedItems.clear();
          _quoteSelectedOptions.clear();
          widget.booking['status'] = newStatus;
          widget.booking['quote_status'] = 'approved';
          if (_bookingDetails != null) {
            _bookingDetails!['status'] = newStatus;
            _bookingDetails!['quote_status'] = 'approved';
          }
        });

        MecaToast.showSuccess(context, message);
        _loadBookingDetails(forceRefresh: true);
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

  Widget _buildTimeSuggestionButton(Map<String, dynamic> merged) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showTimeSuggestionSheet(merged),
        icon: const Icon(Icons.schedule_rounded, size: 20, color: Colors.white),
        label: const Text(
          'Ver sugestão de horário da oficina',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF59E0B),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  void _showTimeSuggestionSheet(Map<String, dynamic> merged) {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollController) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
            return Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: _buildTimeSuggestionCard(merged, onAction: () => Navigator.of(sheetContext).pop()),
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

  Widget _buildTimeSuggestionCard(Map<String, dynamic> merged, {VoidCallback? onAction}) {
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
                // Motivo da sugestão
                Builder(
                  builder: (context) {
                    final merged = _mergeBookingData();
                    final reason = (merged['suggestion_reason'] ?? '').toString().trim();
                    if (reason.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.25)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFF59E0B), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Motivo da oficina:',
                                    style: TextStyle(
                                      color: const Color(0xFFF59E0B),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    reason,
                                    style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                                      fontSize: 14,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
                        onPressed: () { onAction?.call(); _rejectTimeSuggestion(); },
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
                        onPressed: () { onAction?.call(); _acceptTimeSuggestion(); },
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
        _apiService.invalidateBookingsCache();
        _apiService.invalidateBookingCache(bookingId);
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
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Rejeitar Orçamento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditedQuote
                      ? 'O orçamento anterior será restaurado automaticamente.'
                      : 'Você confirma a rejeição deste orçamento?',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      if (isEditedQuote && previousQuote != null)
                        _buildRejectInfoRow(
                          Icons.restore,
                          'Valor original',
                          PriceUtils.formatCurrency(previousQuote!['final_price']) ?? 'R\$ 0,00',
                          isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                          isDark,
                        ),
                      if (isEditedQuote && previousQuote != null && hasDiagnostic)
                        Divider(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, height: 20),
                      if (hasDiagnostic)
                        _buildRejectInfoRow(
                          Icons.receipt_long,
                          'Taxa de diagnóstico',
                          PriceUtils.formatCurrency(_diagnosticValueInReais(diagnosticValue)) ?? 'R\$ 0,00',
                          Colors.orange.shade400,
                          isDark,
                        ),
                      if (!hasDiagnostic && !isEditedQuote)
                        _buildRejectInfoRow(
                          Icons.cancel_outlined,
                          'Resultado',
                          'Agendamento cancelado',
                          isDark ? Colors.red.shade400 : Colors.red.shade700,
                          isDark,
                        ),
                    ],
                  ),
                ),
                if (hasDiagnostic) ...[
                  const SizedBox(height: 8),
                  Text(
                    'A oficina já analisou seu veículo, por isso a taxa de diagnóstico será cobrada.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Motivo (opcional)',
                    hintText: 'Informe o motivo...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Rejeitar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final result = await _apiService.rejectQuote(
        bookingId,
        reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      );
      
      if (!mounted) return;

      if (result['success'] == true) {
        _apiService.invalidateBookingsCache();
        _apiService.invalidateBookingCache(bookingId);
        await _loadBookingDetails();

        String successMessage;
        if (isEditedQuote) {
          successMessage = 'Orçamento adicional rejeitado. O orçamento original foi restaurado e o serviço continua normalmente.';
        } else if (hasDiagnostic) {
          successMessage = 'Orçamento rejeitado. Você precisará pagar apenas o valor do diagnóstico.';
        } else {
          successMessage = 'Orçamento rejeitado e agendamento cancelado. A oficina foi notificada.';
        }

        AppAlerts.showSuccess(context, message: successMessage);
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
        if (!mounted) return;
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
        if (!mounted) return;
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

  /// Valor do diagnóstico em reais. A API envia sempre em centavos (inteiro).
  double _diagnosticValueInReais(dynamic raw) {
    final v = _parseDiagnosticValue(raw);
    if (v == null || v <= 0) return 0.0;
    return v / 100.0;
  }

  // ── Interactive quote helpers ──

  static const _priorityConfig = <int, ({String label, Color color})>{
    5: (label: 'Essencial', color: Color(0xFFFF3B30)),
    4: (label: 'Muito importante', color: Color(0xFFFF9500)),
    3: (label: 'Importante', color: Color(0xFFFFCC00)),
    2: (label: 'Recomendado', color: Color(0xFF007AFF)),
    1: (label: 'Opcional', color: Color(0xFF8E8E93)),
  };

  int _parsePriority(dynamic raw) {
    if (raw is int) return raw.clamp(1, 5);
    if (raw is String) return int.tryParse(raw)?.clamp(1, 5) ?? 3;
    return 3;
  }

  bool _isItemRequired(dynamic item) {
    if (item['is_required'] == true) return true;
    return _parsePriority(item['priority']) == 5;
  }

  void _initQuoteSelection(List quoteItems) {
    if (_quoteSelectionInitialized) return;
    _quoteSelectionInitialized = true;
    for (var i = 0; i < quoteItems.length; i++) {
      final priority = _parsePriority(quoteItems[i]['priority']);
      _quoteSelectedItems[i] = priority > 1;
      final options = quoteItems[i]['options'] as List?;
      if (options != null && options.isNotEmpty) {
        final defaultOpt = options.firstWhere((o) => o['is_default'] == true, orElse: () => null);
        _quoteSelectedOptions[i] = defaultOpt != null ? defaultOpt['id']?.toString() : 'original';
      }
    }
  }

  double _getQuoteItemPrice(dynamic item, int index) {
    final options = item['options'] as List?;
    final selectedOptId = _quoteSelectedOptions[index];
    if (options != null && options.isNotEmpty && selectedOptId != null && selectedOptId != 'original') {
      final selectedOpt = options.firstWhere(
        (o) => o['id']?.toString() == selectedOptId,
        orElse: () => null,
      );
      if (selectedOpt != null) {
        final raw = selectedOpt['unit_price'] ?? 0;
        return (raw is num ? raw.toDouble() : (raw is String ? double.tryParse(raw) ?? 0 : 0)) / 100.0;
      }
    }
    final raw = item['unit_price'] ?? 0;
    return (raw is num ? raw.toDouble() : (raw is String ? double.tryParse(raw) ?? 0 : 0)) / 100.0;
  }

  double _calculateQuoteSelectedTotal(List quoteItems, dynamic diagnosticRaw) {
    double total = 0;
    for (var i = 0; i < quoteItems.length; i++) {
      if (_quoteSelectedItems[i] != true) continue;
      final item = quoteItems[i];
      final q = item['quantity'] is int ? item['quantity'] : (int.tryParse(item['quantity']?.toString() ?? '1') ?? 1);
      total += _getQuoteItemPrice(item, i) * q;
    }
    final dv = _parseDiagnosticValue(diagnosticRaw);
    if (dv != null && dv > 0) total += dv / 100.0;
    return total;
  }

  List<Map<String, dynamic>> _buildQuoteResponseItems(List quoteItems) {
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < quoteItems.length; i++) {
      final itemId = quoteItems[i]['id']?.toString();
      if (itemId == null) continue;
      final payload = <String, dynamic>{
        'quote_item_id': itemId,
        'selected': _quoteSelectedItems[i] ?? false,
      };
      final optId = _quoteSelectedOptions[i];
      if (optId != null && optId != 'original' && (_quoteSelectedItems[i] ?? false)) {
        payload['selected_option_id'] = optId;
      }
      items.add(payload);
    }
    return items;
  }

  double? _parseBackendPrice(dynamic raw) {
    if (raw == null) return null;

    if (raw is num) {
      final value = raw.toDouble();
      if (value == 0) return null;
      // API RDS usa centavos (int). 100=R$1, 125=R$1,25.
      if (value % 1 == 0) {
        final converted = value / 100;
        debugPrint('💰 [OrderDetail] _parseBackendPrice: $value centavos -> $converted reais');
        return converted;
      }
      debugPrint('💰 [OrderDetail] _parseBackendPrice: $value (decimal, reais)');
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

// Widget Modal para detalhes do orçamento com seleção de peças e opções
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
  final Map<int, bool> _selectedItems = {};
  final Map<int, String?> _selectedOptionIds = {};

  static const _priorityConfig = <int, _PriorityInfo>{
    5: _PriorityInfo('Essencial', Color(0xFFFF3B30)),
    4: _PriorityInfo('Muito importante', Color(0xFFFF9500)),
    3: _PriorityInfo('Importante', Color(0xFFFFCC00)),
    2: _PriorityInfo('Recomendado', Color(0xFF007AFF)),
    1: _PriorityInfo('Opcional', Color(0xFF8E8E93)),
  };

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.quoteItems.length; i++) {
      final item = widget.quoteItems[i];
      final priority = _parsePriority(item['priority']);
      _selectedItems[i] = true;
      final options = item['options'] as List?;
      if (options != null && options.isNotEmpty) {
        final defaultOpt = options.firstWhere((o) => o['is_default'] == true, orElse: () => options.first);
        _selectedOptionIds[i] = defaultOpt['id']?.toString();
      }
    }
  }

  int _parsePriority(dynamic raw) {
    if (raw is int) return raw.clamp(1, 5);
    if (raw is String) return int.tryParse(raw)?.clamp(1, 5) ?? 3;
    return 3;
  }

  bool _isRequired(dynamic item) {
    if (item['is_required'] == true) return true;
    return _parsePriority(item['priority']) == 5;
  }

  void _toggleItem(int index) {
    final item = widget.quoteItems[index];
    if (_isRequired(item)) return;
    setState(() {
      _selectedItems[index] = !(_selectedItems[index] ?? false);
    });
  }

  double _getItemPrice(dynamic item, int index) {
    final options = item['options'] as List?;
    if (options != null && options.isNotEmpty && _selectedOptionIds[index] != null) {
      final selectedOpt = options.firstWhere(
        (o) => o['id']?.toString() == _selectedOptionIds[index],
        orElse: () => null,
      );
      if (selectedOpt != null) {
        final raw = selectedOpt['unit_price'] ?? 0;
        return (raw is int ? raw : (raw is String ? int.tryParse(raw) ?? 0 : (raw is double ? raw.toInt() : 0))) / 100.0;
      }
    }
    final unitPriceRaw = item['unit_price'] ?? 0;
    return (unitPriceRaw is int ? unitPriceRaw : (unitPriceRaw is String ? int.tryParse(unitPriceRaw) ?? 0 : (unitPriceRaw is double ? unitPriceRaw.toInt() : 0))) / 100.0;
  }

  double? _parseDiagnosticValue(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return double.tryParse(raw);
    if (raw is int) return raw.toDouble();
    if (raw is double) return raw;
    return null;
  }

  double _calculateSelectedTotal() {
    double total = 0;
    for (var i = 0; i < widget.quoteItems.length; i++) {
      if (_selectedItems[i] != true) continue;
      final item = widget.quoteItems[i];
      final quantityRaw = item['quantity'] ?? 1;
      final quantity = quantityRaw is int ? quantityRaw : (quantityRaw is String ? int.tryParse(quantityRaw) ?? 1 : 1);
      total += _getItemPrice(item, i) * quantity;
    }
    final diagnosticValue = _parseDiagnosticValue(widget.diagnosticValue);
    if (diagnosticValue != null && diagnosticValue > 0) {
      total += diagnosticValue / 100.0;
    }
    return total;
  }

  List<Map<String, dynamic>> _buildResponseItems() {
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < widget.quoteItems.length; i++) {
      final item = widget.quoteItems[i];
      final itemId = item['id']?.toString();
      if (itemId == null) continue;
      final payload = <String, dynamic>{
        'quote_item_id': itemId,
        'selected': _selectedItems[i] ?? false,
      };
      if (_selectedOptionIds[i] != null && (_selectedItems[i] ?? false)) {
        payload['selected_option_id'] = _selectedOptionIds[i];
      }
      items.add(payload);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final selectedTotal = _calculateSelectedTotal();
    final hasSelection = _selectedItems.values.any((v) => v);
    final allSelected = _selectedItems.values.every((v) => v);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF00C977), Color(0xFF00B369)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Revisar Orçamento', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Selecione os itens e opções desejados', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ...widget.quoteItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = _selectedItems[index] ?? false;
                  final isRequired = _isRequired(item);
                  final priority = _parsePriority(item['priority']);
                  final pInfo = _priorityConfig[priority] ?? _priorityConfig[3]!;
                  final description = item['description'] ?? 'Item sem descrição';
                  final quantityRaw = item['quantity'] ?? 1;
                  final quantity = quantityRaw is int ? quantityRaw : (quantityRaw is String ? int.tryParse(quantityRaw) ?? 1 : 1);
                  final itemPrice = _getItemPrice(item, index);
                  final totalItem = itemPrice * quantity;
                  final options = item['options'] as List? ?? [];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF00C977) : (widget.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF00C977).withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))] : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isRequired)
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleItem(index),
                                  activeColor: const Color(0xFF00C977),
                                )
                              else
                                const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.lock, color: Color(0xFFFF3B30), size: 20),
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(description, style: TextStyle(
                                            fontSize: 15, fontWeight: FontWeight.w600,
                                            color: isSelected ? (widget.isDarkMode ? Colors.white : Colors.black87) : Colors.grey,
                                            decoration: isSelected ? null : TextDecoration.lineThrough,
                                          )),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: pInfo.color.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(pInfo.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pInfo.color)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Qtd: $quantity × ${PriceUtils.formatCurrency(itemPrice)}',
                                      style: TextStyle(fontSize: 13, color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                PriceUtils.formatCurrency(totalItem) ?? 'R\$ 0,00',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black87),
                              ),
                            ],
                          ),
                          if (options.isNotEmpty && isSelected) ...[
                            const Divider(height: 20),
                            Text('Escolha uma opção:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                            const SizedBox(height: 6),
                            ...options.map<Widget>((opt) {
                              final optId = opt['id']?.toString() ?? '';
                              final optDesc = opt['description']?.toString() ?? '';
                              final optPriceRaw = opt['unit_price'] ?? 0;
                              final optPrice = (optPriceRaw is int ? optPriceRaw : (optPriceRaw is String ? int.tryParse(optPriceRaw) ?? 0 : (optPriceRaw is double ? optPriceRaw.toInt() : 0))) / 100.0;
                              final isOptSelected = _selectedOptionIds[index] == optId;
                              return InkWell(
                                onTap: () => setState(() => _selectedOptionIds[index] = optId),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isOptSelected ? const Color(0xFF00C977).withOpacity(0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isOptSelected ? const Color(0xFF00C977) : Colors.grey.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      Radio<String>(
                                        value: optId,
                                        groupValue: _selectedOptionIds[index],
                                        activeColor: const Color(0xFF00C977),
                                        onChanged: (v) => setState(() => _selectedOptionIds[index] = v),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(optDesc, style: TextStyle(fontSize: 13, color: widget.isDarkMode ? Colors.white : Colors.black87))),
                                      Text(PriceUtils.formatCurrency(optPrice) ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                Builder(
                  builder: (context) {
                    final diagnosticValue = _parseDiagnosticValue(widget.diagnosticValue);
                    if (diagnosticValue == null || diagnosticValue <= 0) return const SizedBox.shrink();
                    final diagnosticInReais = diagnosticValue / 100.0;
                    return Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: widget.isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: widget.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                Icon(Icons.search, size: 16, color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                                const SizedBox(width: 6),
                                Text('Diagnóstico', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black87)),
                              ]),
                              Text(PriceUtils.formatCurrency(diagnosticInReais) ?? 'R\$ 0,00', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black87)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [const Color(0xFF00C977).withOpacity(0.1), const Color(0xFF00B369).withOpacity(0.1)]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00C977).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Selecionado:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black87)),
                      Text(PriceUtils.formatCurrency(selectedTotal) ?? 'R\$ 0,00', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00C977))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
              border: Border(top: BorderSide(color: widget.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: hasSelection ? () {
                      Navigator.of(context).pop();
                      final responseItems = _buildResponseItems();
                      widget.onApprove(allSelected ? null : responseItems);
                    } : null,
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: Text(
                      allSelected ? 'Aprovar Orçamento Completo' : 'Enviar Resposta — ${PriceUtils.formatCurrency(selectedTotal)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C977),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    label: const Text('Rejeitar Orçamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

class _PriorityInfo {
  final String label;
  final Color color;
  const _PriorityInfo(this.label, this.color);
}

