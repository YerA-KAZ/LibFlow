import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import '../services/library_database_service.dart';
import 'library_card_screen.dart';
import 'notifications_screen.dart';
import 'qr_scanner_screen.dart';

class ProfileScreen extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeToggle;
  final VoidCallback onLogout;
  final VoidCallback onNavigateToFavorites;
  final VoidCallback onNavigateToMyBooks;
  final VoidCallback? onOpenStaff;

  const ProfileScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
    required this.onLogout,
    required this.onNavigateToFavorites,
    required this.onNavigateToMyBooks,
    this.onOpenStaff,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final name = (user?['name'] as String? ?? '').trim();
    final ticket = user?['ticket'] as String? ?? '';
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    void open(Widget screen) => Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: scheme.onPrimaryContainer,
                        foregroundColor: scheme.primaryContainer,
                        child: Text(
                          name.isEmpty
                              ? '?'
                              : name.characters.first.toUpperCase(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name.isEmpty ? 'Оқырман' : name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        user?['email'] as String? ?? '',
                        style: TextStyle(color: scheme.onPrimaryContainer),
                      ),
                      if (ticket.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Оқырман билеті · $ticket',
                          style: TextStyle(color: scheme.onPrimaryContainer),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Менің кітапханам', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    _entry(
                      Icons.badge_outlined,
                      'Сандық оқырман билеті',
                      () => open(const LibraryCardScreen()),
                    ),
                    const Divider(height: 1),
                    _entry(
                      Icons.confirmation_number_outlined,
                      'Менің броньдарым',
                      onNavigateToMyBooks,
                    ),
                    const Divider(height: 1),
                    _entry(
                      Icons.favorite_border,
                      'Таңдаулылар',
                      onNavigateToFavorites,
                    ),
                    const Divider(height: 1),
                    _entry(
                      Icons.notifications_outlined,
                      'Хабарламалар',
                      () => open(
                        NotificationsScreen(
                          books: LibraryDatabaseService().books,
                          onNavigateToMyBooks: onNavigateToMyBooks,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    _entry(
                      Icons.settings_outlined,
                      'Баптаулар',
                      () => showModalBottomSheet<void>(
                        context: context,
                        builder: (_) {
                          var dark = isDarkMode;
                          return StatefulBuilder(
                            builder: (_, setSheetState) => SafeArea(
                              child: SwitchListTile(
                                title: const Text('Түнгі режим (Dark Mode)'),
                                value: dark,
                                onChanged: (value) {
                                  onThemeToggle(value);
                                  setSheetState(() => dark = value);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      leading: Icon(Icons.language),
                      title: Text('Қосымша тілі'),
                      trailing: Text('Қазақша'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    if (onOpenStaff != null) ...[
                      _entry(Icons.shelves, 'Қызметкер бөлімі', onOpenStaff!),
                      const Divider(height: 1),
                    ],
                    _entry(
                      Icons.qr_code_scanner,
                      'Бронь QR кодын тексеру',
                      () => open(const QrScannerScreen()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Жүйеден шығу'),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('LibFlow жүйесінен шығасыз ба?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Бас тарту'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Шығу'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) onLogout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _entry(IconData icon, String label, VoidCallback onTap) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
