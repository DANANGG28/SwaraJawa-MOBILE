import 'package:flutter_test/flutter_test.dart';

import 'package:sjmobile/app.dart';

void main() {
  testWidgets('Aplikasi Sinau Jowo dapat dirender', (WidgetTester tester) async {
    await tester.pumpWidget(const SinauJowoApp());
    expect(find.byType(SinauJowoApp), findsOneWidget);
  });
}
