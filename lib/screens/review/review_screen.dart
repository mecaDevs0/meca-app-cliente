import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/appsflyer_service.dart';
import '../../widgets/app_alerts.dart';

class ReviewScreen extends StatefulWidget {
  final String bookingId;
  final String workshopId;
  final bool fromPayment;

  const ReviewScreen({
    super.key,
    required this.bookingId,
    required this.workshopId,
    this.fromPayment = false,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final ApiService _apiService = ApiService();
  int _rating = 5;
  int _qualityRating = 0;
  int _priceRating = 0;
  int _timeRating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  String _ratingLabel(int value) {
    switch (value) {
      case 1:
        return 'Muito ruim';
      case 2:
        return 'Ruim';
      case 3:
        return 'Ok';
      case 4:
        return 'Boa';
      case 5:
      default:
        return 'Excelente';
    }
  }

  Color _ratingColor(ThemeData theme, int value) {
    if (value <= 2) return const Color(0xFFE53935);
    if (value == 3) return const Color(0xFFF9A825);
    return theme.colorScheme.primary;
  }

  /// R2: Show referral card after successful review (post-payment flow).
  Future<void> _showReferralCard() async {
    if (!widget.fromPayment) return;

    try {
      final result = await _apiService.get('/customer/referral');
      if (result['success'] != true) return;
      final code = result['data']?['referral_code'] ?? '';
      if (code.isEmpty || !mounted) return;

      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Icon(Icons.card_giftcard_rounded, size: 48, color: const Color(0xFF00C977)),
                const SizedBox(height: 16),
                Text(
                  'Gostou do serviço?',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Indique um amigo e ganhe 10% OFF!\nSeu amigo também ganha 5% no 1º serviço.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Share.share(
                        'Agende serviços automotivos pelo MECA! Use meu código $code no cadastro e ganhe 5% OFF no 1º serviço. Baixe: https://meca.onelink.me/ARwB',
                      );
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    label: const Text('Compartilhar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C977),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Agora não', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('[Referral] Post-payment card error: $e');
    }
  }

  /// V1-V4: After a 4-5★ review with 1+ paid booking, prompt native store review.
  /// Rate limited to once per 90 days via SharedPreferences.
  Future<void> _maybeRequestStoreReview() async {
    if (_rating < 4) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRequest = prefs.getInt('store_review_last_request') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      const ninetyDaysMs = 90 * 24 * 60 * 60 * 1000;

      if (lastRequest > 0 && (now - lastRequest) < ninetyDaysMs) return;

      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await prefs.setInt('store_review_last_request', now);
        await Future.delayed(const Duration(seconds: 1));
        await inAppReview.requestReview();
      }
    } catch (e) {
      debugPrint('[InAppReview] Error: $e');
    }
  }

  Future<void> _submitRating() async {
    if (_rating < 1 || _rating > 5) {
      await AppAlerts.showWarning(
        context,
        message: 'Escolha uma nota de 1 a 5 para enviar sua avaliação.',
        title: 'Nota obrigatória',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await _apiService.submitRating(
        bookingId: widget.bookingId,
        workshopId: widget.workshopId,
        rating: _rating,
        comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
        qualityRating: _qualityRating > 0 ? _qualityRating : null,
        priceRating: _priceRating > 0 ? _priceRating : null,
        timeRating: _timeRating > 0 ? _timeRating : null,
      );

      if (result['success']) {
        AppsFlyerService.instance.logRating(widget.bookingId, _rating);
        _apiService.invalidateBookingCache(widget.bookingId);
        _apiService.invalidateBookingsCache();

        // V1-V4: Trigger native store review for 4-5★ ratings
        await _maybeRequestStoreReview();

        if (!mounted) return;
        await AppAlerts.showSuccess(
          context,
          message: result['reward'] != null
              ? 'Avaliação enviada! Você ganhou ${result['reward']['percent'] ?? 5}% de desconto 🎉'
              : 'Avaliação enviada com sucesso! Obrigado por compartilhar sua experiência.',
        );
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;

        // R2: Show referral card after review in post-payment flow
        await _showReferralCard();
        if (!mounted) return;

        if (widget.fromPayment) {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        } else {
          Navigator.of(context).pop(true);
        }
      } else {
        await AppAlerts.showError(
          context,
          message: result['error'] != null
              ? 'Erro ao enviar avaliação: ${result['error']}'
              : 'Não foi possível enviar sua avaliação agora. Tente novamente.',
        );
      }
    } catch (e) {
      await AppAlerts.showError(
        context,
        message: 'Não foi possível enviar sua avaliação agora. Tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Widget _buildDimensionRow({
    required ThemeData theme,
    required String label,
    required IconData icon,
    required int value,
    required ValueChanged<int> onChanged,
    required Color starInactiveColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.85),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              final selected = starValue <= value;
              return GestureDetector(
                onTap: () => onChanged(starValue == value ? 0 : starValue),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    selected ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 28,
                    color: selected
                        ? _ratingColor(theme, value)
                        : starInactiveColor,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? theme.colorScheme.surface : theme.colorScheme.background;
    final cardColor = isDark
        ? theme.colorScheme.surfaceVariant.withOpacity(0.50)
        : theme.colorScheme.surfaceVariant.withOpacity(0.92);
    final borderColor = theme.dividerColor.withOpacity(isDark ? 0.35 : 0.18);
    final titleColor = theme.colorScheme.primary;
    final starInactiveColor = theme.colorScheme.onSurface.withOpacity(isDark ? 0.35 : 0.18);
    final ratingColor = _ratingColor(theme, _rating);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary,
        foregroundColor: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary,
        title: const Text('Avaliar Serviço'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card 1: Nota geral
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(isDark ? 0.10 : 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(isDark ? 0.18 : 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.rate_review_rounded, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Como foi sua experiência?',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sua avaliação ajuda outras pessoas e melhora a qualidade do serviço.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.72),
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Column(
                        children: [
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            children: List.generate(5, (index) {
                              final value = index + 1;
                              final selected = value <= _rating;
                              return InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => setState(() => _rating = value),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    selected ? Icons.star_rounded : Icons.star_border_rounded,
                                    size: 44,
                                    color: selected ? ratingColor : starInactiveColor,
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: ratingColor.withOpacity(isDark ? 0.16 : 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _ratingLabel(_rating),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: ratingColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Card 2: Dimensões (opcional)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(isDark ? 0.10 : 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Avalie em detalhes',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'opcional',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDimensionRow(
                      theme: theme,
                      label: 'Qualidade do serviço',
                      icon: Icons.build_rounded,
                      value: _qualityRating,
                      onChanged: (v) => setState(() => _qualityRating = v),
                      starInactiveColor: starInactiveColor,
                    ),
                    Divider(color: borderColor, height: 1),
                    _buildDimensionRow(
                      theme: theme,
                      label: 'Custo-benefício',
                      icon: Icons.payments_rounded,
                      value: _priceRating,
                      onChanged: (v) => setState(() => _priceRating = v),
                      starInactiveColor: starInactiveColor,
                    ),
                    Divider(color: borderColor, height: 1),
                    _buildDimensionRow(
                      theme: theme,
                      label: 'Pontualidade',
                      icon: Icons.schedule_rounded,
                      value: _timeRating,
                      onChanged: (v) => setState(() => _timeRating = v),
                      starInactiveColor: starInactiveColor,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Card 3: Comentário
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(isDark ? 0.10 : 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comentário (opcional)',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _commentController,
                      maxLines: 4,
                      maxLength: 500,
                      textInputAction: TextInputAction.done,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Conte como foi o atendimento, a qualidade do serviço, pontualidade...',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.background.withOpacity(isDark ? 0.10 : 0.55),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.6), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Botão enviar
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRating,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: theme.colorScheme.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Enviar avaliação',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
