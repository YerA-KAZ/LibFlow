import 'package:flutter/material.dart';

import '../models/book_model.dart';
import 'qr_widget.dart';

Future<void> showReservationTicket(BuildContext context, Book book) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final theme = Theme.of(context);
      final code = book.reservationCode?.trim();
      final active = book.hasActiveReservation;
      final expires = book.reservationTime
          ?.add(const Duration(hours: 24))
          .toLocal();
      final localizations = MaterialLocalizations.of(context);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'КІТАПХАНАДАН АЛУ',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(book.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(active ? 'Белсенді бронь' : 'Бронь мерзімі аяқталған'),
              if (expires != null)
                Text(
                  '${localizations.formatShortDate(expires)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(expires))}',
                ),
              const SizedBox(height: 16),
              if (active && code != null && code.isNotEmpty) ...[
                const Text(
                  'Кітапты алу үшін осы кодты кітапхана қызметкеріне көрсетіңіз.',
                ),
                const SizedBox(height: 16),
                Center(child: CustomQrView(data: code, size: 176)),
                const SizedBox(height: 12),
                Center(
                  child: SelectableText(
                    code,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ] else if (active)
                const Text(
                  'Бұл броньға алу коды тіркелмеген. Кітапхана қызметкеріне хабарласыңыз.',
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Жабу'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
