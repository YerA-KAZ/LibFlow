import 'package:flutter/material.dart';

class AppColors {
  // LibFlow Figma Brand Palette
  static const Color primary = Color(0xFF1E392A); // Deep Emerald Forest Green
  static const Color primaryDark = Color(0xFF13251C);
  static const Color primaryLight = Color(0xFF2C553E);
  static const Color accent = Color(0xFFD4A373); // Warm Sand / Gold Accent
  static const Color accentLight = Color(0xFFFAEDCD);
  static const Color badgeGreen = Color(0xFF2D6A4F);

  // Status Colors
  static const Color success = Color(0xFF2D6A4F);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // Neutral Colors (Light - Warm Paper / Cream)
  static const Color backgroundLight = Color(0xFFF9F7F2); // Warm Cream Paper
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF19201D); // Deep Charcoal
  static const Color textSecondaryLight = Color(0xFF6B7280); // Muted Slate
  static const Color borderLight = Color(0xFFEBE6DC); // Gentle Warm Border
  static const Color inputBackground = Color(0xFFF4EFE6); // Soft Warm Input Field

  // Neutral Colors (Dark)
  static const Color backgroundDark = Color(0xFF101713);
  static const Color surfaceDark = Color(0xFF1A241F);
  static const Color cardDark = Color(0xFF1E2A24);
  static const Color textPrimaryDark = Color(0xFFF3F4F6);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color borderDark = Color(0xFF2A3830);
}

class AppConstants {
  static const String appName = 'LibFlow';
  static const String appTagline = 'Онлайн кітапхана және электронды кітаптар';
  
  static const List<String> categories = [
    'Барлығы',
    'Көркем әдебиет',
    'Оқулықтар',
    'IT және Технология',
    'Тарих және Тұлғалар',
    'Психология және Бизнес',
  ];
}
