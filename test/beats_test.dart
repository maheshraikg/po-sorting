import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/data/beats.dart';
import 'package:sorting_sahayak/data/import/table_reader.dart';
import 'package:sorting_sahayak/features/beats/beats_screen.dart';
import 'package:sorting_sahayak/features/settings/export_all.dart';
import 'package:sorting_sahayak/features/settings/import_shared.dart';

import 'helpers/app_harness.dart';

List<Beat> _starter() => beatsFromTable(readTable(File(kStarterBeatsAsset).readAsBytesSync(), 'b.csv'));

void main() {
  test('Dharwad HO beat sheet: 23 beats with their areas', () {
    final b = _starter();
    expect(b, hasLength(23));
    expect(b.every((x) => x.office == 'Dharwad HO' && x.pin == 580001), isTrue);
    expect(b.first.beat, '1');
    expect(b[1].areas, containsAll(['Michigan compound', 'Adishakti colony']));
    // Double spaces separate areas too.
    expect(b[17].areas, containsAll(['Jublee circle', 'TCW']));
  });

  test('search an area, a misspelt area, a beat number', () {
    final b = _starter();
    expect(searchBeats(b, 'michigan').first.beat.beat, '2');
    expect(searchBeats(b, 'michigan').first.areas, ['Michigan compound']);
    expect(searchBeats(b, 'sapthapur').map((h) => h.beat.beat), containsAll(['3', '4']));
    expect(searchBeats(b, 'beat 12').single.beat.beat, '12');
    expect(searchBeats(b, 'zzzz'), isEmpty);
  });

  test('read a sheet with a title row, merged office cells and number cells', () {
    final rows = [
      ['Beat wise areas', '', '', '', ''],
      ['Serial No.', 'Name of Post Office', 'Pincode', 'Beat No. ', 'Serving Areas'],
      ['1', 'Hubballi HO', '580020.0', '1.0', 'Station road, Gokul road'],
      ['', '', '', '2', 'Vidyanagar;  Keshwapur'],
    ];
    final b = readBeats(rows);
    expect(b.map((x) => (x.office, x.pin, x.beat)).toList(), [('Hubballi HO', 580020, '1'), ('Hubballi HO', 580020, '2')]);
    expect(b[1].areas, ['Vidyanagar', 'Keshwapur']);
    final (merged, n) = mergeBeats(b, [
      Beat(office: 'Hubballi HO', pin: 580020, beat: '2', areas: ['Keshwapur', 'Desai cross']),
    ]);
    expect((merged.length, n), (2, 1));
    expect(merged[1].areas, ['Vidyanagar', 'Keshwapur', 'Desai cross']);
  });

  testWidgets('Beat list: starter beats load, search, add a beat', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(BeatsScreen(loadAsset: (p) async => File(p).readAsBytesSync())));
    await settle(tester, rounds: 6);
    expect(loadBeats(h.settings), hasLength(23));
    await tester.enterText(find.byKey(const ValueKey('beats_search')), 'Michigan');
    await tester.pump();
    expect(find.byKey(const ValueKey('beat_580001_2')), findsOneWidget);
    expect(find.text('Michigan compound'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('beats_search')), '');
    await tester.tap(find.byKey(const ValueKey('beat_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('beat_no')), '24');
    await tester.enterText(find.byKey(const ValueKey('beat_areas')), 'Navanagar, KHB colony');
    await tester.tap(find.byKey(const ValueKey('beat_save')));
    await tester.pumpAndSettle();
    final added = loadBeats(h.settings).last;
    expect((added.office, added.pin, added.beat), ('Dharwad HO', 580001, '24'));
    expect(added.areas, ['Navanagar', 'KHB colony']);
  });

  testWidgets('beats travel in the shared data file', (tester) async {
    final a = await Harness.create(tester);
    storeBeats(a.settings, _starter());
    final now = DateTime(2026, 10, 21);
    final bytes = (await tester.runAsync(() => buildSharePack(a.services, a.settings, now: now)))!;
    final d = readSharedData(readTable(Uint8List.fromList(bytes), 'x.xlsx'))!;
    expect(d.beats, hasLength(23));
    final b = await Harness.create(tester);
    final r = (await tester.runAsync(
      () => applySharedData(b.services, b.settings, d, ShareChoice(offices: false, villages: false, favourites: false, scheme: false)),
    ))!;
    expect(r.beats, 23);
    expect(loadBeats(b.settings), hasLength(23));
  });
}
