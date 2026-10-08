/// The user's own fixes to post office names in the directory.
library;

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/settings.dart';
import '../../core/widgets.dart';
import '../../data/app_services.dart';
import '../../data/directory_builder.dart' show NameCorrection;
import '../../data/models/office.dart';

NameCorrection _fix(Map<String, Object?> m, {bool undo = false}) => NameCorrection(
  pincode: (m['pin'] as num).toInt(),
  officeType: m['type'] as String,
  oldName: (undo ? m['new'] : m['old']) as String,
  newName: (undo ? m['old'] : m['new']) as String,
);

/// Applies all saved fixes (on start; renames only offices still spelt the
/// old way, so it is safe to run every time).
Future<void> applyOfficeFixes(Settings settings, AppServices services) async {
  final fixes = settings.officeFixes;
  if (fixes.isNotEmpty) await services.renameOffices([for (final f in fixes) _fix(f)]);
}

/// Asks for a new name and saves it as a fix. Returns true if renamed.
Future<bool> editOfficeName(BuildContext context, Office o) async {
  final l = AppLocalizations.of(context);
  final settings = context.settings;
  final services = context.services;
  final messenger = ScaffoldMessenger.of(context);
  final c = TextEditingController(text: o.officeName);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.editOfficeName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${o.pin} · ${o.officeType} · ${o.district}'),
          TextField(key: const ValueKey('office_name_field'), controller: c, autofocus: true, decoration: InputDecoration(labelText: l.fOffice)),
          const SizedBox(height: 8),
          Text(l.editOfficeNameHint, style: Theme.of(ctx).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(key: const ValueKey('office_name_save'), onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(l.save)),
      ],
    ),
  );
  if (name == null || name.isEmpty || name == o.officeName) return false;
  final fixes = [...settings.officeFixes];
  // Renaming an office the user already renamed: keep the original name.
  final i = fixes.indexWhere((f) => f['pin'] == o.pincode && f['type'] == o.officeType && f['new'] == o.officeName);
  if (i >= 0) {
    if (fixes[i]['old'] == name) {
      fixes.removeAt(i);
    } else {
      fixes[i] = {...fixes[i], 'new': name};
    }
  } else {
    fixes.add({'pin': o.pincode, 'type': o.officeType, 'old': o.officeName, 'new': name});
  }
  settings.officeFixes = fixes;
  await services.renameOffices([NameCorrection(pincode: o.pincode, officeType: o.officeType, oldName: o.officeName, newName: name)]);
  messenger.showSnackBar(SnackBar(content: Text(l.officeRenamed(name))));
  return true;
}

class OfficeFixesScreen extends StatelessWidget {
  const OfficeFixesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fixes = context.settings.officeFixes;
    return Scaffold(
      appBar: AppBar(title: Text(l.officeFixes)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Padding(padding: const EdgeInsets.all(4), child: Text(l.officeFixesHint)),
          if (fixes.isEmpty) EmptyState(icon: Icons.edit_location_alt_outlined, text: l.officeFixesNone),
          for (final f in fixes)
            Card(
              child: ListTile(
                title: Text('${f['new']} ${f['type']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${f['pin']} · ${l.wasName(f['old'] as String)}'),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.undo),
                  label: Text(l.restore),
                  onPressed: () async {
                    final settings = context.settings;
                    final services = context.services;
                    settings.officeFixes = [...settings.officeFixes]..removeWhere((x) => x['pin'] == f['pin'] && x['type'] == f['type'] && x['new'] == f['new']);
                    await services.renameOffices([_fix(f, undo: true)]);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
