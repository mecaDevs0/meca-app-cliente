import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../widgets/meca_toast.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../utils/formatters.dart';
import '../payment/meca_payment_screen.dart';

const _kGreen = Color(0xFF00C977);

class PreCompraDetailScreen extends StatefulWidget {
  final String preCompraId;

  const PreCompraDetailScreen({Key? key, required this.preCompraId}) : super(key: key);

  @override
  State<PreCompraDetailScreen> createState() => _PreCompraDetailScreenState();
}

class _PreCompraDetailScreenState extends State<PreCompraDetailScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _item;
  bool _loading = true;
  String _error = '';
  bool _canceling = false;
  bool _downloadingPdf = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool skipCache = false}) async {
    setState(() { _loading = true; _error = ''; });
    try {
      final result = await _api.get('/pre-compra/${widget.preCompraId}', skipCache: skipCache);
      if (result['success'] == true) {
        setState(() { _item = Map<String, dynamic>.from(result['data'] ?? {}); _loading = false; });
      } else {
        setState(() { _error = result['error'] ?? 'Erro ao carregar'; _loading = false; });
      }
    } catch (_) {
      setState(() { _error = 'Erro de conexão.'; _loading = false; });
    }
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Pré-Compra'),
        content: const Text('Deseja realmente cancelar esta inspeção?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _canceling = true);
    try {
      final result = await _api.put('/pre-compra/${widget.preCompraId}/cancel', {});
      if (result['success'] == true) {
        _showSnack('Pré-Compra cancelada');
        _load(skipCache: true);
      } else {
        _showSnack(result['error'] ?? 'Erro ao cancelar', isError: true);
      }
    } catch (_) {
      _showSnack('Erro de conexão', isError: true);
    } finally {
      if (mounted) setState(() => _canceling = false);
    }
  }

  Future<void> _goToPay() async {
    final item = _item;
    if (item == null) return;

    final priceRaw = item['price'];
    final double totalAmount = (priceRaw != null)
        ? (double.tryParse(priceRaw.toString()) ?? 0.0)
        : 0.0;

    if (totalAmount <= 0) {
      _showSnack('Valor da inspeção não definido pela oficina.', isError: true);
      return;
    }

    final oficina_id = item['oficina_id']?.toString() ?? '';
    final workshopName = item['workshop_name']?.toString() ?? 'Oficina';
    final mecaFee = totalAmount * 0.12;

    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MecaPaymentScreen(
          bookingData: {
            'id': widget.preCompraId,
            'oficina_id': oficina_id,
            'workshop_id': oficina_id,
            'workshop_name': workshopName,
          },
          totalAmount: totalAmount,
          mecaFee: mecaFee,
          serviceAmount: totalAmount - mecaFee,
          installments: 1,
          workshopAcceptsInstallment: true,
          workshopMaxInstallments: 12,
          isPreCompra: true,
        ),
      ),
    );

    if (paid == true && mounted) {
      _load(skipCache: true);
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _downloadingPdf = true);
    try {
      final result = await _api.get('/pre-compra/${widget.preCompraId}/pdf', skipCache: true);
      if (result['success'] == true) {
        final url = result['data']?['pdf_url']?.toString();
        if (url != null && url.isNotEmpty) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            _showSnack('Não foi possível abrir o PDF', isError: true);
          }
        }
      } else if (result['payment_required'] == true || result['error']?.toString().contains('pagamento') == true) {
        _showSnack('PDF disponível apenas após pagamento da inspeção', isError: true);
      } else {
        _showSnack(result['error'] ?? 'Erro ao baixar PDF', isError: true);
      }
    } catch (_) {
      _showSnack('Erro de conexão', isError: true);
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      MecaToast.show(context, msg);
    } else {
      MecaToast.showSuccess(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(builder: (context, theme, _) {
      final isDark = theme.isDarkMode;
      final bg = isDark ? const Color(0xFF0A0A0A) : Colors.grey[50]!;
      final card = isDark ? const Color(0xFF1A1A1A) : Colors.white;
      final text = isDark ? Colors.white : Colors.black87;
      final sub = isDark ? Colors.white60 : Colors.black54;

      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: const Text('Detalhe Pré-Compra', style: TextStyle(color: _kGreen, fontWeight: FontWeight.bold)),
          backgroundColor: card,
          elevation: 0,
          iconTheme: const IconThemeData(color: _kGreen),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: _kGreen),
              onPressed: () => _load(skipCache: true),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _kGreen))
            : _error.isNotEmpty
                ? _buildError()
                : _buildContent(isDark, card, text, sub),
      );
    });
  }

  Widget _buildContent(bool isDark, Color card, Color text, Color sub) {
    final item = _item!;
    final status = item['status']?.toString() ?? 'pendente';
    final brand = item['vehicle_brand']?.toString() ?? '';
    final model = item['vehicle_model']?.toString() ?? '';
    final year = item['vehicle_year']?.toString() ?? '';
    final plate = item['vehicle_plate']?.toString() ?? '';
    final color = item['vehicle_color']?.toString() ?? '';
    final km = item['vehicle_km']?.toString() ?? '';
    final workshopName = item['workshop_name']?.toString() ?? '';
    final workshopPhone = item['workshop_phone']?.toString() ?? '';
    final workshopAddress = item['workshop_address']?.toString() ?? '';
    final notes = item['notes']?.toString() ?? '';
    final observacoes = item['observacoes']?.toString() ?? '';
    final resultado = item['resultado']?.toString() ?? '';
    final price = item['price'];
    final estimatedPrice = item['estimated_price'];
    final hasPdf = item['laudo_pdf_key'] != null;
    final isPaid = item['payment_status'] == 'pago';
    final paymentStatus = item['payment_status']?.toString() ?? 'pendente';
    final dateStr = item['appointment_date']?.toString();
    final laudo = item['laudo'];

    String formattedDate = '';
    if (dateStr != null) {
      try { formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(dateStr).toLocal()); } catch (_) {}
    }

    // Backward compat: dado legado pode ter status='concluido' mas payment_status!='pago'
    final effectiveStatus = (status == 'concluido' && !isPaid) ? 'aguardando_pagamento' : status;
    final canCancel = ['pendente', 'confirmado', 'aguardando_pagamento'].contains(effectiveStatus);
    final isAguardandoPagamento = effectiveStatus == 'aguardando_pagamento';
    final isConcluido = effectiveStatus == 'concluido'; // concluido agora sempre significa pago

    return RefreshIndicator(
      color: _kGreen,
      onRefresh: () => _load(skipCache: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Banner (usar effectiveStatus para backward compat)
          _buildStatusBanner(effectiveStatus, isDark),
          const SizedBox(height: 16),

          // Veículo
          _section('Veículo Inspecionado', card, isDark, [
            _row(Icons.directions_car, 'Veículo', '$brand $model${year.isNotEmpty ? ' ($year)' : ''}', text, sub),
            if (plate.isNotEmpty) _row(Icons.badge, 'Placa', plate, text, sub),
            if (color.isNotEmpty) _row(Icons.color_lens, 'Cor', color, text, sub),
            if (km.isNotEmpty) _row(Icons.speed, 'Quilometragem', '${km} km', text, sub),
          ]),
          const SizedBox(height: 12),

          // Oficina
          _section('Oficina', card, isDark, [
            _row(Icons.store, 'Nome', workshopName, text, sub),
            if (workshopPhone.isNotEmpty) _row(Icons.phone, 'Telefone', Formatters.formatPhone(workshopPhone), text, sub),
            if (workshopAddress.isNotEmpty) _row(Icons.location_on, 'Endereço', workshopAddress, text, sub),
            if (formattedDate.isNotEmpty) _row(Icons.calendar_today, 'Agendado para', formattedDate, text, sub),
          ]),
          const SizedBox(height: 12),

          // Pagamento
          if (isConcluido || price != null || estimatedPrice != null)
            _section('Pagamento', card, isDark, [
              if (estimatedPrice != null) _row(Icons.attach_money, 'Preço estimado', 'R\$ ${double.tryParse(estimatedPrice.toString())?.toStringAsFixed(2) ?? estimatedPrice}', text, sub),
              if (price != null) _row(Icons.attach_money, 'Valor cobrado', 'R\$ ${double.tryParse(price.toString())?.toStringAsFixed(2) ?? price}', text, sub),
              _row(Icons.payment, 'Status pagamento', _paymentStatusLabel(paymentStatus), text, sub),
              // CTA de pagamento quando laudo enviado e ainda não pago
              if (isAguardandoPagamento && !isPaid && price != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _goToPay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.payment),
                    label: const Text('Realizar Pagamento', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ]),

          if (isAguardandoPagamento || isConcluido || price != null) const SizedBox(height: 12),

          // Resultado da Inspeção
          if ((isAguardandoPagamento || isConcluido) && resultado.isNotEmpty) ...[
            _section('Resultado da Inspeção', card, isDark, [
              _buildResultadoBadge(resultado),
              if (observacoes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Observações:', style: TextStyle(color: sub, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(observacoes, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
              ],
            ]),
            const SizedBox(height: 12),

            // Laudo por categorias
            if (laudo != null && laudo is Map && laudo.isNotEmpty)
              _buildLaudoSection(laudo, card, isDark, text, sub),
            const SizedBox(height: 12),
          ],

          // PDF do Laudo
          if (hasPdf) ...[
            _section('Laudo em PDF', card, isDark, [
              Row(
                children: [
                  Icon(Icons.picture_as_pdf, color: isPaid ? _kGreen : Colors.orange[700], size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPaid ? 'PDF disponível para download' : 'PDF disponível após pagamento',
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500),
                        ),
                        if (!isPaid)
                          Text('Realize o pagamento para acessar o laudo completo em PDF',
                              style: TextStyle(color: sub, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isPaid && !_downloadingPdf
                      ? _downloadPdf
                      : (!isPaid ? _goToPay : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPaid ? _kGreen : Colors.orange[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: _downloadingPdf
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Icon(isPaid ? Icons.download : Icons.payment),
                  label: Text(
                    isPaid ? 'Baixar Laudo PDF' : 'Pagar e Desbloquear PDF',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
          ],

          // Notas
          if (notes.isNotEmpty) ...[
            _section('Suas observações', card, isDark, [
              Text(notes, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
            ]),
            const SizedBox(height: 12),
          ],

          // Ações
          if (canCancel) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _canceling ? null : _cancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _canceling
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2))
                    : const Text('Cancelar Pré-Compra', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(String status, bool isDark) {
    Color color;
    IconData icon;
    String label;
    String description;
    switch (status) {
      case 'confirmado':
        color = Colors.blue; icon = Icons.check_circle_outline; label = 'Confirmado';
        description = 'A oficina confirmou sua inspeção.'; break;
      case 'em_andamento':
        color = Colors.orange; icon = Icons.build; label = 'Em Andamento';
        description = 'O mecânico está inspecionando o veículo.'; break;
      case 'aguardando_pagamento':
        color = Colors.amber.shade700; icon = Icons.hourglass_top_rounded; label = 'Laudo Pronto!';
        description = 'Realize o pagamento para acessar o laudo completo em PDF.'; break;
      case 'concluido':
        color = _kGreen; icon = Icons.verified; label = 'Concluído e Pago';
        description = 'Pagamento confirmado. O PDF do laudo está disponível para download.'; break;
      case 'cancelado':
        color = Colors.red; icon = Icons.cancel; label = 'Cancelado';
        description = 'Esta pré-compra foi cancelada.'; break;
      default:
        color = Colors.grey; icon = Icons.hourglass_empty; label = 'Aguardando Confirmação';
        description = 'A oficina irá confirmar em breve.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(color: color.withOpacity(0.8), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultadoBadge(String resultado) {
    Color color;
    String label;
    IconData icon;
    switch (resultado) {
      case 'aprovado': color = _kGreen; label = 'APROVADO'; icon = Icons.thumb_up; break;
      case 'reprovado': color = Colors.red; label = 'REPROVADO'; icon = Icons.thumb_down; break;
      default: color = Colors.orange; label = 'APROVADO COM RESSALVAS'; icon = Icons.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildLaudoSection(Map laudo, Color card, bool isDark, Color text, Color sub) {
    final categorias = {
      'motor': 'Motor',
      'transmissao': 'Transmissão',
      'suspensao': 'Suspensão',
      'freios': 'Freios',
      'carroceria': 'Carroceria',
      'interior': 'Interior',
      'eletrica': 'Elétrica',
      'pneus': 'Pneus',
      'ar_condicionado': 'Ar Condicionado',
      'revisao_geral': 'Revisão Geral',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Laudo por Categorias', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: text)),
          const SizedBox(height: 12),
          ...categorias.entries.map((e) {
            final catData = laudo[e.key];
            if (catData == null) return const SizedBox.shrink();
            final nota = int.tryParse(catData['nota']?.toString() ?? '0') ?? 0;
            final obs = catData['observacao']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(e.value, style: TextStyle(fontWeight: FontWeight.w600, color: text))),
                      _buildStars(nota),
                    ],
                  ),
                  if (obs.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(obs, style: TextStyle(color: sub, fontSize: 13)),
                  ],
                  const Divider(height: 16),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildStars(int nota) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        Color starColor;
        if (nota >= 4) starColor = _kGreen;
        else if (nota == 3) starColor = Colors.orange;
        else starColor = Colors.red;
        return Icon(
          i < nota ? Icons.star : Icons.star_border,
          size: 16,
          color: i < nota ? starColor : Colors.grey,
        );
      }),
    );
  }

  Widget _section(String title, Color card, bool isDark, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _kGreen)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, Color text, Color sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _kGreen),
          const SizedBox(width: 8),
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: sub, fontSize: 13))),
          Expanded(child: Text(value, style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  String _paymentStatusLabel(String status) {
    switch (status) {
      case 'pago': return 'Pago';
      case 'cancelado': return 'Cancelado';
      default: return 'Pendente';
    }
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
          const SizedBox(height: 12),
          Text(_error, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _load(skipCache: true),
            style: ElevatedButton.styleFrom(backgroundColor: _kGreen, foregroundColor: Colors.white),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
