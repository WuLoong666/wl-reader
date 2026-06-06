import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AnimeBackground extends StatelessWidget {
  const AnimeBackground({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.cream,
      child: CustomPaint(
        painter: _AnimeBackgroundPainter(),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class _AnimeBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final washPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.pageGradient,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, washPaint);

    _drawTeaRipples(canvas, size);
    _drawBookPages(canvas, size);
    _drawSparkles(canvas, size);
    _drawSakuraPetals(canvas, size);
  }

  void _drawTeaRipples(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = AppColors.teaAmber.withValues(alpha: 0.16);

    final anchors = [
      Offset(size.width * 0.08, size.height * 0.14),
      Offset(size.width * 0.88, size.height * 0.24),
      Offset(size.width * 0.18, size.height * 0.78),
    ];

    for (final anchor in anchors) {
      for (var index = 0; index < 3; index++) {
        final radius = 24.0 + index * 18;
        canvas.drawArc(
          Rect.fromCircle(center: anchor, radius: radius),
          math.pi * 0.12,
          math.pi * 1.36,
          false,
          paint,
        );
      }
    }
  }

  void _drawBookPages(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.deepPurple.withValues(alpha: 0.07);

    final path = Path()
      ..moveTo(size.width * 0.62, size.height * 0.08)
      ..quadraticBezierTo(
        size.width * 0.73,
        size.height * 0.03,
        size.width * 0.88,
        size.height * 0.11,
      )
      ..moveTo(size.width * 0.64, size.height * 0.13)
      ..quadraticBezierTo(
        size.width * 0.76,
        size.height * 0.08,
        size.width * 0.9,
        size.height * 0.16,
      );
    canvas.drawPath(path, paint);
  }

  void _drawSparkles(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.3
      ..color = AppColors.star.withValues(alpha: 0.42);

    final points = [
      Offset(size.width * 0.2, size.height * 0.1),
      Offset(size.width * 0.82, size.height * 0.1),
      Offset(size.width * 0.72, size.height * 0.45),
      Offset(size.width * 0.12, size.height * 0.52),
      Offset(size.width * 0.86, size.height * 0.82),
    ];

    for (final point in points) {
      canvas.drawLine(
        point.translate(-4, 0),
        point.translate(4, 0),
        paint,
      );
      canvas.drawLine(
        point.translate(0, -4),
        point.translate(0, 4),
        paint,
      );
    }
  }

  void _drawSakuraPetals(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.sakuraPink.withValues(alpha: 0.18);

    final petals = [
      Offset(size.width * 0.38, size.height * 0.18),
      Offset(size.width * 0.92, size.height * 0.55),
      Offset(size.width * 0.28, size.height * 0.9),
    ];

    for (var index = 0; index < petals.length; index++) {
      final center = petals[index];
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(index * 0.7 + 0.35);
      final path = Path()
        ..moveTo(0, -7)
        ..cubicTo(8, -2, 8, 7, 0, 10)
        ..cubicTo(-8, 7, -8, -2, 0, -7)
        ..close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
