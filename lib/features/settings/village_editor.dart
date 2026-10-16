/// Villages under a post office: the user adds and removes them; searching
/// a village finds its office and PIN.
library;

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/settings.dart';
import '../../core/widgets.dart';
import '../../data/app_services.dart';
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

/// Every office the user added villages to.
class VillagesScreen extends StatelessWidget {
  const VillagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lists = _lists(context.settings)..sort((a, b) => a.pin != b.pin ? a.pin.compareTo(b.pin) : a.office.compareTo(b.office));
    final n = lists.fold<int>(0, (n, e) => n + e.villages.length);
    return Scaffold(
      appBar: AppBar(title: Text(l.villagesMine)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Padding(padding: const EdgeInsets.all(4), child: Text(l.villagesHint)),
          if (lists.isEmpty)
            EmptyState(icon: Icons.holiday_village_outlined, text: l.villagesMineNone)
          else
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(l.villagesCount(n, lists.length), style: Theme.of(context).textTheme.bodySmall),
            ),
          for (final e in lists)
            Card(
              key: ValueKey('villages_${e.pin}_${e.office}'),
              child: ListTile(
                leading: Icon(Icons.holiday_village_outlined, color: Theme.of(context).colorScheme.primary),
                title: Text('${e.office} · ${e.pin}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(e.villages.join(', ')),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => editVillages(context, pin: e.pin, name: e.office),
              ),
            ),
        ],
      ),
    );
  }
}
