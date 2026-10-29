import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sjmobile/core/theme/app_theme.dart';
import 'package:sjmobile/screens/speech/latihan_ngomong_screen.dart';
import 'package:sjmobile/state/app_state.dart';
import 'package:sjmobile/widgets/preppy_pill_avatar.dart';

void main() {
  testWidgets('LatihanNgomongScreen renders unified stage UI matching website', (tester) async {
    final appState = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LatihanNgomongScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // 1. Verifikasi header bar panggung
    expect(find.text('Si Swara'), findsOneWidget);
    expect(find.text('Aktif · Tutor Wicara Basa Jawa'), findsOneWidget);
    expect(find.text('1.0x'), findsOneWidget);
    expect(find.text('Kosakata'), findsOneWidget);

    // 2. Verifikasi maskot animasi PreppyPillAvatar
    expect(find.byType(PreppyPillAvatar), findsOneWidget);

    // 3. Verifikasi badge petunjuk mic interaktif
    expect(find.text('Pencet & tahan Si Swara kanggo wicara'), findsOneWidget);

    // 4. Verifikasi wadah subtitle AI awal & tantangan peniruan
    expect(find.textContaining('Sugeng rawuh! Kula Si Swara'), findsOneWidget);
    expect(find.text('Sugeng enjang, Mas Swara'), findsOneWidget);

    // 5. Verifikasi toggle kecepatan suara
    await tester.tap(find.text('1.0x'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 6. Verifikasi toggle form input teks
    final ketikButton = find.text('Ketik Pitakon');
    await tester.scrollUntilVisible(ketikButton, 100);
    await tester.tap(ketikButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Gunakan Suara'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
