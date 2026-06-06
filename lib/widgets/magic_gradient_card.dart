import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

class MagicGradientCard extends StatelessWidget {
  const MagicGradientCard({
    super.key,
    required this.child,
    this.colors = AppColors.teaGradient,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
  });

  final Widget child;
  final List<Color> colors;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: AppShadows.glow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                const Positioned.fill(child: _MagicCardPattern()),
                Padding(
                  padding: padding,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MagicCardPattern extends StatelessWidget {
  const _MagicCardPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MagicCardPainter());
  }
}

class _MagicCardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.32);

    final starPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = AppColors.deepPurple.withValues(alpha: 0.16);

    final pagePath = Path()
      ..moveTo(size.width * 0.66, size.height * 0.18)
      ..quadraticBezierTo(
        size.width * 0.8,
        size.height * 0.08,
        size.width * 0.98,
        size.height * 0.22,
      )
      ..moveTo(size.width * 0.7, size.height * 0.3)
      ..quadraticBezierTo(
        size.width * 0.84,
        size.height * 0.18,
        size.width,
        size.height * 0.34,
      );
    canvas.drawPath(pagePath, linePaint);

    final ringCenter = Offset(size.width * 0.92, size.height * 0.82);
    for (var index = 0; index < 3; index++) {
      canvas.drawCircle(ringCenter, 22 + index * 14, linePaint);
    }

    final sparkles = [
      Offset(size.width * 0.18, size.height * 0.24),
      Offset(size.width * 0.84, size.height * 0.18),
      Offset(size.width * 0.58, size.height * 0.78),
    ];
    for (final point in sparkles) {
      canvas.drawLine(point.translate(-4, 0), point.translate(4, 0), starPaint);
      canvas.drawLine(point.translate(0, -4), point.translate(0, 4), starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
