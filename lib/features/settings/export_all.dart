/// "Export all my data": the user's schemes (lines, rules, air codes, DMSL),
/// hub tables (NSH, RMS L1, NPH, RMS NSH), office changes, villages and
/// favourites, as spreadsheet files shared through the Android share sheet.
/// The PO_Sorting_data file is also a share pack: another user imports it
/// with "Import shared data" (see import_shared.dart).
library;

import 'dart:typed_data';

import '../../core/constants.dart';
import '../../core/fuzzy.dart';
import '../../core/settings.dart';
import '../../data/app_services.dart';
import '../../data/directory_builder.dart' show OfficeData, OfficeEdit;
import '../../data/import/scheme_io.dart';
import '../../data/import/table_reader.dart';
import '../../data/models/office.dart';
import '../../data/models/scheme.dart';
import '../../data/nsh.dart';
import '../../data/villages.dart';

/// First cell of the About sheet; marks a share pack.
const kSharePackMarker = 'PO Sorting shared data';

/// Sheet name of each hub table in the share pack.
const kHubSheets = {HubTableKind.nsh: 'NSH', HubTableKind.l1: 'RMS_L1', HubTableKind.nph: 'NPH', HubTableKind.rmsNsh: 'RMS_NSH'};

String _d(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

/// File name of the share pack made on [now].
String sharePackName(DateTime now) => 'PO_Sorting_data_${_d(now)}.xlsx';

/// Header of the Offices sheet (full office list of the user's area).
const kOfficesHeader = [
  'PIN', 'Office', 'Type', 'Account office (SO / HO)', 'Delivery', 'Taluk', 'Division', 'District', 'State', //
  'Villages', 'Line / Bag', 'Position', 'Status', 'Was PIN', 'Was office', //
];

/// PINs of the user's area: exact TD PINs (and short TD ranges) of the
/// active scheme, plus every PIN the user changed, added villages or
/// favourites to.
Future<List<int>> areaPins(AppServices services, Settings settings, List<OfficeEdit> edits) async {
  final pins = <int>{};
  for (final r in services.active?.bagResolver.rules ?? const <BagRule>[]) {
    if (r.category != null && r.category != 'TD') continue;
    final m = r.match;
    if (m.type == RuleType.exact && m.pin != null) pins.add(m.pin!);
    if (m.type == RuleType.range && m.pinFrom != null && m.pinTo != null && m.pinTo! - m.pinFrom! <= 200) {
      for (var p = m.pinFrom!; p <= m.pinTo!; p++) {
        pins.add(p);
      }
    }
    if (m.type == RuleType.prefix && (m.prefix?.length ?? 0) == 6) pins.add(int.parse(m.prefix!));
  }
  // TD office rules ("Sampaje" on Puttur line): their PINs, taken from
  // same-named offices in the districts already in the area.
  final named = [
    for (final r in services.active?.bagResolver.rules ?? const <BagRule>[])
      if ((r.category == null || r.category == 'TD') && r.match.type == RuleType.office && (r.match.officeNorm ?? '').isNotEmpty) r.match.officeNorm!,
  ];
  if (named.isNotEmpty) {
    final districts = <String>{};
    for (final p in pins.take(400)) {
      for (final o in await services.directory.officesForPin(p)) {
        districts.add(o.district);
      }
    }
    for (final n in named) {
      for (final h in await services.directory.search(n, limit: 8)) {
        if (normalizePlace(h.office.officeName) == n && (districts.isEmpty || districts.contains(h.office.district))) pins.add(h.office.pincode);
      }
    }
  }
  for (final e in edits) {
    if (e.before != null) pins.add(e.before!.pincode);
    if (e.after != null) pins.add(e.after!.pincode);
  }
  for (final f in settings.officeFixes) {
    pins.add((f['pin'] as num).toInt());
  }
  for (final v in settings.villages.map(VillageList.fromJson)) {
    pins.add(v.pin);
  }
  for (final f in await services.user.favourites()) {
    pins.add(f.pin);
  }
  pins.removeWhere((p) => p < 110000 || p > 999999);
  return pins.toList()..sort();
}

/// Every office of the user's area as it is now on this phone (with the
/// user's additions and changes), then the offices the user removed.
Future<List<List<String>>> officesSheet(AppServices services, Settings settings, List<OfficeEdit> edits) async {
  final category = services.categories.contains('TD') ? 'TD' : settings.category;
  final engine = services.engine;
  final rows = <List<String>>[kOfficesHeader];
  const heads = {'SO', 'HO', 'PO'};
  for (final pin in await areaPins(services, settings, edits)) {
    final offs = await services.directory.officesForPin(pin);
    final head = offs.where((o) => heads.contains(o.officeType)).firstOrNull;
    for (final o in offs) {
      final d = OfficeData(pincode: o.pincode, name: o.officeName, type: o.officeType, delivery: o.delivery, district: o.district, state: o.state);
      final edit = edits.where((e) => e.after != null && e.after!.sameOffice(d)).firstOrNull;
      final status = edit == null ? 'Original' : (edit.before == null ? 'Added' : 'Changed');
      final r = engine.resolveOffice(o, category: category);
      rows.add(_officeRow(o, head, services.villages.of(o.pincode, o.officeName), r.bag?.label ?? '', r.bagRule?.section ?? '', status, edit?.before));
    }
  }
  for (final e in edits.where((e) => e.after == null)) {
    final b = e.before!;
    rows.add(['${b.pincode}', b.name, b.type, '', b.delivery ? 'Delivery' : 'Non-delivery', '', '', b.district, b.state, '', '', '', 'Removed', '', '']);
  }
  return rows;
}

List<String> _officeRow(Office o, Office? head, List<String> villages, String bag, String position, String status, OfficeData? was) => [
  '${o.pincode}', o.officeName, o.officeType, //
  head == null || identical(head, o) || head.officeName == o.officeName ? '' : '${head.officeName} ${head.officeType}',
  o.delivery ? 'Delivery' : 'Non-delivery', o.taluk, o.division, o.district, o.state, //
  villages.join(', '), bag, position, status, //
  was == null ? '' : '${was.pincode}', was?.name ?? '',
];

/// Every scheme as its own file, plus the share pack.
Future<Map<String, Object>> exportAllData(AppServices services, Settings settings, {DateTime? now}) async {
  final when = now ?? DateTime.now();
  final files = <String, Object>{};
  for (final s in await services.schemes.schemes()) {
    files.addAll(await exportScheme(services.schemes, s, xlsx: true));
  }
  files[sharePackName(when)] = await buildSharePack(services, settings, now: when);
  return files;
}

/// The share pack: one .xlsx with all of this phone's data that another
/// user can import (and that opens in Excel / Google Sheets).
Future<Uint8List> buildSharePack(AppServices services, Settings settings, {DateTime? now}) async {
  final when = now ?? DateTime.now();
  final edited = [
    for (final e in kHubSheets.entries)
      if (settings.tableCsv(e.key.prefsKey) != null) e.value,
  ];
  final active = services.active;
  final scheme = active == null || active.scheme.isSample ? null : active;
  final sheets = <String, List<List<String>>>{
    'About': [
      [kSharePackMarker],
      ['App version', kAppVersion],
      ['Date', _d(when)],
      ['Edited hub tables', edited.join(', ')],
      [
        'Sheets',
        'Offices = every office of my area now (Status: Original / Added / Changed / Removed). Office_changes = only my changes. Villages, Favourites, hub tables (NSH, RMS_L1, NPH, RMS_NSH), Scheme_* = lines and rules.',
      ],
      ['Scheme', scheme?.scheme.name ?? ''],
      ['Import', 'Open PO Sorting → More → Share & backup data → Import a data file, and pick this file.'],
      ['Google Sheets', 'To edit in Google Sheets and import again: File → Download → Microsoft Excel (.xlsx). Keep the sheet names.'],
    ],
    for (final e in kHubSheets.entries)
      if (services.table(e.key) != null) e.value: services.table(e.key)!.toRows(),
  };
  final edits = [for (final e in settings.officeEdits) OfficeEdit.fromJson(e)];
  sheets['Offices'] = await officesSheet(services, settings, edits);
  List<String> office(OfficeData? o) =>
      o == null ? ['', '', '', '', '', ''] : ['${o.pincode}', o.name, o.type, o.delivery ? 'Delivery' : 'Non-delivery', o.district, o.state];
  sheets['Office_changes'] = [
    ['Change', 'PIN', 'Office', 'Type', 'Delivery', 'District', 'State', 'Was PIN', 'Was office', 'Was type', 'Was delivery', 'Was district', 'Was state'],
    for (final e in edits)
      [
        e.before == null
            ? 'Added'
            : e.after == null
            ? 'Removed'
            : 'Changed',
        ...office(e.after ?? e.before),
        ...office(e.after == null ? null : e.before),
      ],
    for (final f in settings.officeFixes)
      ['Renamed', '${f['pin']}', '${f['new']}', '${f['type']}', '', '', '', '${f['pin']}', '${f['old']}', '${f['type']}', '', '', ''],
  ];
  sheets['Villages'] = [
    ['PIN', 'Office', 'Village'],
    for (final e in settings.villages.map(VillageList.fromJson))
      for (final v in e.villages) ['${e.pin}', e.office, v],
  ];
  final favs = await services.user.favourites();
  sheets['Favourites'] = [
    ['PIN', 'Office', 'District', 'State', 'Note'],
    for (final f in favs) ['${f.pin}', f.officeName, f.district, f.state, f.note],
  ];
  if (scheme != null) {
    sheets['Scheme_Rules'] = bagRulesTable(scheme.bagResolver.rules, scheme.bags);
    if (scheme.airResolver.rules.isNotEmpty) sheets['Scheme_AirCodes'] = airCodesTable(scheme.airResolver.rules);
    if (scheme.hubResolver.rules.isNotEmpty) sheets['Scheme_DMSL'] = dmslTable(scheme.hubResolver.rules);
  }
  return writeXlsx(sheets);
}
