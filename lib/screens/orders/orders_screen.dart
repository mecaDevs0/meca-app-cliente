
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/notification_provider.dart';
import '../../services/api_service.dart';
import '../../utils/price_utils.dart';
import '../../widgets/app_alerts.dart';
import '../../widgets/meca_loading_widget.dart';
import 'expired_bookings_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        // Recarregar notificações para garantir sincronização
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
    
    final result = await _apiService.getBookings();
    
    if (!mounted) return;
    
    if (result['success']) {
      // IMPORTANTE: Normalizar resposta (pode vir como array direto ou objeto com bookings)
      final data = result['data'];
      List<Map<String, dynamic>> bookings = [];
      if (data is List) {
        bookings = data.cast<Map<String, dynamic>>();
      } else if (data is Map && data['bookings'] != null) {
        bookings = (data['bookings'] as List).cast<Map<String, dynamic>>();
      } else if (data is Map) {
        // Se data for um objeto vazio ou com outras propriedades, tentar extrair bookings
        bookings = [];
      }
      
      // Filtrar por status - mapear corretamente
      bookings = bookings.where((b) {
        final bookingStatus = b['status'] ?? '';
        final suggestedBy = b['suggested_by'] ?? b['sugerido_por'];
        final hasSuggestedDate = b['suggested_date'] != null || b['data_sugerida'] != null;
        // final isTimeSuggestion = (suggestedBy == 'oficina' || suggestedBy == 'workshop') && hasSuggestedDate; // Removido: variável não utilizada
        
        if (_currentStatus == 'pendente_oficina') {
          // IMPORTANTE: A aba "Pendentes" deve mostrar TODOS os agendamentos aguardando ação do cliente:
          // - pendente_oficina: aguardando oficina aceitar
          // - pendente_cliente: aguardando cliente aprovar orçamento OU sugestão de horário
          // O status pendente_cliente significa que está aguardando ação do cliente, independente de ter sugestão de horário ou não
          return bookingStatus == 'pendente_oficina' || 
                 bookingStatus == 'pending' ||
                 bookingStatus == 'pendente_cliente'; // SEMPRE incluir pendente_cliente (orçamento ou sugestão aguardando aprovação)
        } else if (_currentStatus == 'confirmado') {
          // Incluir confirmado, em_andamento, mas NÃO incluir pendente_cliente (fica em pendentes)
          return (bookingStatus == 'confirmado' || 
                 bookingStatus == 'confirmado_oficina' || 
                 bookingStatus == 'confirmed' ||
                 bookingStatus == 'em_andamento' ||
                 bookingStatus == 'in_progress') &&
                 bookingStatus != 'pendente_cliente'; // Excluir pendente_cliente (fica em pendentes)
        } else if (_currentStatus == 'finalizado_cliente') {
          return bookingStatus == 'finalizado_cliente' || 
                 bookingStatus == 'finalizado_aguardando_pagamento' ||
                 bookingStatus == 'pago' ||
                 bookingStatus == 'concluido' || 
                 bookingStatus == 'completed';
        }
        
        return b['status'] == _currentStatus;
      }).toList().cast<Map<String, dynamic>>();
      
      // Ordenar agendamentos pendentes por data mais próxima da atual
      if (_currentStatus == 'pendente_oficina') {
        bookings.sort((a, b) {
          // Tentar ambos os campos possíveis de data
          final dateA = a['appointment_date'] ?? a['scheduled_date'];
          final dateB = b['appointment_date'] ?? b['scheduled_date'];
          
          // Se ambos têm data, ordenar por data crescente (mais próximo primeiro)
          if (dateA != null && dateB != null) {
            try {
              final dateAObj = DateTime.parse(dateA);
              final dateBObj = DateTime.parse(dateB);
              return dateAObj.compareTo(dateBObj);
            } catch (e) {
              // Se houver erro ao parsear, manter ordem original
              return 0;
            }
          }
          
          // Se apenas A tem data, A vem primeiro
          if (dateA != null && dateB == null) return -1;
          
          // Se apenas B tem data, B vem primeiro
          if (dateA == null && dateB != null) return 1;
          
          // Se nenhum tem data, manter ordem original
          return 0;
        });
      }
      
      // Carregar dados dos veículos
      await _loadVehicleData(bookings);
      
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _loading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _loading = false);
      }
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
      for (final booking in _bookings) {
        if (_isBookingExpired(booking, today)) {
          pendingExpired.add(booking);
        } else {
          pendingUpcoming.add(booking);
        }
      }
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
                                ? pendingUpcoming.length + (hasExpiredSection ? 1 : 0)
                                : _bookings.length,
                            itemBuilder: (context, index) {
                              if (!isPendingTab) {
                                final booking = _bookings[index];
                                return _buildBookingCard(booking);
                              }

                              if (index < pendingUpcoming.length) {
                                return _buildBookingCard(pendingUpcoming[index]);
                              }

                              if (hasExpiredSection && index == pendingUpcoming.length) {
                                return _buildExpiredDivider(pendingExpired.length, pendingExpired);
                              }

                              // Agendamentos expirados não aparecem mais aqui, apenas na tela dedicada
                              return const SizedBox.shrink();
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, {bool isExpired = false}) {
    final status = booking['status'] ?? 'pending';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final statusConfig = _getStatusConfig(status, isDarkMode: isDarkMode);
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
                
                // Seção de contato WhatsApp - APENAS quando status = em_andamento
                Builder(
                  builder: (context) {
                    final normalizedStatus = status.toString().toLowerCase();
                    final isInProgress = normalizedStatus == 'em_andamento' || normalizedStatus == 'in_progress';
                    
                    if (!isInProgress) return const SizedBox.shrink();
                    
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
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Número copiado!'),
                                          backgroundColor: const Color(0xFF25D366),
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
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
        // Notificações de pendentes: quando oficina sugere horário, confirma, etc
        if (title.contains('pendente') || 
            title.contains('sugestão') || 
            title.contains('horário') ||
            message.contains('pendente') ||
            message.contains('sugestão') ||
            bookingStatus.contains('pendente')) {
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
        // Notificações de concluídos: quando serviço é finalizado
        if (title.contains('finalizado') || 
            title.contains('concluído') ||
            title.contains('concluido') ||
            message.contains('finalizado') ||
            message.contains('concluído') ||
            message.contains('concluido') ||
            bookingStatus.contains('finalizado') ||
            bookingStatus.contains('completed')) {
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
    _tabController.dispose();
    super.dispose();
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
