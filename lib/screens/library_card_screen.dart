import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import '../widgets/qr_widget.dart';

class LibraryCardScreen extends StatelessWidget {
  const LibraryCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final ticket = (user?['ticket'] as String? ?? '').trim();
    final name = (user?['name'] as String? ?? '').trim();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Электронды оқырман билеті')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Card(
                color: colors.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        color: colors.onPrimaryContainer,
                        size: 32,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ОҚЫРМАН БИЛЕТІ',
                        style: theme.textTheme.labelLarge?.copyWith(
                          letterSpacing: 1.6,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name.isEmpty ? 'Оқырман' : name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      if (ticket.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SelectableText(
                          ticket,
                          style: TextStyle(color: colors.onPrimaryContainer),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (ticket.isNotEmpty) ...[
                        CustomQrView(data: ticket, size: 180),
                        const SizedBox(height: 12),
                        const Text(
                          'QR-код оқырман билетінің нөмірін қамтиды.',
                          textAlign: TextAlign.center,
                        ),
                      ] else
                        const Text('Оқырман билетінің нөмірі тіркелмеген.'),
                      const SizedBox(height: 8),
                      Text(
                        'Кітапты алу үшін «Броньдар» бөліміндегі бронь билетін ашыңыз.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
