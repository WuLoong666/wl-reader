import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppShadows {
  const AppShadows._();

  static const soft = [
    BoxShadow(
      color: Color(0x1C3F2A56),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  static const glow = [
    BoxShadow(
      color: Color(0x34FFA8C8),
      blurRadius: 22,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x22C58B45),
      blurRadius: 18,
      offset: Offset(0, 4),
    ),
  ];

  static BoxShadow coverGlow({double opacity = 0.24}) {
    return BoxShadow(
      color: AppColors.deepPurple.withValues(alpha: opacity),
      blurRadius: 18,
      offset: const Offset(0, 10),
    );
  }
}
