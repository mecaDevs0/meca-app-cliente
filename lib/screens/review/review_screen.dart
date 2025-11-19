import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/app_alerts.dart';

class ReviewScreen extends StatefulWidget {
  final String bookingId;
  final String workshopId;

  const ReviewScreen({
    super.key,
    required this.bookingId,
    required this.workshopId,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final ApiService _apiService = ApiService();
  int _rating = 5;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

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
      );

      if (result['success']) {
        await AppAlerts.showSuccess(
          context,
          message: 'Avaliação enviada com sucesso! Obrigado por compartilhar sua experiência.',
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
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
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? theme.colorScheme.surface : theme.colorScheme.background;
    final cardColor = isDark
        ? theme.colorScheme.surfaceVariant.withOpacity(0.55)
        : theme.colorScheme.surfaceVariant.withOpacity(0.92);
    final borderColor = theme.dividerColor.withOpacity(isDark ? 0.5 : 0.25);
    final primaryTextColor = theme.colorScheme.onSurface;
    final titleColor = theme.colorScheme.primary;
    final starActiveColor = theme.colorScheme.secondary;
    final starInactiveColor = theme.colorScheme.onSurface.withOpacity(isDark ? 0.4 : 0.2);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary,
        foregroundColor: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary,
        title: const Text('Avaliar Serviço'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Como foi sua experiência?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 48,
                    color: index < _rating ? starActiveColor : starInactiveColor,
                  ),
                  onPressed: () {
                    setState(() => _rating = index + 1);
                  },
                );
              }),
            ),
            const SizedBox(height: 30),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(isDark ? 0.12 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _commentController,
                maxLines: 5,
                style: theme.textTheme.bodyMedium?.copyWith(color: primaryTextColor),
                decoration: InputDecoration(
                  hintText: 'Deixe um comentário (opcional)',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(isDark ? 0.5 : 0.4),
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                        'Enviar Avaliação',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

