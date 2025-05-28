import 'dart:ui';

import 'package:flutter/material.dart';

class AppDashedBorderPainter extends CustomPainter {
  AppDashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 4.0,
    this.borderRadius = 8.0,
  });
  final Color color;
  final double strokeWidth;
  final double gap;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    final outerRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect =
        RRect.fromRectAndRadius(outerRect, Radius.circular(borderRadius));

    path.addRRect(rrect);

    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const double dashWidth = 5.0;
    final double dashSpace = gap;
    for (final PathMetric pathMetric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        final extractPath =
            pathMetric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
