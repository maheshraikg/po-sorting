/// "Export all my data": the user's schemes (lines, rules, air codes, DMSL),
/// hub tables (NSH, RMS L1, NPH, RMS NSH), office changes and favourites,
/// as spreadsheet files shared through the Android share sheet.
library;

import '../../core/settings.dart';
import '../../data/app_services.dart';
import '../../data/directory_builder.dart' show OfficeData, OfficeEdit;
import '../../data/import/scheme_io.dart';
import '../../data/import/table_reader.dart';
import '../../data/nsh.dart';

String _d(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

Future<Map<String, Object>> exportAllData(AppServices services, Settings settings, {DateTime? now}) async {
  final date = _d(now ?? DateTime.now());
  final files = <String, Object>{};
  for (final s in await services.schemes.schemes()) {
    files.addAll(await exportScheme(services.schemes, s, xlsx: true));
  }
  final sheets = <String, List<List<String>>>{
    for (final (k, name) in [
      (HubTableKind.nsh, 'NSH'),
      (HubTableKind.l1, 'RMS_L1'),
      (HubTableKind.nph, 'NPH'),
      (HubTableKind.rmsNsh, 'RMS_NSH'),
    ])
      if (services.table(k) != null) name: services.table(k)!.toRows(),
  };
  final edits = [for (final e in settings.officeEdits) OfficeEdit.fromJson(e)];
  List<String> office(OfficeData? o) =>
      o == null ? ['', '', '', '', '', ''] : ['${o.pincode}', o.name, o.type, o.delivery ? 'Delivery' : 'Non-delivery', o.district, o.state];
  sheets['Office_changes'] = [
    ['Change', 'PIN', 'Office', 'Type', 'Delivery', 'District', 'State', 'Was PIN', 'Was office', 'Was type', 'Was delivery', 'Was district', 'Was state'],
    for (final e in edits) [e.before == null ? 'Added' : e.after == null ? 'Removed' : 'Changed', ...office(e.after ?? e.before), ...office(e.after == null ? null : e.before)],
    for (final f in settings.officeFixes) ['Renamed', '${f['pin']}', '${f['new']}', '${f['type']}', '', '', '', '${f['pin']}', '${f['old']}', '${f['type']}', '', '', ''],
  ];
  final favs = await services.user.favourites();
  sheets['Favourites'] = [
    ['PIN', 'Office', 'District', 'State', 'Note'],
    for (final f in favs) ['${f.pin}', f.officeName, f.district, f.state, f.note],
  ];
  files['PO_Sorting_data_$date.xlsx'] = writeXlsx(sheets);
  return files;
}
