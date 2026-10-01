import 'package:flutter_test/flutter_test.dart';

import 'package:sjmobile/app.dart';

void main() {
  testWidgets('Aplikasi SINAU APP dapat dirender', (WidgetTester tester) async {
    await tester.pumpWidget(const SinauApp());
    expect(find.byType(SinauApp), findsOneWidget);
  });
}
