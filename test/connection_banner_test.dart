import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libflow/services/library_realtime_service.dart';
import 'package:libflow/services/library_repository.dart';
import 'package:libflow/widgets/connection_banner.dart';

class BannerRepository extends LibraryRepository {
  final RealtimeStatus connection;
  int retries = 0;
  int refreshes = 0;
  BannerRepository(this.connection);
  @override
  RealtimeStatus get realtimeStatus => connection;
  @override
  void retryRealtime() => retries++;
  @override
  Future<bool> refresh() async {
    refreshes++;
    return true;
  }
}

void main() {
  testWidgets('Offline banner explains cache and automatic retry', (
    tester,
  ) async {
    final repository = BannerRepository(RealtimeStatus.offline)
      ..error = 'Желі қолжетімсіз';
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConnectionBanner(repository: repository)),
      ),
    );
    expect(find.textContaining('Offline:'), findsOneWidget);
    expect(find.textContaining('Сақталған кітаптар'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.refresh));
    expect(repository.retries, 1);
    expect(repository.refreshes, 1);
  });

  testWidgets('Protocol error has a readable recovery message', (tester) async {
    final repository = BannerRepository(RealtimeStatus.error);
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConnectionBanner(repository: repository)),
      ),
    );
    expect(find.textContaining('Байланыс деректерінде қате'), findsOneWidget);
    expect(find.textContaining('Қайта қосылу автоматты'), findsOneWidget);
  });

  testWidgets('Online banner refreshes without replacing healthy socket', (
    tester,
  ) async {
    final repository = BannerRepository(RealtimeStatus.online);
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConnectionBanner(repository: repository)),
      ),
    );
    expect(find.text('Нақты уақыттағы байланыс қосылды'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.refresh));
    expect(repository.retries, 0);
    expect(repository.refreshes, 1);
  });
}
