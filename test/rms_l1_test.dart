import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/core/constants.dart';
import 'package:sorting_sahayak/data/import/scheme_io.dart';
import 'package:sorting_sahayak/data/nsh.dart';
import 'package:sorting_sahayak/features/home_shell.dart';

import 'helpers/app_harness.dart';

void main() {
  final l1 = NshTable.parse(File(kRmsL1Asset).readAsBytesSync());
  final nph = NshTable.parse(File(kRmsNphAsset).readAsBytesSync());

  test('RMS L1 and NPH per PIN, as in the MR RMS sorting data', () {
    expect(l1.resolve('575001')!.hub.name, 'Mangaluru RMS L1U');
    expect(l1.resolve('574239')!.hub.name, 'Mangaluru RMS L1U');
    expect(l1.resolve('400001')!.hub.name, 'Mumbai Unaccountable L1');
    expect(l1.resolve('673001')!.hub.name, 'Kozhikode RMS L1U');
    expect(l1.resolve('560001'), isNull); // no L1 in the data
    expect(nph.resolve('560001')!.hub.name, 'Bengaluru Parcel Hub');
    expect(nph.resolve('110001')!.hub.name, 'Integrated Parcel Hub AMPC');
    expect(nph.resolve('575001')!.hub.name, 'Mangaluru PH');
    expect(l1.hubs.length, greaterThan(200));
  });

  testWidgets('Sort (Non-TD) shows the RMS L1 card with the parcel hub', (tester) async {
    final h = await Harness.create(tester, sample: false);
    await tester.runAsync(() async {
      await installDefaultScheme(h.services.schemes, (p) async => File(p).readAsBytesSync());
      await h.services.reloadActive();
    });
    h.services
      ..nsh = NshTable.parse(File(kNshAsset).readAsBytesSync())
      ..l1 = l1
      ..nph = nph;
    h.settings.category = kCatNonTD;
    await tester.pumpWidget(h.wrap(HomeShell(key: HomeShell.shellKey)));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('pin_field')), '673001');
    await settle(tester, rounds: 6);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('l1_card')), 200, scrollable: find.byType(Scrollable).first);
    expect((tester.widget(find.byKey(const ValueKey('l1_name'))) as Text).data, 'Kozhikode RMS L1U');
    expect((tester.widget(find.byKey(const ValueKey('nph_name'))) as Text).data, 'Parcel hub (NPH): Kozhikode PH');
  });
}
