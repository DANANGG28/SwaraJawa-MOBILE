// Throwaway smoke test: TracingView harus pas viewport parent — tanpa sisa
// scroll (maxScrollExtent 0), agar goresan vertikal tidak menggeser halaman.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sjmobile/models/soal.dart';
import 'package:sjmobile/screens/quiz/widgets/kuis_chrome.dart';
import 'package:sjmobile/screens/quiz/widgets/pilihan_ganda_view.dart';
import 'package:sjmobile/screens/quiz/widgets/tracing_view.dart';

void main() {
  testWidgets('TracingView pas viewport: scroll extent 0 di 390x844', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(top: 24),
          viewPadding: EdgeInsets.only(top: 24),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  KuisHeader(
                    nomor: 1,
                    total: 3,
                    muted: true,
                    onClose: () {},
                    onToggleSound: () {},
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: TracingView(soal: soal, onChanged: (_) {}),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: PeriksaButton(
                      enabled: true,
                      loading: false,
                      // Label pendek: Epilogue tidak dibundel di test → font
                      // fallback lebih lebar dan label panjang meluap horisontal
                      // (artefak test, bukan tinggi chrome — tinggi identik).
                      label: 'Periksa',
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.ancestor(of: find.byType(TracingView), matching: find.byType(Scrollable)),
    );

    expect(
      scrollable.position.maxScrollExtent,
      0,
      reason: 'TracingView harus pas viewport; sisa scroll = goresan bisa '
          'menggeser halaman tak sengaja',
    );

  });
}
