import 'package:flutter_test/flutter_test.dart';
import 'package:krishi_rakshak_app/main.dart';

void main() {
  testWidgets('Krishi Rakshak app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const KrishiRakshakApp());

    expect(find.byType(KrishiRakshakApp), findsOneWidget);
  });
}