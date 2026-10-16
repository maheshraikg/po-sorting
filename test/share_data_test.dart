import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/data/directory_builder.dart' show OfficeData;
import 'package:sorting_sahayak/data/import/scheme_io.dart';
import 'package:sorting_sahayak/data/import/table_reader.dart';
import 'package:sorting_sahayak/data/nsh.dart';
import 'package:sorting_sahayak/features/settings/export_all.dart';
import 'package:sorting_sahayak/features/settings/import_shared.dart';
import 'package:sorting_sahayak/features/settings/office_editor.dart';
import 'package:sorting_sahayak/features/settings/village_editor.dart';

import 'helpers/app_harness.dart';

Future<Harness> _phone(WidgetTester tester) async {
  final h = await Harness.create(tester, sample: false);
  await tester.runAsync(() async {
    await installDefaultScheme(h.services.schemes, (p) async => File(p).readAsBytesSync());
    await h.services.reloadActive();
  });
  for (final k in HubTableKind.values) {
    h.services.setTable(k, NshTable.parse(File(k.asset).readAsBytesSync()));
  }
  return h;
}

void main() {
  testWidgets('share pack: one user exports, another imports the same data', (tester) async {
    final a = await _phone(tester);
    final darbe = (await tester.runAsync(() => a.services.directory.officesForPin(574202)))!.firstWhere((o) => o.officeName == 'Darbe');
    await tester.runAsync(() async {
      await saveOfficeChange(
        a.settings,
        a.services,
        null,
        const OfficeData(pincode: 574202, name: 'Kemminje', type: 'BO', district: 'Dakshina Kannada', state: 'Karnataka'),
      );
      await saveOfficeChange(
        a.settings,
        a.services,
        officeData(darbe),
        OfficeData(pincode: 574202, name: 'Darbe Jn', type: darbe.officeType, district: darbe.district, state: darbe.state),
      );
      await a.services.user.addFavourite(darbe);
    });
    saveVillages(a.settings, a.services, 574202, 'Kemminje', ['Kodimbadi', 'Bolwar']);
    // Edit the NPH table on phone A.
    final nph = a.services.nph!;
    final i = nph.hubs.indexWhere((x) => x.series.contains('560'));
    final hubs = [...nph.hubs];
    hubs[i] = NshHub(name: 'My Parcel Hub', kind: hubs[i].kind, circle: hubs[i].circle, series: hubs[i].series);
    final t = NshTable(hubs);
    a.settings.setTableCsv(HubTableKind.nph.prefsKey, t.toCsv());
    a.services.setTable(HubTableKind.nph, t);

    final files = (await tester.runAsync(() => exportAllData(a.services, a.settings, now: DateTime(2026, 10, 16))))!;
    final bytes = files[sharePackName(DateTime(2026, 10, 16))] as Uint8List;
    final pack = readSharedData(readTable(bytes, 'PO_Sorting_data_2026-10-16.xlsx'))!;
    expect(pack.officeCount, 2);
    expect(pack.villageCount, 2);
    expect(pack.editedTables, {HubTableKind.nph});
    expect(pack.hasScheme, isTrue);

    // Phone B.
    final b = await _phone(tester);
    final offer = shareOffer(b.services, pack);
    expect(offer.tables, {HubTableKind.nph}); // B has the same bundled NSH / L1 / RMS NSH
    expect(offer.schemeSame, isTrue); // B has the same default scheme
    final choice = offer.choice(pack)..scheme = true;
    expect(choice.tables, {HubTableKind.nph});
    final r = (await tester.runAsync(() => applySharedData(b.services, b.settings, pack, choice)))!;
    expect((r.offices, r.villages, r.tables, r.favourites, r.scheme), (2, 2, 1, 1, true));
    final at = (await tester.runAsync(() => b.services.directory.officesForPin(574202)))!.map((o) => o.officeName).toList();
    expect(at, containsAll(['Kemminje', 'Darbe Jn']));
    expect(at, isNot(contains('Darbe')));
    expect(b.services.villages.of(574202, 'Kemminje'), ['Kodimbadi', 'Bolwar']);
    final hit = (await tester.runAsync(() => b.services.directory.search('Kodimbadi')))!.first;
    expect((hit.office.officeName, hit.village), ('Kemminje', 'Kodimbadi'));
    expect(b.services.nph!.resolve('560001')!.hub.name, 'My Parcel Hub');
    expect(b.settings.tableCsv(HubTableKind.nph.prefsKey), contains('My Parcel Hub'));
    expect(b.settings.tableCsv(HubTableKind.nsh.prefsKey), isNull); // not edited: B keeps the bundled sheet
    expect(b.services.active!.scheme.name, contains('(shared 2026-10-16)'));
    expect(b.services.active!.bagResolver.rules.length, a.services.active!.bagResolver.rules.length);

    // Importing the same file again adds nothing.
    final again = (await tester.runAsync(() => applySharedData(b.services, b.settings, pack, ShareChoice(scheme: false))))!;
    expect((again.offices, again.villages, again.favourites), (0, 0, 0));
  });

  test('not a share pack', () {
    expect(
      readSharedData(
        const TableFile({
          'Sheet1': [
            ['PIN', 'Bag'],
          ],
        }),
      ),
      isNull,
    );
  });

  testWidgets('import dialog lists what is in the file', (tester) async {
    final h = await _phone(tester);
    final d = SharedData(
      villages: const [],
      favourites: const [(pin: 574202, office: 'Darbe', note: '')],
      schemeName: 'Udupi TD',
      schemeRules: const [
        ['h'],
        ['r'],
      ],
    );
    ShareChoice? got;
    await tester.pumpWidget(
      h.wrap(
        Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () async => got = await showDialog(
                context: c,
                builder: (_) => ShareImportDialog(data: d, offer: shareOffer(h.services, d), fileName: 'x.xlsx'),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('share_favourites')), findsOneWidget);
    expect(find.byKey(const ValueKey('share_scheme')), findsOneWidget);
    expect(find.byKey(const ValueKey('share_offices')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('share_scheme')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('share_import')));
    await tester.pumpAndSettle();
    expect((got!.favourites, got!.scheme), (true, false));
  });
}
