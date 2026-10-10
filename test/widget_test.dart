import 'package:flutter_test/flutter_test.dart';
import 'package:flexbooru/main.dart';

void main() {
  testWidgets('Flexbooru app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FlexbooruApp());
    expect(find.byType(FlexbooruApp), findsOneWidget);
  });
}
