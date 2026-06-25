import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingTimelineWidget extends StatelessWidget {
  final List<Map<String, dynamic>> events;

  const BookingTimelineWidget({Key? key, required this.events}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(events.length, (index) {
        final event = events[index];
        final isCompleted = event['completed'] == true;
        final isCurrent = event['current'] == true;
        final isLast = index == events.length - 1;
        final label = (event['label'] ?? event['status'] ?? '').toString();
        final timestampRaw = event['timestamp'] ?? event['created_at'];
        final description = event['description']?.toString();
        final icon = _getEventIcon(event['status']?.toString() ?? '');

        String? formattedTime;
        if (timestampRaw != null) {
          try {
            final dt = DateTime.parse(timestampRaw.toString());
            formattedTime = DateFormat('dd/MM/yyyy HH:mm').format(dt);
          } catch (_) {
            formattedTime = timestampRaw.toString();
          }
        }

        return _buildTimelineItem(
          context: context,
          label: label,
          formattedTime: formattedTime,
          description: description,
          icon: icon,
          isCompleted: isCompleted,
          isCurrent: isCurrent,
          isLast: isLast,
          isDark: isDark,
        );
      }),
    );
  }

  Widget _buildTimelineItem({
    required BuildContext context,
    required String label,
    String? formattedTime,
    String? description,
    required IconData icon,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
    required bool isDark,
  }) {
    final Color dotColor;
    final Color lineColor;
    final Color textColor;

    if (isCompleted || isCurrent) {
      dotColor = const Color(0xFF00C977);
      lineColor = const Color(0xFF00C977);
      textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    } else {
      dotColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;
      lineColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
      textColor = isDark ? Colors.grey[500]! : Colors.grey[500]!;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column (dot + line)
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Dot
                Container(
                  width: isCurrent ? 22 : 18,
                  height: isCurrent ? 22 : 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isCompleted || isCurrent)
                        ? dotColor
                        : Colors.transparent,
                    border: Border.all(
                      color: dotColor,
                      width: 2,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: dotColor.withOpacity(0.3),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: (isCompleted || isCurrent)
                      ? Icon(
                          isCompleted ? Icons.check : icon,
                          size: isCurrent ? 12 : 10,
                          color: Colors.white,
                        )
                      : null,
                ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: lineColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isCurrent ? 15 : 14,
                      fontWeight: (isCompleted || isCurrent) ? FontWeight.w600 : FontWeight.w400,
                      color: textColor,
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                  if (formattedTime != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      formattedTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getEventIcon(String status) {
    final s = status.toLowerCase();
    if (s.contains('pendente') || s.contains('pending')) return Icons.schedule;
    if (s.contains('confirmado') || s.contains('confirmed') || s.contains('aceito') || s.contains('accepted')) return Icons.check_circle_outline;
    if (s.contains('checkin') || s.contains('check_in')) return Icons.login;
    if (s.contains('andamento') || s.contains('progress') || s.contains('iniciado') || s.contains('started')) return Icons.build;
    if (s.contains('orcamento') || s.contains('quote')) return Icons.receipt_long;
    if (s.contains('finalizado') || s.contains('completed') || s.contains('concluido')) return Icons.done_all;
    if (s.contains('pagamento') || s.contains('payment') || s.contains('pago') || s.contains('paid')) return Icons.payments;
    if (s.contains('cancelado') || s.contains('cancelled')) return Icons.cancel;
    return Icons.circle;
  }
}
