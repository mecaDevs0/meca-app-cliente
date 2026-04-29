
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../widgets/meca_toast.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/notification_provider.dart';
import '../../services/api_service.dart';
import '../../utils/price_utils.dart';
import '../../widgets/app_alerts.dart';
import '../../widgets/meca_loading_widget.dart';
import 'expired_bookings_screen.dart';
import '../pre_compra/pre_compra_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  String _currentStatus = 'pendente_oficina';
  Map<String, Map<String, dynamic>> _vehicleData = {};
  final TextEditingController _pendingSearchController = TextEditingController();
  String _pendingSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pendingSearchController.addListener(() {
      if (mounted) setState(() => _pendingSearchQuery = _pendingSearchController.text);
    });
    _tabController.addListener(() {
      final statuses = ['pendente_oficina', 'confirmado', 'finalizado_cliente'];
      setState(() {
        final index = _tabController.index;
        if (index >= 0 && index < statuses.length) {
          _currentStatus = statuses[index];
        }
      });
      // IMPORTANTE: Forçar refresh ao mudar de aba para garantir dados atualizados
      _loadBookings(forceRefresh: true);
    });
    _loadBookings();
    // Marcar todas as notificações como lidas automaticamente ao entrar na tela
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllNotificationsAsRead();
    });
  }

  // Marcar todas as notificações como lidas silenciosamente
  Future<void> _markAllNotificationsAsRead() async {
    try {
      final result = await _apiService.markAllNotificationsRead();
      // Atualizar provider de notificações
      if (mounted && result['success'] == true) {
        final provider = Provider.of<NotificationProvider>(context, listen: false);
        // Marcar todas as notificações no provider como lidas
        final updatedNotifications = provider.notifications.map((n) {
          return Map<String, dynamic>.from(n)
            ..['is_read'] = true
            ..['read'] = true;
        }).toList();
        provider.setNotifications(updatedNotifications);
        provider.setUnreadNotifications(0, resetBadge: true);
      // Recarregar bookings para garantir sincronização
      // NÃO recarregar notificações - já foram marcadas localmente
      _loadBookings(forceRefresh: false);
      }
    } catch (e) {
      // Silenciar erros
      print('Erro ao marcar notificações como lidas: $e');
    }
  }

  Future<void> _loadBookings({bool forceRefresh = false}) async {
    if (!mounted) return;

    // IMPORTANTE: Invalidar cache se forçar refresh
    if (forceRefresh) {
      _apiService.invalidateBookingsCache();
    }

    setState(() => _loading = true);

    // Buscar bookings normais e pré-compras em paralelo
    final results = await Future.wait([
      _apiService.getBookings(),
      _apiService.getPreCompras(forceRefresh: forceRefresh),
    ]);

    if (!mounted) return;

    final bookingResult = results[0];
    final preCompraResult = results[1];

    // Normalizar resposta de bookings
    List<Map<String, dynamic>> bookings = [];
    if (bookingResult['success'] == true) {
      final data = bookingResult['data'];
      if (data is List) {
        bookings = data.cast<Map<String, dynamic>>();
      } else if (data is Map && data['bookings'] != null) {
        bookings = (data['bookings'] as List).cast<Map<String, dynamic>>();
      }
    }

    // Mesclar pré-compras na lista
    if (preCompraResult['success'] == true) {
      final preCompras = (preCompraResult['data'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      bookings = [...bookings, ...preCompras];
    }

    // Filtrar por status — pré-compras têm mapeamento diferente
    bookings = bookings.where((b) {
      final isPreCompra = b['booking_type'] == 'pre_compra';
      final rawStatus = (b['status'] ?? '').toString();
      final paymentStatus = isPreCompra ? (b['payment_status']?.toString() ?? '') : null;
      final bucket = isPreCompra
          ? _bucketForPreCompraStatus(rawStatus, paymentStatus: paymentStatus)
          : _bucketForStatus(rawStatus);

      if (_currentStatus == 'pendente_oficina') return bucket == 'pending';
      if (_currentStatus == 'confirmado') return bucket == 'confirmed';
      if (_currentStatus == 'finalizado_cliente') return bucket == 'completed';
      return b['status'] == _currentStatus;
    }).toList().cast<Map<String, dynamic>>();

    // Ordenar pendentes: futuros primeiro (mais próximo do hoje no topo), passados por último
    if (_currentStatus == 'pendente_oficina') {
      final now = DateTime.now();
      bookings.sort((a, b) {
        final dateAStr = a['appointment_date'] ?? a['scheduled_date'] ?? a['inspection_date'];
        final dateBStr = b['appointment_date'] ?? b['scheduled_date'] ?? b['inspection_date'];
        if (dateAStr == null && dateBStr == null) return 0;
        if (dateAStr == null) return 1;
        if (dateBStr == null) return -1;
        try {
          final da = DateTime.parse(dateAStr.toString());
          final db = DateTime.parse(dateBStr.toString());
          final isPastA = da.isBefore(now);
          final isPastB = db.isBefore(now);
          // Futuro antes de passado
          if (!isPastA && isPastB) return -1;
          if (isPastA && !isPastB) return 1;
          // Ambos futuros: mais próximo primeiro (ASC)
          if (!isPastA && !isPastB) return da.compareTo(db);
          // Ambos passados: mais recente primeiro (mais perto de hoje)
          return db.compareTo(da);
        } catch (e) {
          return 0;
        }
      });
    }

    // Carregar dados dos veículos (apenas para bookings normais)
    await _loadVehicleData(bookings);

    if (mounted) {
      setState(() {
        _bookings = bookings;
        _loading = false;
      });
    }
  }

  Future<void> _loadVehicleData(List<Map<String, dynamic>> bookings) async {
    try {
      final vehiclesResult = await _apiService.getUserVehicles();
      if (vehiclesResult['success']) {
        final vehicles = (vehiclesResult['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        
        // Remover duplicatas baseado no ID antes de adicionar ao Map
        final uniqueVehicles = <String, Map<String, dynamic>>{};
        for (var vehicle in vehicles) {
          final id = vehicle['id']?.toString() ?? '';
          if (id.isNotEmpty && !uniqueVehicles.containsKey(id)) {
            uniqueVehicles[id] = vehicle;
          }
        }
        
        // Adicionar ao _vehicleData
        for (var vehicle in uniqueVehicles.values) {
          _vehicleData[vehicle['id']] = vehicle;
        }
      }
    } catch (e) {
      print('Erro ao carregar dados dos veículos: $e');
    }
  }

  String _getVehicleDisplayName(Map<String, dynamic> booking) {
    // Primeiro tenta usar vehicle_snapshot se disponível
    if (booking['vehicle_snapshot'] != null) {
      final snapshot = booking['vehicle_snapshot'];
      return '${snapshot['brand'] ?? ''} ${snapshot['model'] ?? ''} - ${snapshot['plate'] ?? ''}';
    }
    
    // Se não, tenta usar os dados carregados do veículo
    if (booking['vehicle_id'] != null && _vehicleData.containsKey(booking['vehicle_id'])) {
      final vehicle = _vehicleData[booking['vehicle_id']];
      return '${vehicle?['brand'] ?? ''} ${vehicle?['model'] ?? ''} - ${vehicle?['plate'] ?? ''}';
    }
    
    // Se não há dados, mostra uma mensagem genérica
    return 'Veículo não informado';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isPendingTab = _currentStatus == 'pendente_oficina';
    final List<Map<String, dynamic>> pendingUpcoming = [];
    final List<Map<String, dynamic>> pendingExpired = [];

    if (isPendingTab && _bookings.isNotEmpty) {
      final today = DateTime.now();
      final rawUpcoming = <Map<String, dynamic>>[];
      final rawExpired = <Map<String, dynamic>>[];
      for (final booking in _bookings) {
        if (_isBookingExpired(booking, today)) {
          if (!_hasAmountToPay(booking)) {
            rawExpired.add(booking);
          } else {
            rawUpcoming.add(booking);
          }
        } else {
          rawUpcoming.add(booking);
        }
      }
      pendingUpcoming.addAll(_filterPendingBySearch(rawUpcoming));
      pendingExpired.addAll(_filterPendingBySearch(rawExpired));
    }

    final hasExpiredSection = isPendingTab && pendingExpired.isNotEmpty;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0A0A0A) : Colors.white,
      body: CustomScrollView(
        slivers: [
          // AppBar melhorado
          SliverAppBar(
            expandedHeight: 60,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF00C977),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                );
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Meus Agendamentos',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF00C977),
                      Color(0xFF00B369),
                      Color(0xFF00A85C),
                    ],
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // TabBar com design moderno estilo iOS
          SliverPersistentHeader(
            pinned: true,
            delegate: _SimpleTabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isDarkMode ? const Color(0xFF00B369).withOpacity(0.3) : const Color(0xFF00C977).withOpacity(0.2),
                  boxShadow: [
                    BoxShadow(
                      color: (isDarkMode ? const Color(0xFF00B369) : const Color(0xFF00C977)).withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                tabs: [
                  _buildTabWithBadge('Pendentes', 'pendente_oficina'),
                  _buildTabWithBadge('Confirmados', 'confirmado'),
                  _buildTabWithBadge('Concluídos', 'finalizado_cliente'),
                ],
              ),
              isDarkMode: isDarkMode,
            ),
          ),
          // Conteúdo principal
          SliverFillRemaining(
            child: _loading
                ? const MecaApiLoadingWidget(message: 'Carregando agendamentos...')
                : RefreshIndicator(
                    color: const Color(0xFF00C977),
                    onRefresh: _loadBookings,
                    child: _bookings.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C977).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF00C977).withOpacity(0.2),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.event_busy,
                                        size: 80,
                                        color: Color(0xFF00C977),
                                      ),
                                      const SizedBox(height: 20),
                                      const Text(
                                        'Nenhum agendamento encontrado',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF00C977),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Agende um serviço para começar',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(15),
                            itemCount: isPendingTab
                                ? 1 + // Ajuste 3: barra de pesquisa
                                    (pendingUpcoming.isEmpty && pendingExpired.isEmpty && _pendingSearchQuery.trim().isNotEmpty ? 1 : 0) +
                                    (pendingUpcoming.isNotEmpty ? 1 : 0) +
                                    pendingUpcoming.length +
                                    (hasExpiredSection ? 1 : 0)
                                : _bookings.length,
                            itemBuilder: (context, index) {
                              if (!isPendingTab) {
                                final booking = _bookings[index];
                                return booking['booking_type'] == 'pre_compra'
                                    ? _buildPreCompraCard(booking)
                                    : _buildBookingCard(booking);
                              }

                              // Ajuste 3: barra de pesquisa (primeiro item na aba Pendentes)
                              if (index == 0) {
                                return _buildPendingSearchBar(isDarkMode);
                              }

                              final noResults = pendingUpcoming.isEmpty && pendingExpired.isEmpty && _pendingSearchQuery.trim().isNotEmpty;
                              if (noResults && index == 1) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 24),
                                  child: Center(
                                    child: Text(
                                      'Nenhum resultado para sua pesquisa.',
                                      style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                                    ),
                                  ),
                                );
                              }

                              final offset = noResults ? 2 : 1;
                              final showBanner = pendingUpcoming.isNotEmpty;
                              final adjustedForSearch = index - offset;
                              if (showBanner && adjustedForSearch == 0) {
                                return _buildPendingInfoBanner(pendingUpcoming);
                              }

                              final adjustedIndex = showBanner ? adjustedForSearch - 1 : adjustedForSearch;

                              if (adjustedIndex < pendingUpcoming.length) {
                                final item = pendingUpcoming[adjustedIndex];
                                return item['booking_type'] == 'pre_compra'
                                    ? _buildPreCompraCard(item)
                                    : _buildBookingCard(item);
                              }

                              if (hasExpiredSection && adjustedIndex == pendingUpcoming.length) {
                                return _buildExpiredDivider(pendingExpired.length, pendingExpired);
                              }

                              return const SizedBox.shrink();
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSearchBar(bool isDarkMode) {
    final bg = isDarkMode ? const Color(0xFF1A1A1A) : Colors.grey.shade100;
    final borderColor = isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _pendingSearchController,
        decoration: InputDecoration(
          hintText: 'Buscar por oficina, serviço ou observação...',
          hintStyle: TextStyle(fontSize: 13, color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600),
          prefixIcon: Icon(Icons.search, size: 20, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
          filled: true,
          fillColor: bg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor, width: 1)),
        ),
        style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white : Colors.black87),
      ),
    );
  }

  Widget _buildPendingInfoBanner(List<Map<String, dynamic>> pendingBookings) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bg = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final border = const Color(0xFF00C977).withOpacity(isDarkMode ? 0.25 : 0.22);
    final textPrimary = isDarkMode ? Colors.white : Colors.black87;
    final textSecondary = isDarkMode ? Colors.white70 : Colors.black54;

    int awaitingWorkshop = 0;
    int awaitingYou = 0;
    int awaitingPayment = 0;
    for (final b in pendingBookings) {
      final normalized = _normalizeStatusKeyForList((b['status'] ?? '').toString());
      if (normalized == 'pending') {
        awaitingWorkshop += 1;
      } else if (normalized == 'awaiting_payment') {
        awaitingPayment += 1;
        awaitingYou += 1; // pagamento é ação do cliente
      } else {
        awaitingYou += 1;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C977).withOpacity(isDarkMode ? 0.08 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF00C977).withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline, color: Color(0xFF00C977), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pendentes',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Aqui aparecem agendamentos que ainda têm alguma pendência — '
                  'aguardando a oficina ou aguardando uma ação sua (aprovação, autorização ou pagamento).',
                  style: TextStyle(
                    color: textSecondary,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildPendingPillCompact(
                        label: 'Oficina',
                        value: awaitingWorkshop.toString(),
                        icon: Icons.storefront_outlined,
                        bg: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                        fg: textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPendingPillCompact(
                        label: 'Você',
                        value: awaitingYou.toString(),
                        icon: Icons.person_outline,
                        bg: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                        fg: textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPendingPillCompact(
                        label: 'Pago',
                        value: awaitingPayment.toString(),
                        icon: Icons.payments_outlined,
                        bg: isDarkMode ? const Color(0xFF1A2338) : const Color(0xFFE0F2FF),
                        fg: isDarkMode ? Colors.white70 : const Color(0xFF1B6DC1),
                        isMuted: awaitingPayment == 0,
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

  Widget _buildPendingPillCompact({
    required String label,
    required String value,
    required IconData icon,
    required Color bg,
    required Color fg,
    bool isMuted = false,
  }) {
    final effectiveFg = isMuted ? fg.withOpacity(0.55) : fg;
    final effectiveBg = isMuted ? bg.withOpacity(0.55) : bg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: effectiveFg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: effectiveFg,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: effectiveFg,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingPill({
    required String label,
    required IconData icon,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _normalizeStatusKeyForList(String rawStatus) {
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

  String _bucketForStatus(String rawStatus) {
    final normalized = _normalizeStatusKeyForList(rawStatus);
    if (normalized == 'paid') return 'completed';
    if (normalized == 'confirmed' || normalized == 'in_progress') return 'confirmed';
    return 'pending';
  }

  /// Status de pré-compra → tab (mapeamento diferente do booking normal)
  String _bucketForPreCompraStatus(String rawStatus, {String? paymentStatus}) {
    final s = rawStatus.toLowerCase().trim();
    // Backward compat: concluido sem pagamento = aguardando_pagamento (tab Confirmados)
    if (s == 'concluido' || s == 'concluído') {
      return (paymentStatus == 'pago') ? 'completed' : 'confirmed';
    }
    if (s == 'confirmado' || s == 'em_andamento' || s == 'aguardando_pagamento') return 'confirmed';
    if (s == 'cancelado') return 'completed';
    return 'pending'; // 'pendente'
  }

  Widget _buildPreCompraCard(Map<String, dynamic> item) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final status = (item['status'] ?? 'pendente').toString();
    final paymentStatus = item['payment_status']?.toString() ?? '';
    // Backward compat: concluido+unpaid exibir como aguardando_pagamento
    final effectiveStatus = (status == 'concluido' && paymentStatus != 'pago') ? 'aguardando_pagamento' : status;
    final statusConfig = _getPreCompraStatusConfig(effectiveStatus, isDarkMode: isDarkMode);
    final brand = (item['vehicle_brand'] ?? '').toString();
    final model = (item['vehicle_model'] ?? '').toString();
    final year = (item['vehicle_year'] ?? '').toString();
    final vehicleDesc = [brand, model, year].where((s) => s.isNotEmpty).join(' ');
    final workshopName = (item['workshop_name'] ?? 'Oficina').toString();
    final bool hasLaudo = item['laudo_pdf_key'] != null && paymentStatus == 'pago';

    String dateStr = 'Data não definida';
    final rawDate = item['inspection_date'] ?? item['created_at'];
    if (rawDate != null) {
      try {
        final parsed = DateTime.parse(rawDate.toString()).toLocal();
        final prefix = item['inspection_date'] != null ? '' : 'Solicitado em ';
        dateStr = '$prefix${DateFormat('dd/MM/yyyy').format(parsed)}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [const Color(0xFF1A1A1A), const Color(0xFF2A2A2A)]
              : [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00C977).withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C977).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final id = item['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PreCompraDetailScreen(preCompraId: id),
                ),
              ).then((_) {
                if (mounted) _loadBookings(forceRefresh: true);
              });
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          workshopName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C977).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF00C977).withOpacity(0.4)),
                          ),
                          child: const Text(
                            'Pré-Compra',
                            style: TextStyle(
                              color: Color(0xFF00C977),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusConfig['color'],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            statusConfig['label'],
                            style: TextStyle(
                              color: statusConfig['textColor'],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                // Date
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: TextStyle(
                          color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Vehicle
                Row(
                  children: [
                    Icon(Icons.directions_car, size: 16,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vehicleDesc.isNotEmpty ? vehicleDesc : 'Veículo a inspecionar',
                        style: TextStyle(
                            color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
                // PDF indicator
                if (hasLaudo) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.picture_as_pdf, size: 16, color: Colors.red.shade400),
                      const SizedBox(width: 8),
                      Text(
                        'Laudo disponível para download',
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getPreCompraStatusConfig(String status, {bool isDarkMode = false}) {
    switch (status.toLowerCase().trim()) {
      case 'confirmado':
        return {
          'label': 'Confirmado',
          'color': isDarkMode ? const Color(0xFF1A2332) : const Color(0xFFE3EDFA),
          'textColor': isDarkMode ? const Color(0xFF6BA3FF) : const Color(0xFF7896D8),
        };
      case 'em_andamento':
        return {
          'label': 'Em Andamento',
          'color': isDarkMode ? const Color(0xFF1A2E1F) : const Color(0xFFE8FFEE),
          'textColor': isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF2FD65C),
        };
      case 'aguardando_pagamento':
        return {
          'label': 'Aguardando Pagamento',
          'color': isDarkMode ? const Color(0xFF3D2F1A) : const Color(0xFFFCF4E5),
          'textColor': isDarkMode ? const Color(0xFFFFC94A) : const Color(0xFFDBA800),
        };
      case 'concluido':
      case 'concluído':
        return {
          'label': 'Concluído',
          'color': isDarkMode ? const Color(0xFF1A2E1F) : const Color(0xFFE8FFEE),
          'textColor': isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF2FD65C),
        };
      case 'cancelado':
        return {
          'label': 'Cancelado',
          'color': isDarkMode ? const Color(0xFF3D1F1F) : const Color(0xFFFEE2E2),
          'textColor': isDarkMode ? const Color(0xFFFF6B6B) : const Color(0xFFE8867C),
        };
      default:
        return {
          'label': 'Pendente',
          'color': isDarkMode ? const Color(0xFF3D2F1A) : const Color(0xFFFCF4E5),
          'textColor': isDarkMode ? const Color(0xFFFFC94A) : const Color(0xFFDBA800),
        };
    }
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, {bool isExpired = false}) {
    final status = booking['status'] ?? 'pending';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final statusConfig = _getStatusConfig(status, isDarkMode: isDarkMode);
    final normalizedStatus = _normalizeStatusKeyForList((status ?? '').toString());
    final isAwaitingPayment = normalizedStatus == 'awaiting_payment';
    final attachments = (booking['customer_uploads'] is List)
        ? List<Map<String, dynamic>>.from(booking['customer_uploads'])
        : (booking['customerUploads'] is List)
            ? List<Map<String, dynamic>>.from(booking['customerUploads'])
            : <Map<String, dynamic>>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  const Color(0xFF1A1A1A),
                  const Color(0xFF2A2A2A),
                ]
              : [
                  Colors.white,
                  Colors.grey.shade50,
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00C977).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C977).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // IMPORTANTE: Aguardar resultado para atualizar se necessário
            final result = await Navigator.pushNamed(
              context,
              '/order-detail',
              arguments: booking,
            );
            // Se retornou true, significa que houve atualização e precisa recarregar
            if (result == true && mounted) {
              // IMPORTANTE: Forçar refresh sem usar cache
              await _loadBookings(forceRefresh: true);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          booking['workshop_name'] ?? 'Oficina',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        if (isExpired)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.history, size: 14, color: Colors.orange),
                                SizedBox(width: 4),
                                Text(
                                  'Expirado',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusConfig['color'],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            statusConfig['label'],
                            style: TextStyle(
                              color: statusConfig['textColor'],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                if (isAwaitingPayment) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: (isDarkMode ? const Color(0xFF1A2338) : const Color(0xFFE0F2FF)).withOpacity(0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.payments_outlined, color: const Color(0xFF1B6DC1).withOpacity(0.85), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pagamento pendente. Para concluir o serviço e poder avaliar a oficina, finalize o pagamento.',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white70 : Colors.black87,
                              fontWeight: FontWeight.w500,
                              fontSize: 12.5,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Date & Time - Suporte para janela de horários
                Builder(
                  builder: (context) {
                    final scheduleType = booking['schedule_type']?.toString() ?? 'specific_time';
                    final isTimeWindow = scheduleType == 'time_window';
                    
                    if (isTimeWindow && booking['time_window_start'] != null && booking['time_window_end'] != null) {
                      // Exibir janela de horários
                      try {
                        final startTime = DateTime.parse(booking['time_window_start']);
                        final endTime = DateTime.parse(booking['time_window_end']);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 16, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(startTime),
                                  style: TextStyle(color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 16, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Text(
                                  '${DateFormat('HH:mm').format(startTime)} até ${DateFormat('HH:mm').format(endTime)}',
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      } catch (e) {
                        // Fallback para exibição padrão se houver erro ao parsear
                      }
                    }
                    
                    // Exibição padrão para horário específico
                    return Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          booking['appointment_date'] != null
                              ? DateFormat('dd/MM/yyyy').format(DateTime.parse(booking['appointment_date']))
                              : 'Data não definida',
                          style: TextStyle(color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700),
                        ),
                        const SizedBox(width: 15),
                        Icon(Icons.access_time, size: 16, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          booking['appointment_date'] != null
                              ? DateFormat('HH:mm').format(DateTime.parse(booking['appointment_date']))
                              : '00:00',
                          style: TextStyle(color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Vehicle
                Row(
                  children: [
                    Icon(Icons.directions_car, size: 16, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      _getVehicleDisplayName(booking),
                      style: TextStyle(color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Services
                if (booking['customer_notes'] != null && (booking['customer_notes'] as String).isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C977).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      booking['customer_notes'],
                      style: const TextStyle(
                        color: Color(0xFF00C977),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.photo_camera_back_outlined,
                          size: 16, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        attachments.length == 1
                            ? '1 foto anexada'
                            : '${attachments.length} fotos anexadas',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 15),

                // Total - só mostra se houver preço
                // Priorizar final_price (orçamento aprovado) sobre outros valores
                Builder(builder: (context) {
                  // Extrair preço usando a mesma lógica do order_detail_screen
                  double? finalPrice;
                  
                  // Primeiro, tentar final_price (orçamento aprovado)
                  final rawFinalPrice = booking['final_price'] ?? booking['finalPrice'];
                  
                  // DEBUG: Log para verificar valor bruto
                  debugPrint('💰 [OrdersScreen] final_price raw: $rawFinalPrice, type: ${rawFinalPrice?.runtimeType}');
                  
                  finalPrice = PriceUtils.extractPrice(rawFinalPrice);
                  
                  // DEBUG: Log para verificar valor convertido
                  if (finalPrice != null) {
                    debugPrint('💰 [OrdersScreen] finalPrice converted: $finalPrice (R\$ ${finalPrice.toStringAsFixed(2)})');
                  }
                  
                  // Se não tiver final_price, tentar outros campos
                  if (finalPrice == null) {
                    finalPrice = PriceUtils.extractPrice(
                      booking['approved_amount'] ?? 
                      booking['approvedAmount'] ?? 
                      booking['final_amount'] ?? 
                      booking['finalAmount'] ??
                      booking['total'] ?? 
                      booking['estimated_price'] ?? 
                      booking['service_price']
                    );
                  }
                  
                  // IMPORTANTE: finalPrice já está convertido para reais, formatar diretamente
                  final totalLabel = finalPrice != null ? 'R\$ ${finalPrice.toStringAsFixed(2).replaceAll('.', ',')}' : null;
                  if (totalLabel == null) return const SizedBox.shrink();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        totalLabel,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00C977),
                        ),
                      ),
                    ],
                  );
                }),
                
                // Botões para aceitar/recusar sugestão de horário
                Builder(
                  builder: (context) {
                    // IMPORTANTE: Não exibir se já está confirmado
                    final currentStatus = (status ?? '').toString().toLowerCase().trim();
                    if (currentStatus == 'confirmado' || currentStatus == 'confirmed') {
                      return const SizedBox.shrink();
                    }
                    
                    final suggestedBy = booking['suggested_by'] ?? booking['sugerido_por'];
                    final hasSuggestedDate = booking['suggested_date'] != null || booking['data_sugerida'] != null;
                    final isTimeSuggestion = (suggestedBy == 'oficina' || suggestedBy == 'workshop') && 
                                            hasSuggestedDate && 
                                            currentStatus == 'pendente_cliente';
                    
                    if (!isTimeSuggestion) return const SizedBox.shrink();
                    
                    final suggestedDateStr = booking['suggested_date'] ?? booking['data_sugerida'];
                    DateTime? suggestedDate;
                    try {
                      if (suggestedDateStr != null) {
                        suggestedDate = DateTime.parse(suggestedDateStr.toString());
                      }
                    } catch (e) {
                      // Ignorar erro
                    }
                    
                    return Column(
                      children: [
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFF59E0B).withOpacity(0.15),
                                const Color(0xFFF97316).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withOpacity(0.4),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.schedule_rounded,
                                      color: Color(0xFFF59E0B),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Nova Sugestão de Horário',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isDarkMode ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        if (suggestedDate != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '${DateFormat('dd/MM/yyyy').format(suggestedDate)} às ${DateFormat('HH:mm').format(suggestedDate)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _rejectTimeSuggestion(booking),
                                      icon: const Icon(Icons.close_rounded, size: 18),
                                      label: const Text(
                                        'Recusar',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFEF4444),
                                        side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _acceptTimeSuggestion(booking),
                                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                                      label: const Text(
                                        'Aceitar',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00C977),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                
                // Seção de contato WhatsApp - quando status do agendamento for no mínimo confirmado
                Builder(
                  builder: (context) {
                    final normalizedStatus = status.toString().toLowerCase().trim();
                    final canShowPhone = [
                      'confirmado', 'confirmed',
                      'em_andamento', 'in_progress',
                      'aguardando_autorizacao_inicio',
                      'aguardando_aprovacao_finalizacao',
                      'aguardando_aprovacao_orcamento',
                      'finalizado', 'finalizado_aguardando_pagamento',
                      'aguardando_pagamento',
                    ].contains(normalizedStatus);
                    
                    if (!canShowPhone) return const SizedBox.shrink();
                    
                    // Obter telefone da oficina
                    final workshopPhone = booking['workshop_phone'] ?? 
                                        booking['workshop']?['phone'] ?? 
                                        booking['oficina_phone'] ?? 
                                        '';
                    
                    if (workshopPhone.toString().isEmpty || workshopPhone == 'Telefone não informado') {
                      return const SizedBox.shrink();
                    }
                    
                    // Limpar telefone (remover caracteres não numéricos)
                    final cleanPhone = workshopPhone.toString().replaceAll(RegExp(r'[^0-9]'), '');
                    if (cleanPhone.isEmpty) return const SizedBox.shrink();
                    
                    // Formatar telefone para WhatsApp (adicionar código do país se necessário)
                    String whatsappNumber = cleanPhone;
                    if (!whatsappNumber.startsWith('55') && cleanPhone.length >= 10) {
                      whatsappNumber = '55$cleanPhone';
                    }
                    
                    return Column(
                      children: [
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF25D366).withOpacity(isDarkMode ? 0.2 : 0.1),
                                const Color(0xFF128C7E).withOpacity(isDarkMode ? 0.15 : 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF25D366).withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF25D366).withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25D366).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: Color(0xFF25D366),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Contato com a Oficina',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isDarkMode ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Entre em contato via WhatsApp',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        final url = 'https://wa.me/$whatsappNumber';
                                        // ignore: avoid_print
                                        print('Abrindo WhatsApp: $url');
                                        // Usar url_launcher para abrir WhatsApp
                                        // ignore: unawaited_futures
                                        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                      },
                                      icon: const Icon(Icons.chat, size: 18),
                                      label: const Text(
                                        'Abrir WhatsApp',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF25D366),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      // Copiar número para área de transferência
                                      Clipboard.setData(ClipboardData(text: cleanPhone));
                                      MecaToast.showSuccess(context, 'Número copiado!');
                                    },
                                    icon: const Icon(Icons.copy, size: 18),
                                    label: const Text('Copiar'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF25D366),
                                      side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpiredDivider(int expiredCount, List<Map<String, dynamic>> expiredBookings) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: isDarkMode ? Colors.white12 : Colors.grey.shade300,
            thickness: 1,
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExpiredBookingsScreen(expiredBookings: expiredBookings),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Agendamentos pendentes expirados',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          expiredCount == 1
                              ? 'Este agendamento passou da data prevista e aguarda ação manual.'
                              : '$expiredCount agendamentos pendentes passaram da data prevista e aguardam ação manual.',
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.orange.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isBookingExpired(Map<String, dynamic> booking, DateTime reference) {
    final bookingDate = _parseBookingDate(booking);
    if (bookingDate == null) return false;
    final dayStart = DateTime(reference.year, reference.month, reference.day);
    final bookingDay = DateTime(bookingDate.year, bookingDate.month, bookingDate.day);
    return bookingDay.isBefore(dayStart);
  }

  /// Agendamentos com valor a pagar NUNCA devem ir para pendentes expirados (cliente precisa ver para pagar)
  bool _hasAmountToPay(Map<String, dynamic> booking) {
    final normalized = _normalizeStatusKeyForList((booking['status'] ?? '').toString());
    if (normalized != 'awaiting_payment') return false;
    final price = PriceUtils.extractPrice(
      booking['final_price'] ?? booking['finalPrice'] ??
      booking['approved_amount'] ?? booking['approvedAmount'] ??
      booking['final_amount'] ?? booking['finalAmount']
    );
    return price != null && price > 0;
  }

  DateTime? _parseBookingDate(Map<String, dynamic> booking) {
    final possibleDates = [
      booking['appointment_date'],
      booking['scheduled_date'],
      booking['expected_date'],
    ];
    for (final raw in possibleDates) {
      if (raw == null) continue;
      try {
        final parsed = DateTime.parse(raw.toString());
        return parsed.toLocal();
      } catch (_) {}
    }
    return null;
  }

  Map<String, dynamic> _getStatusConfig(String status, {bool isDarkMode = false}) {
    // Normalizar o status para minúsculas e remover espaços
    final normalizedStatus = status.toString().toLowerCase().trim();
    
    // Mapear status da API para status de exibição
    final statusMap = {
      'pendente_oficina': 'pending',
      'pendente_cliente': 'pending_customer',
      'pendente': 'pending',
      'pending': 'pending',
      'confirmado': 'confirmed',
      'confirmado_oficina': 'confirmed',
      'confirmed': 'confirmed',
      'em_andamento': 'in_progress',
      'em andamento': 'in_progress',
      'in_progress': 'in_progress',
      'finalizado_aguardando_pagamento': 'awaiting_payment',
      'finalizado_cliente': 'completed',
      'finalizado': 'awaiting_payment',
      'concluido': 'awaiting_payment',
      'concluído': 'awaiting_payment',
      'completed': 'awaiting_payment',
      'pago': 'completed',
      'cancelado': 'cancelled',
      'cancelled': 'cancelled',
    };
    
    final mappedStatus = statusMap[normalizedStatus] ?? normalizedStatus;
    
    // Cores adaptadas para modo escuro e claro
    final configs = {
      'pending': {
        'label': 'Pendente',
        'color': isDarkMode ? const Color(0xFF3D2F1A) : const Color(0xFFFCF4E5),
        'textColor': isDarkMode ? const Color(0xFFFFC94A) : const Color(0xFFDBA800),
      },
      'pending_customer': {
        'label': 'Aguardando você',
        'color': isDarkMode ? const Color(0xFF3D2A1A) : const Color(0xFFFFF4E6),
        'textColor': isDarkMode ? const Color(0xFFFF9F4A) : const Color(0xFFEF8E1C),
      },
      'confirmed': {
        'label': 'Confirmado',
        'color': isDarkMode ? const Color(0xFF1A2332) : const Color(0xFFE3EDFA),
        'textColor': isDarkMode ? const Color(0xFF6BA3FF) : const Color(0xFF7896D8),
      },
      'in_progress': {
        'label': 'Em Andamento',
        'color': isDarkMode ? const Color(0xFF1A2E1F) : const Color(0xFFE8FFEE),
        'textColor': isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF2FD65C),
      },
      'awaiting_payment': {
        'label': 'Aguardando Pagamento',
        'color': isDarkMode ? const Color(0xFF1A2338) : const Color(0xFFE0F2FF),
        'textColor': isDarkMode ? const Color(0xFF5BA3FF) : const Color(0xFF1B6DC1),
      },
      'completed': {
        'label': 'Concluído',
        'color': isDarkMode ? const Color(0xFF1A2E1F) : const Color(0xFFE8FFEE),
        'textColor': isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF2FD65C),
      },
      'cancelled': {
        'label': 'Cancelado',
        'color': isDarkMode ? const Color(0xFF3D1F1F) : const Color(0xFFFEE2E2),
        'textColor': isDarkMode ? const Color(0xFFFF6B6B) : const Color(0xFFE8867C),
      },
    };
    
    return configs[mappedStatus] ?? configs['pending']!;
  }

  Widget _buildTabWithBadge(String label, String status) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final hasUnread = _hasUnreadNotificationsForStatus(notificationProvider, status);
        return Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label),
              if (hasUnread) ...[
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  bool _hasUnreadNotificationsForStatus(NotificationProvider provider, String status) {
    for (final notification in provider.notifications) {
      final isRead = notification['read'] == true || notification['is_read'] == true;
      if (isRead) continue;

      final type = (notification['type'] ?? '').toString().toLowerCase();
      final title = (notification['title'] ?? '').toString().toLowerCase();
      final message = (notification['message'] ?? '').toString().toLowerCase();
      final bookingStatus = notification['booking_status']?.toString().toLowerCase() ?? 
                           notification['data']?['booking_status']?.toString().toLowerCase() ?? '';

      // Verificar se é notificação relacionada a agendamento
      final bool isBookingRelated = type.contains('booking') ||
          type.contains('agendamento') ||
          title.contains('agendamento') ||
          message.contains('agendamento') ||
          title.contains('oficina') ||
          message.contains('oficina');

      if (!isBookingRelated) continue;

      // Mapear status para verificar correspondência
      final normalizedStatus = status.toLowerCase();
      if (normalizedStatus == 'pendente_oficina') {
        // Pendentes incluem: aguardando oficina OU aguardando você (aprovações, autorização, pagamento)
        if (title.contains('pendente') ||
            message.contains('pendente') ||
            title.contains('sugestão') ||
            message.contains('sugestão') ||
            title.contains('horário') ||
            message.contains('horário') ||
            title.contains('orçamento') ||
            message.contains('orçamento') ||
            title.contains('aprovar') ||
            message.contains('aprovar') ||
            title.contains('autoriz') ||
            message.contains('autoriz') ||
            title.contains('pagamento') ||
            message.contains('pagamento') ||
            bookingStatus.contains('pendente') ||
            bookingStatus.contains('aguardando') ||
            bookingStatus.contains('finalizado_aguardando_pagamento')) {
          return true;
        }
      } else if (normalizedStatus == 'confirmado') {
        // Notificações de confirmados: quando oficina confirma agendamento
        if (title.contains('confirmado') || 
            title.contains('confirmou') ||
            message.contains('confirmado') ||
            message.contains('confirmou') ||
            bookingStatus.contains('confirmado') ||
            bookingStatus.contains('confirmed')) {
          return true;
        }
      } else if (normalizedStatus == 'finalizado_cliente') {
        // Concluídos (nesta aba) = PAGOS
        if (title.contains('pago') ||
            title.contains('pagamento confirmado') ||
            message.contains('pago') ||
            message.contains('pagamento confirmado') ||
            bookingStatus.contains('pago') ||
            bookingStatus.contains('paid') ||
            bookingStatus.contains('finalizado_cliente')) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _acceptTimeSuggestion(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
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
        // IMPORTANTE: Invalidar cache de bookings para forçar reload
        _apiService.invalidateBookingsCache();
        _apiService.invalidateBookingCache(bookingId);
        
        AppAlerts.showSuccess(
          context,
          message: 'Horário aceito com sucesso! O agendamento está confirmado.',
        );
        // IMPORTANTE: Forçar reload sem usar cache
        await _loadBookings(forceRefresh: true);
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

  Future<void> _rejectTimeSuggestion(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
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
        // Recarregar lista para remover o agendamento cancelado
        await _loadBookings(forceRefresh: true);
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

  @override
  void dispose() {
    _pendingSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Ajuste 3: Filtra agendamentos pendentes por workshop, serviço ou observação (like)
  List<Map<String, dynamic>> _filterPendingBySearch(List<Map<String, dynamic>> list) {
    if (_pendingSearchQuery.trim().isEmpty) return list;
    final q = _pendingSearchQuery.trim().toLowerCase();
    return list.where((b) {
      final workshop = (b['workshop_name'] ?? b['workshop']?['name'] ?? '').toString().toLowerCase();
      final service = (b['service_name'] ?? b['service']?['name'] ?? b['product_name'] ?? '').toString().toLowerCase();
      final notes = (b['customer_notes'] ?? b['observations'] ?? b['notes'] ?? '').toString().toLowerCase();
      final vehicle = '${b['vehicle_brand'] ?? ''} ${b['vehicle_model'] ?? ''}'.toLowerCase();
      return workshop.contains(q) || service.contains(q) || notes.contains(q) || vehicle.contains(q);
    }).toList();
  }
}

class _SimpleTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isDarkMode;

  _SimpleTabBarDelegate(this.tabBar, {required this.isDarkMode});

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0A0A0A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: tabBar,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    if (oldDelegate is! _SimpleTabBarDelegate) return true;
    return oldDelegate.isDarkMode != isDarkMode;
  }
}
