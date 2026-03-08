import 'package:flutter_test/flutter_test.dart';
import 'package:memo_copypaste/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const MemoCopyPasteApp());
    expect(find.text('메모복붙'), findsOneWidget);
  });
}
