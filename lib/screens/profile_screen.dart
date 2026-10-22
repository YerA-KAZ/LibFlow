import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'library_card_screen.dart';

class ProfileScreen extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeToggle;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Профиль',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'serif'),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // User Avatar Card matching Figma 14: Circular Avatar with 'A', 'Айша Нұрлан', 'Оқырман • 2026 жылдан'
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: isDark ? AppColors.surfaceDark : const Color(0xFFE5EDE8),
                    child: const Text(
                      'A',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Айша Нұрлан',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Оқырман • 2026 жылдан',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Statistics Grid (3 items as in Figma 14: 5 Кітап | 2 Оқылуда | 1 240 Бет)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildFigmaStatTile('Кітап', '5', isDark),
                  Container(height: 32, width: 1, color: isDark ? Colors.white12 : Colors.grey[200]),
                  _buildFigmaStatTile('Оқылуда', '2', isDark),
                  Container(height: 32, width: 1, color: isDark ? Colors.white12 : Colors.grey[200]),
                  _buildFigmaStatTile('Бет', '1 240', isDark),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Section: Менің кеңістігім (My space)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Менің кеңістігім',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Navigation List Items matching Figma 14
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.menu_book_outlined, color: AppColors.primaryLight),
                    title: const Text('Менің кітапханам', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LibraryCardScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.favorite_border_rounded, color: AppColors.primaryLight),
                    title: const Text('Таңдаулылар', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: AppColors.primaryLight),
                    title: const Text('Баптаулар', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Settings & Preferences
            Material(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Open Library Card
                  ListTile(
                    leading: const Icon(Icons.badge_rounded,
                        color: AppColors.primaryLight),
                    title: const Text('Сандық оқырман билеті',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('QR-код және штрих-код'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LibraryCardScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),

                  // Dark Mode Switch (US-10)
                  SwitchListTile(
                    secondary: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: AppColors.accent,
                    ),
                    title: const Text('Түнгі режим (Dark Mode)',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Көзді шаршатпайтын қараңғы тақырып'),
                    value: isDarkMode,
                    onChanged: onThemeToggle,
                  ),
                  const Divider(height: 1),

                  // Language selection
                  ListTile(
                    leading: const Icon(Icons.language_rounded,
                        color: AppColors.primaryLight),
                    title: const Text('Қосымша тілі',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Қазақша 🇰🇿',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const Divider(height: 1),

                  // Notifications preference
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined,
                        color: AppColors.primaryLight),
                    title: const Text('Push-хабарламалар',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Дедлайнға 2 күн қалғанда ескерту'),
                    trailing: Switch(value: true, onChanged: (_) {}),
                  ),
                  const Divider(height: 1),

                  // Open Library API status
                  ListTile(
                    leading: const Icon(Icons.public_rounded,
                        color: Color(0xFF0284C7)),
                    title: const Text('Open Library API',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('search.json • Қолжетімді'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Белсенді',
                          style: TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const Divider(height: 1),

                  // Google Books API status
                  ListTile(
                    leading: const Icon(Icons.auto_stories_rounded,
                        color: Color(0xFF1E3A8A)),
                    title: const Text('Google Books API',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('books.googleapis.com • Интеграцияланған'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Белсенді',
                          style: TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button (FR-12)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Жүйеден шығу (Logout)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Шығуды растау'),
                      content: const Text(
                          'LibFlow жүйесінен шыққыңыз келетініне сенімдісіз бе?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Бас тарту'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            onLogout();
                          },
                          child: const Text('Шығу'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'LibFlow v1.0.0 (MVP) • 2024',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFigmaStatTile(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

}
