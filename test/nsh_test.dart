import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/core/constants.dart';
import 'package:sorting_sahayak/data/import/scheme_io.dart';
import 'package:sorting_sahayak/data/nsh.dart';
import 'package:sorting_sahayak/features/home_shell.dart';

import 'helpers/app_harness.dart';

void main() {
  final table = NshTable.parse(File(kNshAsset).readAsBytesSync());

  test('the sheet has its 50 NSH and the ICH of Karnataka and Kerala', () {
    expect(table.hubs.where((h) => h.kind == 'NSH').length, 50);
    expect(table.hubs.where((h) => h.kind == 'ICH' && h.circle == 'Karnataka').length, 13);
  });

  test('PIN → NSH / ICH: exact, range, then longest prefix', () {
    String? hub(String pin) => table.resolve(pin)?.hub.name;
    expect(hub('560001'), 'BENGALURU NSH');
    expect(hub('574239'), 'MANGALORE NSH');
    expect(hub('110001'), 'NEW DELHI NSH');
    expect(hub('194101'), 'NEW DELHI NSH');
    expect(hub('415213'), 'THANE NSH');
    expect(hub('415201'), 'MUMBAI NSH');
    expect(hub('416510'), 'MUMBAI NSH');
    expect(hub('416501'), 'PUNE NSH');
    expect(hub('411001'), 'PUNE NSH');
    expect(hub('423401'), 'NASHIK NSH');
    expect(hub('423101'), 'PUNE NSH'); // 4231 is listed under Pune
    expect(hub('678001'), 'COIMBATORE NSH');
    expect(hub('680001'), 'THRISSUR ICH');
    expect(table.resolve('680001')!.hub.mappedTo, 'KOCHI NSH');
    expect(hub('577301'), 'SHIVAMOGGA ICH');
    expect(hub('577228'), 'ARSIKERE ICH');
    expect(hub('577601'), 'DAVANGERE ICH');
    expect(hub('577101'), 'ARSIKERE ICH');
    expect(hub('561202'), 'TUMKUR ICH');
    expect(hub('561201'), 'BENGALURU NSH');
    expect(hub('175001'), 'AMBALA NSH');
    expect(hub('176001'), 'PATHANKOT NSH');
    // Series the sheet lists under two hubs: both are shown.
    List<String> both(String pin) {
      final m = table.resolve(pin)!;
      return [m.hub.name, ...m.alsoListed.map((h) => h.name)];
    }
    expect(both('402201'), ['THANE NSH', 'MUMBAI NSH']);
    expect(both('423401'), ['NASHIK NSH', 'MUMBAI NSH']);
    expect(both('415201'), ['MUMBAI NSH']); // 415201-415212 is Mumbai's own range
    expect(both('415250'), ['MUMBAI NSH']);
    expect(both('415290'), ['MUMBAI NSH']);
    expect(both('679101'), ['COIMBATORE NSH', 'THRISSUR ICH']);
    expect(both('577201'), ['ARSIKERE ICH', 'SHIVAMOGGA ICH']);
    expect(both('577501'), ['ARSIKERE ICH', 'DAVANGERE ICH']);
    expect(both('175001'), ['AMBALA NSH', 'PATHANKOT NSH']);
    expect(both('560001'), ['BENGALURU NSH']);
    expect(hub('900099'), '2 CBPO (APS)');
    expect(hub('305026'), 'JODHPUR NSH');
    expect(hub('305001'), 'JAIPUR NSH');
    expect(hub('229402'), 'LUCKNOW NSH');
    expect(hub('229410'), 'PRAYAGRAJ NSH');
    expect(hub('99'), isNull);
    expect(hub('560'), 'BENGALURU NSH');
    expect(table.resolve('416510')!.matched, '416510-416525');
  });

  testWidgets('Sort (Non-TD) shows the PH bag and a separate NSH card with its PIN range', (tester) async {
    final h = await Harness.create(tester, sample: false);
    await tester.runAsync(() async {
      await installDefaultScheme(h.services.schemes, (p) async => File(p).readAsBytesSync());
      await h.services.reloadActive();
    });
    h.services.nsh = table;
    h.settings.category = kCatNonTD;
    await tester.pumpWidget(h.wrap(HomeShell(key: HomeShell.shellKey)));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('pin_field')), '574201');
    await settle(tester, rounds: 6);
    expect(find.text('PH / BAG'), findsOneWidget);
    expect((tester.widget(find.byKey(const ValueKey('ph_series'))) as Text).textSpan!.toPlainText(), endsWith('574-576'));
    final scheme = h.services.active!;
    expect(scheme.pinSeries('BANGALORE', category: kCatNonTD), '515, 560-563');
    expect(scheme.pinSeries('TUMUKUR', category: kCatNonTD), '572, 561202');
    expect(scheme.pinSeries('MUMBAI', category: kCatNonTD), contains('4101-4102'));
    expect(find.byKey(const ValueKey('nsh_card')), findsOneWidget);
    expect(find.text('MANGALORE NSH'), findsOneWidget);
    expect((tester.widget(find.byKey(const ValueKey('nsh_series'))) as Text).data, '574-576');
    // TD mode: no NSH card.
    await tester.tap(find.text('TD').first);
    await settle(tester, rounds: 6);
    expect(find.byKey(const ValueKey('nsh_card')), findsNothing);
  });

  test('hub air code: set on the hub, else the airport of its city', () {
    NshHub hub(String name, [String air = '']) => NshHub(name: name, kind: 'NSH', circle: '', series: '515', air: air);
    expect(hubAirCode(hub('Bengaluru Parcel Hub / Ananthapur PH')), 'BLR');
    expect(hubAirCode(hub('Hyderabad PH / Kurnool PH')), 'HYD');
    expect(hubAirCode(hub('TIRUPATHI NSH')), 'TIR');
    expect(hubAirCode(hub('MANGALORE NSH')), 'IXE');
    expect(hubAirCode(hub('KURNOOL NSH')), '');
    expect(hubAirCode(hub('KURNOOL NSH', 'HYD')), 'HYD');
    final t = NshTable([hub('KURNOOL NSH', 'HYD')]);
    expect(NshTable.parse(Uint8List.fromList(utf8.encode(t.toCsv()))).hubs.single.air, 'HYD');
  });
}
