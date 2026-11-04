import 'package:flutter/material.dart';

import '../services/library_realtime_service.dart';
import '../services/library_repository.dart';

class ConnectionBanner extends StatelessWidget {
  final LibraryRepository repository;
  const ConnectionBanner({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    final state = repository.realtimeStatus;
    final offline = state == RealtimeStatus.offline;
    final message =
        (offline ? null : repository.error) ??
        switch (state) {
          RealtimeStatus.idle => 'Жергілікті деректер',
          RealtimeStatus.connecting => 'Нақты уақыттағы байланыс орнатылуда…',
          RealtimeStatus.online => 'Нақты уақыттағы байланыс қосылды',
          RealtimeStatus.offline => 'Offline: желі немесе сервер қолжетімсіз. Сақталған кітаптар көрсетілуде. Қайта қосылу автоматты.',
          RealtimeStatus.error =>
            'Байланыс деректерінде қате бар. Қайта қосылу автоматты.',
        };
    return SafeArea(
      bottom: false,
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            offline || repository.error != null ? Icons.cloud_off : Icons.sync,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
          IconButton(
            tooltip: 'Серверден жаңарту',
            onPressed: repository.status == LibraryStatus.loading
                ? null
                : () {
                    if (state != RealtimeStatus.online) {
                      repository.retryRealtime();
                    }
                    repository.refresh();
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
