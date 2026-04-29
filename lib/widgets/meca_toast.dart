import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _SnackType { success, error, warning, info }

class MecaToast {
  static void show(BuildContext context, String message, {String? title}) {
    _display(context, message, title: title, type: _SnackType.error);
  }

  static void showSuccess(BuildContext context, String message, {String? title}) {
    _display(context, message, title: title, type: _SnackType.success);
  }

  static void showWarning(BuildContext context, String message, {String? title}) {
    _display(context, message, title: title, type: _SnackType.warning);
  }

  static void showInfo(BuildContext context, String message, {String? title}) {
    _display(context, message, title: title, type: _SnackType.info);
  }

  static void _display(BuildContext context, String message, {String? title, required _SnackType type}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastWidget(
        message: message,
        title: title,
        type: type,
        onDismiss: () {
          try { entry.remove(); } catch (_) {}
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final String? title;
  final _SnackType type;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    this.title,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
    );
    HapticFeedback.lightImpact();
    _anim.forward();
    Future.delayed(Duration(seconds: widget.type == _SnackType.error ? 4 : 3), _dismiss);
  }

  void _dismiss() {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _anim.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final accent = _accent(widget.type);

    return Positioned(
      top: top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -2),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(
          opacity: _anim,
          child: GestureDetector(
            onTap: _dismiss,
            onVerticalDragEnd: (d) {
              if (d.velocity.pixelsPerSecond.dy < -50) _dismiss();
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.25),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 64,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_icon(widget.type), color: accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title ?? _title(widget.type),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  height: 1.2,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.message,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 13,
                                  height: 1.3,
                                  fontWeight: FontWeight.w400,
                                  decoration: TextDecoration.none,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _accent(_SnackType t) {
    switch (t) {
      case _SnackType.success: return const Color(0xFF00C977);
      case _SnackType.error:   return const Color(0xFFFF4D4F);
      case _SnackType.warning: return const Color(0xFFFFAB00);
      case _SnackType.info:    return const Color(0xFF448AFF);
    }
  }

  static IconData _icon(_SnackType t) {
    switch (t) {
      case _SnackType.success: return Icons.check_circle_rounded;
      case _SnackType.error:   return Icons.cancel_rounded;
      case _SnackType.warning: return Icons.warning_rounded;
      case _SnackType.info:    return Icons.info_rounded;
    }
  }

  static String _title(_SnackType t) {
    switch (t) {
      case _SnackType.success: return 'Sucesso';
      case _SnackType.error:   return 'Erro';
      case _SnackType.warning: return 'Atenção';
      case _SnackType.info:    return 'Informação';
    }
  }
}
