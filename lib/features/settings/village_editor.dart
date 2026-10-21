/// Villages under a post office: the user adds and removes them; searching
/// a village finds its office and PIN.
library;

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/files.dart';
import '../../core/fuzzy.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/settings.dart';
import '../../core/widgets.dart';
import '../../data/app_services.dart';
import '../../data/import/table_reader.dart';
import '../../data/village_import.dart';
import '../../data/villages.dart';

List<VillageList> _lists(Settings s) => [for (final j in s.villages) VillageList.fromJson(j)];

void _store(Settings settings, AppServices services, List<VillageList> lists) {
  settings.villages = [for (final l in lists) l.toJson()];
  services.villages = VillageBook(lists);
}

/// Loads the saved villages into search (on start).
void loadVillagesOnStart(Settings settings, AppServices services) {
  final lists = _lists(settings);
  if (lists.isNotEmpty) services.villages = VillageBook(lists);
}

/// Saves [villages] as the villages of office [name] / [pin].
void saveVillages(Settings settings, AppServices services, int pin, String name, List<String> villages) =>
    _store(settings, services, setVillages(_lists(settings), pin, name, villages));

/// Keeps villages with their office when it is renamed or its PIN changes.
void moveOfficeVillages(Settings settings, AppServices services, int fromPin, String fromName, int toPin, String toName) {
  final lists = _lists(settings);
  final moved = moveVillages(lists, fromPin, fromName, toPin, toName);
  if (!identical(moved, lists)) _store(settings, services, moved);
}

/// Splits typed text into village names: "Kodi, Hosur; Bela" → 3.
List<String> splitVillages(String text) => [
  for (final v in text.split(RegExp(r'[,;\n]')))
    if (v.trim().isNotEmpty) v.trim(),
];

/// Dialog to add / remove the villages of office [name] ([type]) with [pin].
/// Returns true if anything changed.
Future<bool> editVillages(BuildContext context, {required int pin, required String name, String type = ''}) async {
  final l = AppLocalizations.of(context);
  final settings = context.settings;
  final services = context.services;
  final messenger = ScaffoldMessenger.of(context);
  final start = services.villages.of(pin, name);
  final r = await showDialog<List<String>>(
    context: context,
    builder: (_) => _VillagesDialog(title: '${'$name $type'.trim()} · $pin', start: start),
  );
  if (r == null) return false;
  if (r.length == start.length && r.indexed.every((e) => start[e.$1] == e.$2)) return false;
  saveVillages(settings, services, pin, name, r);
  messenger.showSnackBar(SnackBar(content: Text(l.villagesSaved(r.length, name))));
  return true;
}

class _VillagesDialog extends StatefulWidget {
  const _VillagesDialog({required this.title, required this.start});

  final String title;
  final List<String> start;

  @override
  State<_VillagesDialog> createState() => _VillagesDialogState();
}

class _VillagesDialogState extends State<_VillagesDialog> {
  late final List<String> _v = [...widget.start];
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _add() {
    for (final v in splitVillages(_c.text)) {
      if (!_v.any((x) => x.toLowerCase() == v.toLowerCase())) _v.add(v);
    }
    _c.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(l.villages),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('village_field'),
                controller: _c,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l.villageAdd,
                  helperText: l.villageAddHint,
                  suffixIcon: IconButton(key: const ValueKey('village_add'), tooltip: l.villageAdd, icon: const Icon(Icons.add_circle), onPressed: _add),
                ),
                onSubmitted: (_) => _add(),
              ),
              const SizedBox(height: 12),
              if (_v.isEmpty) Text(l.villagesNone, style: TextStyle(color: cs.onSurfaceVariant)),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final v in _v)
                    InputChip(
                      key: ValueKey('village_chip_$v'),
                      label: Text(v),
                      onDeleted: () => setState(() => _v.remove(v)),
                      deleteButtonTooltipMessage: l.villageRemove,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          key: const ValueKey('villages_save'),
          onPressed: () {
            if (_c.text.trim().isNotEmpty) _add();
            Navigator.pop(context, _v);
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// "Villages: Kodi, Hosur" under an office, or null when it has none.
String? villagesLine(AppLocalizations l, List<String> villages) => villages.isEmpty ? null : '${l.villages}: ${villages.join(', ')}';

const kStarterVillagesAsset = 'assets/villages/hassan_villages.csv';

/// Adds [add] to the saved villages; returns how many villages were new.
int addVillageLists(Settings settings, AppServices services, List<VillageList> add) {
  var lists = _lists(settings);
  var book = VillageBook(lists);
  var before = lists.fold<int>(0, (n, e) => n + e.villages.length);
  final byOffice = <String, VillageList>{};
  for (final v in add) {
    final k = '${v.pin}|${v.office}';
    byOffice[k] = VillageList(pin: v.pin, office: v.office, villages: [...?byOffice[k]?.villages, ...v.villages]);
  }
  for (final v in byOffice.values) {
    lists = setVillages(lists, v.pin, v.office, [...book.of(v.pin, v.office), ...v.villages]);
  }
  _store(settings, services, lists);
  book = VillageBook(lists);
  final after = lists.fold<int>(0, (n, e) => n + e.villages.length);
  return after - before;
}

/// Rows "PIN | Office | Village" (the app's own Villages sheet / bundled list).
List<VillageList> villageListsFromRows(List<List<String>> rows) {
  if (rows.isEmpty) return const [];
  final h = [for (final c in rows.first) c.trim().toLowerCase()];
  final cPin = h.indexOf('pin'), cOffice = h.indexOf('office'), cVillage = h.indexOf('village');
  if (cPin < 0 || cOffice < 0 || cVillage < 0) return const [];
  return [
    for (final r in rows.skip(1))
      if (r.length > cVillage && int.tryParse(r[cPin].trim()) != null && r[cOffice].trim().isNotEmpty && r[cVillage].trim().isNotEmpty)
        VillageList(pin: int.parse(r[cPin].trim()), office: r[cOffice].trim(), villages: [r[cVillage].trim()]),
  ];
}

/// Adds the bundled village list once (first start after the update).
Future<void> seedVillages(Settings settings, AppServices services, Future<Uint8List> Function(String) loadAsset) async {
  if (settings.villagesSeeded) return;
  settings.villagesSeeded = true;
  try {
    final t = readTable(await loadAsset(kStarterVillagesAsset), 'villages.csv');
    addVillageLists(settings, services, villageListsFromRows(t.sheets.values.first));
  } catch (_) {
    // Missing asset: nothing to add.
  }
}

/// Picks a village sheet (a village directory "Village | PO | Account office
/// | Pincode", or the app's own Villages sheet) and adds its villages under
/// the matching offices.
Future<void> importVillageSheet(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final settings = context.settings;
  final services = context.services;
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context, rootNavigator: true);
  final f = await pickTableFile();
  if (f == null || !context.mounted) return;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(l.villagesMatching)),
          ],
        ),
      ),
    ),
  );
  var added = 0, missed = 0, found = false;
  try {
    final t = readTable(f.bytes, f.name);
    for (final name in [if (t.sheets.containsKey('Villages')) 'Villages', ...t.sheets.keys]) {
      final rows = t.sheets[name]!;
      final own = villageListsFromRows(rows);
      if (own.isNotEmpty) {
        added = addVillageLists(settings, services, own);
        found = true;
        break;
      }
      final sheet = readVillageSheet(rows);
      if (sheet.isEmpty) continue;
      final m = await matchVillages(services.directory, sheet);
      missed = m.where((x) => x.office == null).length;
      added = addVillageLists(settings, services, [
        for (final x in m)
          if (x.office != null) VillageList(pin: x.office!.pincode, office: x.office!.officeName, villages: [x.row.village]),
      ]);
      found = true;
      break;
    }
  } catch (_) {
    found = false;
  }
  nav.pop();
  messenger.showSnackBar(SnackBar(content: Text(found ? l.villagesImported(added, missed) : l.villagesNoSheet)));
}

/// Every office the user added villages to.
class VillagesScreen extends StatefulWidget {
  const VillagesScreen({super.key});

  @override
  State<VillagesScreen> createState() => _VillagesScreenState();
}

class _VillagesScreenState extends State<VillagesScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final all = _lists(context.settings)..sort((a, b) => a.pin != b.pin ? a.pin.compareTo(b.pin) : a.office.compareTo(b.office));
    final n = all.fold<int>(0, (n, e) => n + e.villages.length);
    final q = normalizePlace(_q);
    final lists = q.isEmpty
        ? all
        : [
            for (final e in all)
              if ('${e.pin}'.startsWith(q) || normalizePlace(e.office).contains(q) || e.villages.any((v) => normalizePlace(v).contains(q))) e,
          ];
    return Scaffold(
      appBar: AppBar(
        title: Text(l.villagesMine),
        actions: [
          IconButton(
            key: const ValueKey('villages_import'),
            tooltip: l.villagesImport,
            icon: const Icon(Icons.upload_file),
            onPressed: () => importVillageSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              key: const ValueKey('villages_search'),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.villagesSearch),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(all.isEmpty ? l.villagesHint : '${l.villagesCount(n, all.length)} · ${l.villagesHint}', style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: all.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: EmptyState(
                      icon: Icons.holiday_village_outlined,
                      text: l.villagesMineNone,
                      action: FilledButton.icon(
                        onPressed: () => importVillageSheet(context),
                        icon: const Icon(Icons.upload_file),
                        label: Text(l.villagesImport),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: lists.length,
                    itemBuilder: (_, i) {
                      final e = lists[i];
                      return Card(
                        key: ValueKey('villages_${e.pin}_${e.office}'),
                        child: ListTile(
                          leading: Icon(Icons.holiday_village_outlined, color: Theme.of(context).colorScheme.primary),
                          title: Text('${e.office} · ${e.pin}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(e.villages.join(', ')),
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: () => editVillages(context, pin: e.pin, name: e.office),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
