import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/data/nsh.dart';
import 'package:sorting_sahayak/features/lookup/sort_result_view.dart';

import 'helpers/app_harness.dart';

void main() {
  final sheet = NshTable.parse(File(kNshAsset).readAsBytesSync());
  final rms = NshTable.parse(File(kRmsNshAsset).readAsBytesSync());

  test('same hub written differently', () {
    expect(sameHub('BENGALURU NSH', 'Bengaluru NSH'), isTrue);
    expect(sameHub('THIRUVANANTHAPURAM NSH', 'Trivandrum NSH'), isTrue);
    expect(sameHub('HUBLI-DHARWAD NSH', 'Hubballi Dharwad NSH'), isTrue);
    expect(sameHub('GURGAON NSH', 'NSH Gurgaon'), isTrue);
    expect(sameHub('NASHIK NSH', 'Nashik Road NSH'), isTrue);
    expect(sameHub('AHMEDABAD NSH', 'Rajkot NSH'), isFalse);
  });

  testWidgets('NSH card: RMS note only when the RMS data names another NSH', (tester) async {
    final h = await Harness.create(tester, sample: false);
    Future<void> show(String pin) async {
      await tester.pumpWidget(h.wrap(Scaffold(body: NshCard(match: sheet.resolve(pin)!, rmsNsh: rms.resolve(pin)?.hub.name))));
      await tester.pump();
    }

    await show('140802');
    expect(find.text('LUDHIANA NSH'), findsOneWidget);
    expect(find.text('RMS data says: Chandigarh NSH'), findsOneWidget);
    await show('575001');
    expect(find.byKey(const ValueKey('nsh_rms')), findsNothing);
    await show('673001'); // Kozhikode ICH, mapped to Kochi NSH = RMS
    expect(find.byKey(const ValueKey('nsh_rms')), findsNothing);
  });
}
