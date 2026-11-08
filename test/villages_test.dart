import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/data/directory_builder.dart' show OfficeData;
import 'package:sorting_sahayak/data/import/scheme_io.dart';
import 'package:sorting_sahayak/data/import/table_reader.dart';
import 'package:sorting_sahayak/data/models/office.dart';
import 'package:sorting_sahayak/data/village_import.dart';
import 'package:sorting_sahayak/features/packs/office_packs.dart';
import 'package:sorting_sahayak/data/villages.dart';
import 'package:sorting_sahayak/features/settings/export_all.dart';
import 'package:sorting_sahayak/features/settings/office_editor.dart';
import 'package:sorting_sahayak/features/settings/village_editor.dart';

import 'helpers/app_harness.dart';

Future<Harness> _setUp(WidgetTester tester) async {
  final h = await Harness.create(tester, sample: false);
  await tester.runAsync(() async {
    await installDefaultScheme(h.services.schemes, (p) async => File(p).readAsBytesSync());
    await h.services.reloadActive();
  });
  return h;
}

void main() {
  test('village book: add, dedupe, remove, spelling-tolerant find', () {
    var lists = setVillages(const [], 574202, 'Darbe', ['Kodimbadi', ' kodimbadi ', 'Bolwar  Gudde', '']);
    expect(lists.single.villages, ['Kodimbadi', 'Bolwar Gudde']);
    final book = VillageBook(lists);
    expect(book.of(574202, 'DARBE'), ['Kodimbadi', 'Bolwar Gudde']);
    expect(book.find('kodimbadi').single.village, 'Kodimbadi');
    expect(book.find('kodimbady').map((v) => v.village), contains('Kodimbadi'));
    expect(book.find('gudde').map((v) => v.village), ['Bolwar Gudde']);
    expect(book.find('mangaluru'), isEmpty);
    lists = setVillages(lists, 574202, 'Darbe', []);
    expect(lists, isEmpty);
    expect(splitVillages('Kodi, Hosur;Bela\n'), ['Kodi', 'Hosur', 'Bela']);
  });

  test('villages follow their office when it is renamed', () {
    final lists = setVillages(const [], 574202, 'Darbe', ['Kodimbadi']);
    final moved = moveVillages(lists, 574202, 'Darbe', 574203, 'Darbe Padavu');
    expect(VillageBook(moved).of(574203, 'Darbe Padavu'), ['Kodimbadi']);
    expect(VillageBook(moved).of(574202, 'Darbe'), isEmpty);
  });

  testWidgets('a village name finds its office; saved, exported, kept on rename', (tester) async {
    final h = await _setUp(tester);
    final s = h.settings, sv = h.services;
    Future<List<Office>> at(int pin) async => (await tester.runAsync(() => sv.directory.officesForPin(pin)))!;
    final darbe = (await at(574202)).firstWhere((o) => o.officeName == 'Darbe');
    saveVillages(s, sv, 574202, 'Darbe', ['Kodimbadi Kere']);
    expect(s.villages, hasLength(1));
    final hits = (await tester.runAsync(() => sv.directory.search('Kodimbadi Kere')))!;
    expect(hits.first.office.officeName, 'Darbe');
    expect(hits.first.village, 'Kodimbadi Kere');
    // Restart: loaded from settings.
    sv.villages = VillageBook.empty;
    loadVillagesOnStart(s, sv);
    expect(sv.villages.of(574202, 'Darbe'), ['Kodimbadi Kere']);
    // Export.
    final files = (await tester.runAsync(() => exportAllData(sv, s, now: DateTime(2026, 10, 16))))!;
    final book = readTable(files['PO_Sorting_data_2026-10-16.xlsx'] as Uint8List, 'x.xlsx');
    expect(book.sheets['Villages']![1], ['574202', 'Darbe', 'Kodimbadi Kere']);
    // Rename the office: villages move with it and search still finds it.
    await tester.runAsync(
      () => saveOfficeChange(
        s,
        sv,
        officeData(darbe),
        OfficeData(pincode: 574202, name: 'Darbe Jn', type: darbe.officeType, district: darbe.district, state: darbe.state),
      ),
    );
    expect(sv.villages.of(574202, 'Darbe Jn'), ['Kodimbadi Kere']);
    final again = (await tester.runAsync(() => sv.directory.search('kodimbadi kere')))!;
    expect(again.first.office.officeName, 'Darbe Jn');
  });

  testWidgets('village dialog: add two with a comma, remove one, save', (tester) async {
    final h = await _setUp(tester);
    await tester.pumpWidget(
      h.wrap(
        Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => editVillages(c, pin: 574202, name: 'Darbe', type: 'BO'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('village_field')), 'Kodi, Hosur');
    await tester.tap(find.byKey(const ValueKey('village_add')));
    await tester.pump();
    expect(find.byKey(const ValueKey('village_chip_Kodi')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('village_chip_Kodi')), matching: find.byTooltip('Remove village')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('villages_save')));
    await tester.pumpAndSettle();
    expect(h.services.villages.of(574202, 'Darbe'), ['Hosur']);
    expect(find.text('1 villages saved for Darbe'), findsOneWidget);
  });

  test('village directory sheet: title row, two-row header, PO and account office', () {
    final rows = [
      ['ALUR Taluk', '', '', ''],
      ['Name of the ', 'Name of the ', 'Account ', 'Pincode'],
      ['village', 'PO', 'office', ''],
      ['Kodimbadi', 'Darbe BO', 'Puttur', '574202.0'],
      ['Bolwar', 'Darbey', 'Puttur', ''],
      ['', '', '', ''],
    ];
    final v = readVillageSheet(rows);
    expect(v.map((x) => x.village).toList(), ['Kodimbadi', 'Bolwar']);
    expect((v.first.po, v.first.account, v.first.pin, v.last.pin), ('Darbe BO', 'Puttur', 574202, null));
  });

  testWidgets('village sheet rows go under the right office (spelling, missing PIN)', (tester) async {
    final h = await _setUp(tester);
    final rows = [
      const VillageRow(village: 'Kodimbadi', po: 'Darbe BO', pin: 574202),
      const VillageRow(village: 'Bolwar', po: 'Darbey', account: 'Puttur'),
      const VillageRow(village: 'Nowhere', po: 'Xyzabc', pin: 574202),
    ];
    final m = (await tester.runAsync(() => matchVillages(h.services.directory, rows)))!;
    expect(m[0].office?.officeName, 'Darbe');
    expect(m[1].office?.officeName, 'Darbe');
    expect(m[2].office, isNull);
    final n = addVillageLists(h.settings, h.services, [
      for (final x in m)
        if (x.office != null) VillageList(pin: x.office!.pincode, office: x.office!.officeName, villages: [x.row.village]),
    ]);
    expect(n, 2);
    expect(h.services.villages.of(574202, 'Darbe'), ['Kodimbadi', 'Bolwar']);
  });

  testWidgets('office packs: villages added on, removed off; own villages stay', (tester) async {
    final h = await _setUp(tester);
    Future<Uint8List> load(String p) async => File(p).readAsBytesSync();
    final hassan = kOfficePacks.firstWhere((p) => p.id == 'hassan');
    saveVillages(h.settings, h.services, 573129, 'Bharathur', ['My own village']);
    await tester.runAsync(() => setPack(h.settings, h.services, hassan, true, load));
    expect(h.settings.enabledPacks, ['hassan']);
    expect(h.services.villages.of(573129, 'Bharathur'), containsAll(['My own village', 'Adabyalu']));
    final n = h.settings.villages.fold<int>(0, (n, e) => n + (e['villages'] as List).length);
    expect(n, greaterThan(2300));
    await tester.runAsync(() => setPack(h.settings, h.services, hassan, false, load));
    expect(h.settings.enabledPacks, isEmpty);
    expect(h.services.villages.of(573129, 'Bharathur'), ['My own village']);
  });

  testWidgets('phones that already had the bundled data keep it switched on', (tester) async {
    final h = await _setUp(tester);
    h.settings.seededVillageSets = ['hassan', 'shimoga'];
    migratePacks(h.settings);
    expect(h.settings.enabledPacks, ['hassan', 'shimoga']);
    h.settings.seededVillageSets = [];
    migratePacks(h.settings); // runs once
    expect(h.settings.enabledPacks, ['hassan', 'shimoga']);
  });

  testWidgets('Office data screen: switch a pack on', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final h = await _setUp(tester);
    await tester.pumpWidget(h.wrap(OfficePacksScreen(loadAsset: (p) async => File(p).readAsBytesSync())));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    expect(find.text('Main data (always on)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pack_dharwad')));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
    }
    expect(h.settings.enabledPacks, ['dharwad']);
    expect(h.settings.beats, hasLength(23));
  });
}
