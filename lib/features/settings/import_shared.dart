/// "Import shared data": reads a share pack (the PO_Sorting_data .xlsx
/// another user exported) and adds its office changes, villages, edited hub
/// tables, favourites and scheme to this phone.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/files.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/app_services.dart';
import '../../data/directory_builder.dart' show NameCorrection, OfficeData;
import '../../data/import/scheme_import.dart';
import '../../data/import/scheme_io.dart';
import '../../data/import/table_reader.dart';
import '../../data/models/scheme.dart';
import '../../data/nsh.dart';
import '../../data/villages.dart';
import 'export_all.dart';
import 'office_editor.dart';
import 'village_editor.dart';

/// One office change in a share pack.
class SharedOfficeChange {
  const SharedOfficeChange(this.before, this.after);

  final OfficeData? before;
  final OfficeData? after;
}

class SharedData {
  SharedData({
    this.date = '',
    this.officeChanges = const [],
    this.renames = const [],
    this.villages = const [],
    this.tables = const {},
    this.editedTables = const {},
    this.favourites = const [],
    this.schemeName = '',
    this.schemeRules = const [],
    this.schemeAir = const [],
    this.schemeDmsl = const [],
  });

  final String date;
  final List<SharedOfficeChange> officeChanges;

  /// Name fixes: {pin, type, old, new} (as Settings.officeFixes).
  final List<Map<String, Object?>> renames;
  final List<VillageList> villages;

  /// Hub tables in the file, and the ones the sender had edited.
  final Map<HubTableKind, List<List<String>>> tables;
  final Set<HubTableKind> editedTables;
  final List<({int pin, String office, String note})> favourites;
  final String schemeName;
  final List<List<String>> schemeRules;
  final List<List<String>> schemeAir;
  final List<List<String>> schemeDmsl;

  int get villageCount => villages.fold(0, (n, v) => n + v.villages.length);
  int get officeCount => officeChanges.length + renames.length;
  bool get hasScheme => schemeRules.length > 1;

  /// Nothing to import apart from (maybe) hub tables; see [ShareOffer].
  bool get isEmpty => officeCount == 0 && villageCount == 0 && favourites.isEmpty && !hasScheme;
}

/// Reads a share pack; null when [t] is not one.
SharedData? readSharedData(TableFile t) {
  final s = t.sheets;
  final about = s['About'];
  final isPack = (about != null && about.isNotEmpty && about.first.isNotEmpty && about.first.first == kSharePackMarker) || s.containsKey('Office_changes');
  if (!isPack) return null;
  String aboutValue(String key) => about?.where((r) => r.length > 1 && r[0] == key).firstOrNull?[1] ?? '';
  List<List<String>> body(String name) => (s[name] ?? const []).skip(1).where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
  String at(List<String> r, int i) => i < r.length ? r[i].trim() : '';

  OfficeData? office(List<String> r, int from) {
    final pin = int.tryParse(at(r, from));
    final name = at(r, from + 1);
    if (pin == null || name.isEmpty) return null;
    return OfficeData(
      pincode: pin,
      name: name,
      type: at(r, from + 2),
      delivery: at(r, from + 3).toLowerCase() != 'non-delivery',
      district: at(r, from + 4),
      state: at(r, from + 5),
    );
  }

  final changes = <SharedOfficeChange>[];
  final renames = <Map<String, Object?>>[];
  for (final r in body('Office_changes')) {
    final now = office(r, 1), was = office(r, 7);
    switch (at(r, 0).toLowerCase()) {
      case 'added' when now != null:
        changes.add(SharedOfficeChange(null, now));
      case 'removed' when now != null:
        changes.add(SharedOfficeChange(now, null));
      case 'changed' when now != null && was != null:
        changes.add(SharedOfficeChange(was, now));
      case 'renamed' when now != null && was != null:
        renames.add({'pin': now.pincode, 'type': now.type, 'old': was.name, 'new': now.name});
    }
  }

  final byOffice = <String, VillageList>{};
  for (final r in body('Villages')) {
    final pin = int.tryParse(at(r, 0));
    final name = at(r, 1), v = at(r, 2);
    if (pin == null || name.isEmpty || v.isEmpty) continue;
    final k = '$pin|$name';
    final old = byOffice[k];
    byOffice[k] = VillageList(pin: pin, office: name, villages: [...?old?.villages, v]);
  }

  final edited = aboutValue('Edited hub tables').split(',').map((x) => x.trim()).toSet();
  final tables = <HubTableKind, List<List<String>>>{};
  final editedTables = <HubTableKind>{};
  for (final e in kHubSheets.entries) {
    final rows = s[e.value];
    if (rows == null || rows.length < 2) continue;
    tables[e.key] = rows;
    if (edited.contains(e.value)) editedTables.add(e.key);
  }

  return SharedData(
    date: aboutValue('Date'),
    officeChanges: changes,
    renames: renames,
    villages: byOffice.values.toList(),
    tables: tables,
    editedTables: editedTables,
    favourites: [
      for (final r in body('Favourites'))
        if (int.tryParse(at(r, 0)) != null) (pin: int.parse(at(r, 0)), office: at(r, 1), note: at(r, 4)),
    ],
    schemeName: aboutValue('Scheme'),
    schemeRules: s['Scheme_Rules'] ?? const [],
    schemeAir: s['Scheme_AirCodes'] ?? const [],
    schemeDmsl: s['Scheme_DMSL'] ?? const [],
  );
}

/// What to take from a share pack.
class ShareChoice {
  ShareChoice({this.offices = true, this.villages = true, Set<HubTableKind>? tables, this.favourites = true, this.scheme = true}) : tables = tables ?? {};

  bool offices, villages, favourites, scheme;

  /// Hub tables to take (they replace this phone's copy).
  final Set<HubTableKind> tables;
}

/// How a share pack compares with this phone.
class ShareOffer {
  const ShareOffer({required this.tables, required this.schemeSame});

  /// Hub tables in the file that differ from this phone's.
  final Set<HubTableKind> tables;

  /// The file's scheme has the same rules as the active scheme here.
  final bool schemeSame;

  /// Ticked at first: the sender's own edits, and a scheme not here yet.
  ShareChoice choice(SharedData d) => ShareChoice(tables: tables.intersection(d.editedTables), scheme: !schemeSame);
}

NshTable? _table(List<List<String>> rows) {
  try {
    final t = NshTable.parse(Uint8List.fromList(utf8.encode(writeCsv(rows))));
    return t.hubs.isEmpty ? null : t;
  } catch (_) {
    return null;
  }
}

ShareOffer shareOffer(AppServices services, SharedData d) {
  final tables = <HubTableKind>{};
  for (final e in d.tables.entries) {
    final t = _table(e.value);
    if (t != null && t.toCsv() != services.table(e.key)?.toCsv()) tables.add(e.key);
  }
  final a = services.active;
  final same = a != null && d.hasScheme && writeCsv(bagRulesTable(a.bagResolver.rules, a.bags)) == writeCsv(d.schemeRules);
  return ShareOffer(tables: tables, schemeSame: same);
}

/// What an import added.
class ShareResult {
  int offices = 0, villages = 0, tables = 0, favourites = 0;
  bool scheme = false;
}

/// Adds the chosen parts of [d] to this phone. Office changes already made
/// here (or whose office is not in this directory) are skipped; villages
/// and favourites are merged; edited hub tables replace this phone's copy;
/// the scheme is added as a new scheme and made active.
Future<ShareResult> applySharedData(AppServices services, Settings settings, SharedData d, ShareChoice c) async {
  final out = ShareResult();
  if (c.offices) {
    Future<bool> has(OfficeData o) async => (await services.directory.officesForPin(o.pincode)).any((x) => x.officeName == o.name && x.officeType == o.type);
    for (final e in d.officeChanges) {
      final before = e.before, after = e.after;
      if (before == null) {
        if (await has(after!)) continue;
      } else if (!await has(before)) {
        continue;
      } else if (after != null && before.sameAs(after)) {
        continue;
      }
      await saveOfficeChange(settings, services, before, after);
      out.offices++;
    }
    final fixes = [...settings.officeFixes];
    final add = [
      for (final r in d.renames)
        if (!fixes.any((f) => f['pin'] == r['pin'] && f['type'] == r['type'] && f['old'] == r['old'])) r,
    ];
    if (add.isNotEmpty) {
      settings.officeFixes = [...fixes, ...add];
      out.offices += await services.renameOffices([
        for (final r in add)
          NameCorrection(pincode: r['pin'] as int, officeType: r['type'] as String, oldName: r['old'] as String, newName: r['new'] as String),
      ]);
    }
  }
  if (c.villages) {
    for (final v in d.villages) {
      final mine = services.villages.of(v.pin, v.office);
      final merged = [...mine, ...v.villages];
      final before = mine.length;
      saveVillages(settings, services, v.pin, v.office, merged);
      out.villages += services.villages.of(v.pin, v.office).length - before;
    }
  }
  for (final k in c.tables) {
    final t = d.tables[k] == null ? null : _table(d.tables[k]!);
    if (t == null) continue;
    settings.setTableCsv(k.prefsKey, t.toCsv());
    services.setTable(k, t);
    out.tables++;
  }
  if (c.favourites) {
    final have = await services.user.favourites();
    for (final f in d.favourites) {
      if (have.any((h) => h.pin == f.pin && h.officeName == f.office)) continue;
      final o = (await services.directory.officesForPin(f.pin)).where((x) => x.officeName == f.office).firstOrNull;
      if (o != null) {
        await services.user.addFavourite(o, note: f.note);
      } else if (have.any((h) => h.pin == f.pin && h.officeName.isEmpty)) {
        continue; // office not here; the PIN is already a favourite
      } else {
        await services.user.addFavouritePin(f.pin, note: f.note);
      }
      out.favourites++;
    }
    if (out.favourites > 0) services.touchRecents();
  }
  if (c.scheme && d.hasScheme) {
    final r = autoImport<BagRule>(d.schemeRules, ImportKind.bagRules);
    if (r.rules.isNotEmpty) {
      final name = d.schemeName.isEmpty ? 'Shared scheme' : d.schemeName;
      final id = await services.schemes.saveScheme(
        Scheme(name: '$name (shared${d.date.isEmpty ? '' : ' ${d.date}'})', notes: 'Imported from shared data'),
        r.rules,
        completeBags(r.rules, r.bags, kBagPalette.map(colourToHex).toList()),
      );
      if (d.schemeAir.length > 1) await services.schemes.replaceAirCodes(id, autoImport<AirCodeRule>(d.schemeAir, ImportKind.airCodes).rules);
      if (d.schemeDmsl.length > 1) {
        await services.schemes.addDmslVersion(id, 'Shared ${d.date}'.trim(), null, autoImport<HubRule>(d.schemeDmsl, ImportKind.dmsl).rules);
      }
      await services.reloadActive();
      out.scheme = true;
    }
  }
  return out;
}

/// Picks a share pack, shows what is in it and imports the chosen parts.
Future<void> importSharedData(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final services = context.services;
  final settings = context.settings;
  final messenger = ScaffoldMessenger.of(context);
  final f = await pickTableFile();
  if (f == null || !context.mounted) return;
  SharedData? d;
  try {
    d = readSharedData(readTable(f.bytes, f.name));
  } catch (_) {
    d = null;
  }
  final offer = d == null ? null : shareOffer(services, d);
  if (d == null || (d.isEmpty && offer!.tables.isEmpty)) {
    messenger.showSnackBar(SnackBar(content: Text(d == null ? l.shareNotPack : l.shareEmpty)));
    return;
  }
  final choice = await showDialog<ShareChoice>(
    context: context,
    builder: (_) => ShareImportDialog(data: d!, offer: offer!, fileName: f.name),
  );
  if (choice == null) return;
  final r = await applySharedData(services, settings, d, choice);
  messenger.showSnackBar(SnackBar(content: Text(l.shareImported(r.offices, r.villages, r.tables, r.favourites) + (r.scheme ? '\n${l.shareSchemeAdded}' : ''))));
}

class ShareImportDialog extends StatefulWidget {
  const ShareImportDialog({super.key, required this.data, required this.offer, required this.fileName});

  final SharedData data;
  final ShareOffer offer;
  final String fileName;

  @override
  State<ShareImportDialog> createState() => _ShareImportDialogState();
}

class _ShareImportDialogState extends State<ShareImportDialog> {
  late final _c = widget.offer.choice(widget.data);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = widget.data;
    Widget row(String key, String title, String sub, bool value, ValueChanged<bool> set) => CheckboxListTile(
      key: ValueKey('share_$key'),
      contentPadding: EdgeInsets.zero,
      value: value,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(sub),
      onChanged: (v) => setState(() => set(v ?? false)),
    );
    return AlertDialog(
      title: Text(l.shareImportTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text([widget.fileName, if (d.date.isNotEmpty) d.date].join(' · '), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            if (d.officeCount > 0) row('offices', l.officeFixes, l.shareNOffices(d.officeCount), _c.offices, (v) => _c.offices = v),
            if (d.villageCount > 0) row('villages', l.villagesMine, l.shareNVillages(d.villageCount), _c.villages, (v) => _c.villages = v),
            for (final k in widget.offer.tables)
              row(
                'table_${k.name}',
                '${l.shareTable} ${kHubSheets[k]!.replaceAll('_', ' ')}',
                d.editedTables.contains(k) ? l.shareTableEdited : l.shareTableDiffers,
                _c.tables.contains(k),
                (v) => v ? _c.tables.add(k) : _c.tables.remove(k),
              ),
            if (d.favourites.isNotEmpty) row('favourites', l.favourites, l.shareNFavourites(d.favourites.length), _c.favourites, (v) => _c.favourites = v),
            if (d.hasScheme)
              row(
                'scheme',
                l.shareScheme,
                [
                  l.shareSchemeSub(d.schemeName.isEmpty ? '—' : d.schemeName, d.schemeRules.length - 1),
                  if (widget.offer.schemeSame) l.shareSchemeSame,
                ].join(' · '),
                _c.scheme,
                (v) => _c.scheme = v,
              ),
            const SizedBox(height: 8),
            Text(l.shareImportHint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(key: const ValueKey('share_import'), onPressed: () => Navigator.pop(context, _c), child: Text(l.shareImportGo)),
      ],
    );
  }
}
