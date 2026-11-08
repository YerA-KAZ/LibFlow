import 'package:flutter/material.dart';

class AppColors {
  // LibFlow ink and paper palette
  static const Color primary = Color(0xFF343B70);
  static const Color primaryDark = Color(0xFF212541);
  static const Color primaryLight = Color(0xFF575E92);
  static const Color accent = Color(0xFFE1B384); // Warm Sand / Gold Accent
  static const Color accentLight = Color(0xFFFAEDCD);
  static const Color badgeGreen = Color(0xFF2D6A4F);

  // Status Colors
  static const Color success = Color(0xFF2D6A4F);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // Neutral Colors (Light - Warm Paper / Cream)
  static const Color backgroundLight = Color(0xFFF7F3EA); // Warm Cream Paper
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF19201D); // Deep Charcoal
  static const Color textSecondaryLight = Color(0xFF6B7280); // Muted Slate
  static const Color borderLight = Color(0xFFEBE6DC); // Gentle Warm Border
  static const Color inputBackground = Color(
    0xFFF4EFE6,
  ); // Soft Warm Input Field

  // Neutral Colors (Dark)
  static const Color backgroundDark = Color(0xFF171923);
  static const Color surfaceDark = Color(0xFF222532);
  static const Color cardDark = Color(0xFF292C39);
  static const Color textPrimaryDark = Color(0xFFF3F4F6);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color borderDark = Color(0xFF3A3F52);
}

class AppConstants {
  static const String appName = 'LibFlow';
  static const String appTagline = 'Кітапты табу, брондау және алу';

  static const List<String> categories = [
    'Барлығы',
    'Көркем әдебиет',
    'Оқулықтар',
    'IT және Технология',
    'Тарих және Тұлғалар',
    'Психология және Бизнес',
  ];
}
