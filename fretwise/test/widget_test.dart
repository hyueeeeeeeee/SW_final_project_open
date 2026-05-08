import 'package:flutter_test/flutter_test.dart';
import 'package:fretwise/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FretwiseApp());
    await tester.pumpAndSettle();
  });
}
