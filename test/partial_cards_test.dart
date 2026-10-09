import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/core/constants.dart';
import 'package:sorting_sahayak/data/import/scheme_io.dart';
import 'package:sorting_sahayak/data/nsh.dart';
import 'package:sorting_sahayak/features/home_shell.dart';

import 'helpers/app_harness.dart';

void main() {
  test('candidates for a partial PIN', () {
    final l1 = NshTable.parse(File(kRmsL1Asset).readAsBytesSync());
    final c = l1.candidates('574').map((h) => h.name).toList();
    expect(c, contains('Mangaluru RMS L1U'));
    expect(c.length, greaterThan(1));
    expect(l1.candidates('5751').map((h) => h.name), ['Mangaluru RMS L1U']);
  });

  testWidgets('Non-TD: first 3 digits already show PH, NSH and L1 cards', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, sample: false);
    await tester.runAsync(() async {
      await installDefaultScheme(h.services.schemes, (p) async => File(p).readAsBytesSync());
      await h.services.reloadActive();
    });
    h.services
      ..nsh = NshTable.parse(File(kNshAsset).readAsBytesSync())
      ..l1 = NshTable.parse(File(kRmsL1Asset).readAsBytesSync())
      ..nph = NshTable.parse(File(kRmsNphAsset).readAsBytesSync());
    h.settings.category = kCatNonTD;
    await tester.pumpWidget(h.wrap(HomeShell(key: HomeShell.shellKey)));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('pin_field')), '575');
    await settle(tester, rounds: 6);
    expect(find.text('PH / BAG'), findsOneWidget);
    expect(find.byKey(const ValueKey('ph_series')), findsOneWidget);
    expect(find.byKey(const ValueKey('nsh_card')), findsOneWidget);
    expect(find.text('MANGALORE NSH'), findsOneWidget);
    expect(find.byKey(const ValueKey('l1_card')), findsOneWidget);
    expect(find.text('Mangaluru RMS L1U'), findsOneWidget);
    expect(find.text('Add office'), findsNothing); // no rule list under the cards
    expect(find.byKey(const ValueKey('nph_card')), findsOneWidget);
    // Long L1 range: first ranges and "+N more" on the card, all of them on tap.
    final l1Series = (tester.widget(find.byKey(const ValueKey('l1_series'))) as Text).data!;
    expect(l1Series, contains('+'));
    await tester.tap(find.byKey(const ValueKey('l1_card')));
    await settle(tester, rounds: 6);
    final hub = h.services.l1!.resolve('575')!.hub;
    final ranges = hub.series.split(',').where((x) => x.trim().isNotEmpty).length;
    expect(find.descendant(of: find.byKey(const ValueKey('hub_sheet_ranges')), matching: find.byType(Text)), findsNWidgets(ranges));
    Navigator.of(tester.element(find.byKey(const ValueKey('hub_sheet')))).pop();
    await settle(tester, rounds: 6);
    // 574: several L1s are possible.
    await tester.enterText(find.byKey(const ValueKey('pin_field')), '574');
    await settle(tester, rounds: 6);
    expect(find.byKey(const ValueKey('l1_card')), findsOneWidget);
    expect(find.textContaining('Can be one of'), findsOneWidget);
  });
}
