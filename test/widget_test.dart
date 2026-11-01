import 'package:flutter_test/flutter_test.dart';
import 'package:libflow/main.dart';

void main() {
  testWidgets('LibFlow app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LibFlowApp());
    // Splash screen runs a 2.5s timer
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();
    expect(find.byType(LibFlowApp), findsOneWidget);
  });
}
