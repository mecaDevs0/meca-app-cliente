import 'package:flutter/material.dart';

class AppDashedLinePainter extends CustomPainter {
  AppDashedLinePainter({
    required this.color,
    this.dashWidth = 5,
    this.dashSpace = 5,
    this.thickness = 2,
    this.isVertical = false,
  });

  final Color color;
  final double dashWidth;
  final double dashSpace;
  final double thickness;
  final bool isVertical;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;

    double start = 0;
    if (isVertical) {
      while (start < size.height) {
        canvas.drawLine(
          Offset(0, start),
          Offset(0, start + dashWidth),
          paint,
        );
        start += dashWidth + dashSpace;
      }
    } else {
      while (start < size.width) {
        canvas.drawLine(
          Offset(start, 0),
          Offset(start + dashWidth, 0),
          paint,
        );
        start += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
