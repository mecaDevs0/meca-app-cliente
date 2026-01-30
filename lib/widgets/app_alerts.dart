import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';

enum _AlertType { success, error, info, warning }

class AppAlerts {
  static Flushbar<dynamic>? _currentFlushbar;

  static Future<void> showSuccess(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    return _show(
      context,
      message: message,
      title: title ?? 'Tudo certo!',
      type: _AlertType.success,
      duration: duration,
    );
  }

  static Future<void> showError(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 6),
  }) {
    return _show(
      context,
      message: message,
      title: title ?? 'Ops, algo não saiu como esperado',
      type: _AlertType.error,
      duration: duration,
    );
  }

  static Future<void> showInfo(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 5),
  }) {
    return _show(
      context,
      message: message,
      title: title ?? 'Informação',
      type: _AlertType.info,
      duration: duration,
    );
  }

  static Future<void> showWarning(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 5),
  }) {
    return _show(
      context,
      message: message,
      title: title ?? 'Atenção',
      type: _AlertType.warning,
      duration: duration,
    );
  }

  static Future<void> _show(
    BuildContext context, {
    required String message,
    required String title,
    required _AlertType type,
    required Duration duration,
  }) async {
    // Verificar se o context está montado antes de usar Theme.of
    if (!context.mounted) {
      return;
    }
    
    final theme = Theme.of(context);
    final colors = _colorsForType(type, theme);
    final icon = _iconForType(type);

    final previousFlushbar = _currentFlushbar;
    if (previousFlushbar != null) {
      _currentFlushbar = null;
      try {
        await previousFlushbar.dismiss();
      } catch (_) {
        // Se o flushbar anterior já estiver fechado, seguimos sem interromper o fluxo.
      }
    }

    // Verificar novamente após dismiss (pode ter demorado)
    if (!context.mounted) {
      return;
    }

    final flushbar = Flushbar<dynamic>(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderRadius: BorderRadius.circular(18),
      duration: duration,
      backgroundGradient: LinearGradient(colors: colors.backgroundGradient),
      boxShadows: [
        BoxShadow(
          color: colors.shadowColor,
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
      titleText: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      messageText: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white.withOpacity(0.9),
          height: 1.3,
        ),
      ),
      icon: Container(
        decoration: BoxDecoration(
          color: colors.iconBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
      leftBarIndicatorColor: colors.indicatorColor,
      flushbarStyle: FlushbarStyle.FLOATING,
      flushbarPosition: FlushbarPosition.TOP,
    );

    _currentFlushbar = flushbar;
    await flushbar.show(context);
    if (identical(_currentFlushbar, flushbar)) {
      _currentFlushbar = null;
    }
  }

  static _AlertVisualConfig _colorsForType(_AlertType type, ThemeData theme) {
    switch (type) {
      case _AlertType.success:
        return _AlertVisualConfig(
          backgroundGradient: const [
            Color(0xFF34C759),
            Color(0xFF0BA360),
          ],
          iconBackground: const Color(0xFF2ECC71),
          indicatorColor: const Color(0xFFB2FF59),
          shadowColor: const Color(0x5534C759),
        );
      case _AlertType.error:
        return _AlertVisualConfig(
          backgroundGradient: const [
            Color(0xFFD91E3E),
            Color(0xFFB31237),
          ],
          iconBackground: const Color(0xFFF05454),
          indicatorColor: const Color(0xFFFF8A80),
          shadowColor: const Color(0x55FF1744),
        );
      case _AlertType.warning:
        return _AlertVisualConfig(
          backgroundGradient: const [
            Color(0xFFFFB300),
            Color(0xFFFF8F00),
          ],
          iconBackground: const Color(0xFFFFC048),
          indicatorColor: const Color(0xFFFFE082),
          shadowColor: const Color(0x55FFA000),
        );
      case _AlertType.info:
        final isDark = theme.brightness == Brightness.dark;
        return _AlertVisualConfig(
          backgroundGradient: isDark
              ? const [Color(0xFF374151), Color(0xFF1F2937)]
              : const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          iconBackground: isDark ? const Color(0xFF4B5563) : const Color(0xFF3B82F6),
          indicatorColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFFBFDBFE),
          shadowColor: const Color(0x552563EB),
        );
    }
  }

  static IconData _iconForType(_AlertType type) {
    switch (type) {
      case _AlertType.success:
        return Icons.check_rounded;
      case _AlertType.error:
        return Icons.error_outline_rounded;
      case _AlertType.warning:
        return Icons.warning_amber_rounded;
      case _AlertType.info:
        return Icons.info_rounded;
    }
  }
}

class _AlertVisualConfig {
  const _AlertVisualConfig({
    required this.backgroundGradient,
    required this.iconBackground,
    required this.indicatorColor,
    required this.shadowColor,
  });

  final List<Color> backgroundGradient;
  final Color iconBackground;
  final Color indicatorColor;
  final Color shadowColor;
}

