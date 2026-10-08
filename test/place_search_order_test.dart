import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/core/constants.dart';
import 'package:sorting_sahayak/data/import/scheme_io.dart';
import 'package:sorting_sahayak/features/home_shell.dart';
import 'package:sorting_sahayak/features/lookup/sort_screen.dart' show inModeFirst;

import 'helpers/app_harness.dart';

void main() {
  test('offices in the selected mode come first, otherwise best match order', () {
    // "Manglore BO" (Haryana, Non-TD) ×3 before Mangaluru HO (TD) by spelling.
    final hits = ['Manglore BO 135102', 'Manglore BO 203150', 'Manglore BO 175123', 'Mangaluru HO 575001', 'Manellore BO'];
    expect(inModeFirst(hits, (h) => h.contains('575001')), ['Mangaluru HO 575001', 'Manglore BO 135102', 'Manglore BO 203150', 'Manglore BO 175123', 'Manellore BO']);
  });

  testWidgets('TD name search lists offices on TD lines first', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, sample: false);
    await tester.runAsync(() async {
      await installDefaultScheme(h.services.schemes, (p) async => File(p).readAsBytesSync());
      await h.services.reloadActive();
    });
    h.settings.category = kCatTD;
    await tester.pumpWidget(h.wrap(HomeShell(key: HomeShell.shellKey)));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('kb_toggle')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('pin_field')), 'puttur');
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 400));
    }
    // Puttur on the TD line (574201) comes before Puttur BO in Kerala (671543).
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? t.textSpan?.toPlainText() ?? '').toList();
    final td = texts.indexWhere((s) => s.contains('574201'));
    final kerala = texts.indexWhere((s) => s.contains('671543'));
    expect(td, greaterThanOrEqualTo(0));
    expect(kerala == -1 || td < kerala, isTrue);
  });
}
