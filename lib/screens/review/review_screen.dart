import 'package:flutter/material.dart';
import '../../services/api_service.dart';
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
        _apiService.invalidateBookingCache(widget.bookingId);
        _apiService.invalidateBookingsCache();
        await AppAlerts.showSuccess(
          context,
          message: 'Avaliação enviada com sucesso! Obrigado por compartilhar sua experiência.',
        );
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 400));
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
