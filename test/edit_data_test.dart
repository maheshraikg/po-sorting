import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/data/directory_builder.dart' show OfficeData, OfficeEdit;
import 'package:sorting_sahayak/data/import/scheme_io.dart';
import 'package:sorting_sahayak/data/models/office.dart';
import 'package:sorting_sahayak/data/models/scheme.dart';
import 'package:sorting_sahayak/data/nsh.dart';
import 'package:sorting_sahayak/data/resolver.dart';
import 'package:sorting_sahayak/features/schemes/scheme_editor.dart';
import 'package:sorting_sahayak/features/settings/edit_data_screen.dart';
import 'package:sorting_sahayak/features/settings/nsh_editor_screen.dart';
import 'package:sorting_sahayak/features/settings/office_editor.dart';
import 'package:sorting_sahayak/features/settings/office_fixes.dart';

import 'helpers/app_harness.dart';

Future<Harness> _setUp(WidgetTester tester) async {
  final h = await Harness.create(tester, sample: false);
  await tester.runAsync(() async {
    await installDefaultScheme(h.services.schemes, (p) async => File(p).readAsBytesSync());
    await h.services.reloadActive();
  });
  h.services.nsh = NshTable.parse(File(kNshAsset).readAsBytesSync());
  return h;
}

void main() {
  testWidgets('Edit my data lists every editor', (tester) async {
    final h = await _setUp(tester);
    await tester.pumpWidget(h.wrap(const EditDataScreen()));
    await settle(tester);
    for (final k in ['lines', 'rules', 'air', 'nsh', 'l1', 'nph', 'offices', 'schemes']) {
      await tester.scrollUntilVisible(find.byKey(ValueKey('edit_$k')), 100, scrollable: find.byType(Scrollable).first);
      expect(find.byKey(ValueKey('edit_$k')), findsOneWidget);
    }
  });

  testWidgets('air codes: add one, edit it, delete it', (tester) async {
    final h = await _setUp(tester);
    final id = h.services.active!.scheme.id!;
    await tester.pumpWidget(h.wrap(SchemeEditor(schemeId: id)));
    await settle(tester, rounds: 6);
    await tester.tap(find.textContaining('Air codes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_air_code')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<RuleType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exact PIN').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('air_dialog_a')), '574201');
    await tester.enterText(find.byKey(const ValueKey('air_dialog_code')), 'ixe');
    await tester.tap(find.byKey(const ValueKey('air_dialog_save')));
    await settle(tester, rounds: 6);
    String? code() => h.services.active!.airResolver.resolve(const ResolveQuery(pin: 574201))?.rule.airCode;
    expect(code(), 'IXE');
    final rules = await tester.runAsync(() => h.services.schemes.airCodes(id));
    final mine = rules!.firstWhere((r) => r.airCode == 'IXE');
    await tester.runAsync(() => h.services.schemes.upsertAirCode(id, AirCodeRule(id: mine.id, match: mine.match, airCode: 'BLR')));
    await tester.runAsync(h.services.reloadActive);
    expect(code(), 'BLR');
    await tester.runAsync(() => h.services.schemes.deleteAirCode(mine.id!));
    await tester.runAsync(h.services.reloadActive);
    expect(code(), isNull);
  });

  testWidgets('NSH hubs: edit a hub series; reset brings back the sheet', (tester) async {
    final h = await _setUp(tester);
    await tester.pumpWidget(h.wrap(const NshEditorScreen()));
    await settle(tester);
    final i = h.services.nsh!.hubs.indexWhere((x) => x.name == 'MANGALORE NSH');
    await tester.scrollUntilVisible(find.byKey(ValueKey('nsh_hub_$i')), 300, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.byKey(ValueKey('nsh_hub_$i')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('nsh_dialog_series')), '574-576, 577999');
    await tester.tap(find.byKey(const ValueKey('nsh_dialog_save')));
    await tester.pumpAndSettle();
    expect(h.services.nsh!.resolve('577999')!.hub.name, 'MANGALORE NSH');
    expect(h.settings.nshCsv, contains('577999'));
    expect(NshTable.parse(File(kNshAsset).readAsBytesSync()).resolve('577999'), isNull);
  });

  testWidgets('office name fix: saved, survives a fresh directory, can be restored', (tester) async {
    final h = await _setUp(tester);
    h.settings.officeFixes = [
      {'pin': 574202, 'type': 'BO', 'old': 'Darbe', 'new': 'Darbe Padavu'},
    ];
    await tester.runAsync(() => applyOfficeFixes(h.settings, h.services));
    final offices = await tester.runAsync(() => h.services.directory.officesInRange(574202, 574202));
    expect(offices!.map((o) => o.officeName), contains('Darbe Padavu'));
    // Running again (next start) changes nothing and keeps the name.
    await tester.runAsync(() => applyOfficeFixes(h.settings, h.services));
    final again = await tester.runAsync(() => h.services.directory.officesInRange(574202, 574202));
    expect(again!.where((o) => o.officeName == 'Darbe Padavu').length, 1);
    await tester.pumpWidget(h.wrap(const OfficeFixesScreen()));
    await tester.pump();
    expect(find.text('Darbe Padavu BO'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await settle(tester);
    expect(h.settings.officeFixes, isEmpty);
    final back = await tester.runAsync(() => h.services.directory.officesInRange(574202, 574202));
    expect(back!.map((o) => o.officeName), contains('Darbe'));
  });

  testWidgets('offices: add, edit (name, PIN, type, delivery, district), remove, undo; kept after restart', (tester) async {
    final h = await _setUp(tester);
    final s = h.settings, sv = h.services;
    Future<List<Office>> at(int pin) async => (await tester.runAsync(() => sv.directory.officesForPin(pin)))!;
    final darbe = (await at(574202)).firstWhere((o) => o.officeName == 'Darbe');
    // Edit everything.
    await tester.runAsync(() => saveOfficeChange(s, sv, officeData(darbe),
        const OfficeData(pincode: 574203, name: 'Darbe Padavu', type: 'SO', delivery: false, district: 'DK', state: 'Karnataka')));
    expect((await at(574202)).any((o) => o.officeName == 'Darbe'), isFalse);
    final moved = (await at(574203)).firstWhere((o) => o.officeName == 'Darbe Padavu');
    expect((moved.officeType, moved.delivery, moved.district), ('SO', false, 'DK'));
    // Edit it again: still one change, from the original.
    await tester.runAsync(() => saveOfficeChange(s, sv, officeData(moved), OfficeData(pincode: 574203, name: 'Darbe P', type: 'SO', delivery: false, district: 'DK', state: 'Karnataka')));
    expect(s.officeEdits, hasLength(1));
    expect(OfficeEdit.fromJson(s.officeEdits.single).before!.name, 'Darbe');
    // Add one, remove another.
    await tester.runAsync(() => saveOfficeChange(s, sv, null, const OfficeData(pincode: 574202, name: 'Kemminje', type: 'BO', district: 'Dakshina Kannada', state: 'Karnataka')));
    final kabaka = (await at(574220)).first;
    await tester.runAsync(() => saveOfficeChange(s, sv, officeData(kabaka), null));
    expect((await at(574202)).map((o) => o.officeName), contains('Kemminje'));
    expect(await at(574220), isEmpty);
    expect(s.officeEdits, hasLength(3));
    // Next start: applying again changes nothing.
    await tester.runAsync(() => applyOfficeEditsOnStart(s, sv));
    expect((await at(574202)).where((o) => o.officeName == 'Kemminje'), hasLength(1));
    // The changes screen lists them; undo the removal.
    await tester.pumpWidget(h.wrap(const OfficeFixesScreen()));
    await tester.pump();
    expect(find.byKey(const ValueKey('office_change_2')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('office_change_2')), matching: find.text('Restore')));
    await settle(tester);
    expect((await at(574220)).map((o) => o.officeName), contains(kabaka.officeName));
    expect(s.officeEdits, hasLength(2));
  });

  testWidgets('office dialog: change the name and PIN from the Sort result pencil', (tester) async {
    final h = await _setUp(tester);
    final darbe = (await tester.runAsync(() => h.services.directory.officesForPin(574202)))!.firstWhere((o) => o.officeName == 'Darbe');
    await tester.pumpWidget(h.wrap(Builder(builder: (c) => Scaffold(body: Center(child: TextButton(onPressed: () => editOffice(c, office: darbe), child: const Text('go')))))));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('office_name_field')), 'Darbe Junction');
    await tester.enterText(find.byKey(const ValueKey('office_pin_field')), '574299');
    await tester.tap(find.byKey(const ValueKey('office_save')));
    await settle(tester, rounds: 6);
    final now = (await tester.runAsync(() => h.services.directory.officesForPin(574299)))!;
    expect(now.map((o) => o.officeName), contains('Darbe Junction'));
    expect(find.text('Saved Darbe Junction'), findsOneWidget);
  });
}
