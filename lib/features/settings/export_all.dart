/// "Export all my data": the user's schemes (lines, rules, air codes, DMSL),
/// hub tables (NSH, RMS L1, NPH, RMS NSH), office changes, villages and
/// favourites, as spreadsheet files shared through the Android share sheet.
/// The PO_Sorting_data file is also a share pack: another user imports it
/// with "Import shared data" (see import_shared.dart).
library;

import '../../core/constants.dart';
import '../../core/settings.dart';
import '../../data/app_services.dart';
import '../../data/directory_builder.dart' show OfficeData, OfficeEdit;
import '../../data/import/scheme_io.dart';
import '../../data/import/table_reader.dart';
import '../../data/nsh.dart';
import '../../data/villages.dart';

/// First cell of the About sheet; marks a share pack.
const kSharePackMarker = 'PO Sorting shared data';

/// Sheet name of each hub table in the share pack.
const kHubSheets = {HubTableKind.nsh: 'NSH', HubTableKind.l1: 'RMS_L1', HubTableKind.nph: 'NPH', HubTableKind.rmsNsh: 'RMS_NSH'};

String _d(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

/// File name of the share pack made on [now].
String sharePackName(DateTime now) => 'PO_Sorting_data_${_d(now)}.xlsx';

Future<Map<String, Object>> exportAllData(AppServices services, Settings settings, {DateTime? now}) async {
  final when = now ?? DateTime.now();
  final files = <String, Object>{};
  for (final s in await services.schemes.schemes()) {
    files.addAll(await exportScheme(services.schemes, s, xlsx: true));
  }
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
      ['Scheme', scheme?.scheme.name ?? ''],
      ['Import', 'Open PO Sorting → More → Edit my data → Import shared data, and pick this file.'],
    ],
    for (final e in kHubSheets.entries)
      if (services.table(e.key) != null) e.value: services.table(e.key)!.toRows(),
  };
  final edits = [for (final e in settings.officeEdits) OfficeEdit.fromJson(e)];
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
  files[sharePackName(when)] = writeXlsx(sheets);
  return files;
}
