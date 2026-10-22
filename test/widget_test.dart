import 'package:flutter_test/flutter_test.dart';
import 'package:libflow/main.dart';

void main() {
  testWidgets('LibFlow app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LibFlowApp());
    expect(find.text('LibFlow'), findsNothing); // Title is in MaterialApp
  });
}
