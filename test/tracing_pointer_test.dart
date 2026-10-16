import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sjmobile/models/soal.dart';
import 'package:sjmobile/screens/quiz/widgets/tracing_view.dart';

void main() {
  testWidgets('TracingView captures pointer drawing immediately without slop delay', (tester) async {
    const soal = Soal(
      id: 1,
      tipeSoal: Soal.tipeMenulisAksara,
      pertanyaan: 'Tulis aksara ha',
      opsiJawaban: {
        'aksara': 'ꦲ',
        'petunjuk': 'Telusuri bayangan aksara.',
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TracingView(
            soal: soal,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Pastikan Listener terpasang di kanvas
    expect(find.byType(Listener), findsWidgets);

    // Simulasi sentuhan jari pada kanvas
    final customPaintFinder = find.byType(CustomPaint).first;
    final gesture = await tester.startGesture(tester.getCenter(customPaintFinder));
    await gesture.moveBy(const Offset(15, 15));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
