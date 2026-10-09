/// Add, edit or remove post offices in the directory (the user's own data;
/// kept in settings and re-applied after updates).
library;

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/settings.dart';
import '../../data/app_services.dart';
import '../../data/directory_builder.dart' show OfficeData, OfficeEdit;
import '../../data/models/office.dart';

OfficeData officeData(Office o) =>
    OfficeData(pincode: o.pincode, name: o.officeName, type: o.officeType, delivery: o.delivery, district: o.district, state: o.state);

/// Applies saved office changes (on start).
Future<void> applyOfficeEditsOnStart(Settings settings, AppServices services) async {
  final edits = settings.officeEdits;
  if (edits.isNotEmpty) await services.editOffices([for (final e in edits) OfficeEdit.fromJson(e)]);
}

/// Records the change [from] → [to] (either may be null) in settings,
/// merged with an earlier change of the same office, and applies it.
Future<void> saveOfficeChange(Settings settings, AppServices services, OfficeData? from, OfficeData? to) async {
  final list = [for (final e in settings.officeEdits) OfficeEdit.fromJson(e)];
  final i = from == null ? -1 : list.indexWhere((e) => e.after != null && e.after!.sameOffice(from));
  if (i >= 0) {
    final first = list[i].before;
    if (first == null && to == null) {
      list.removeAt(i); // added, then removed
    } else if (first != null && to != null && first.sameAs(to)) {
      list.removeAt(i); // changed back
    } else {
      list[i] = OfficeEdit(before: first, after: to);
    }
  } else {
    list.add(OfficeEdit(before: from, after: to));
  }
  settings.officeEdits = [for (final e in list) e.toJson()];
  await services.editOffices([OfficeEdit(before: from, after: to)]);
}

/// Undoes a saved change.
Future<void> undoOfficeChange(Settings settings, AppServices services, int index) async {
  final list = [for (final e in settings.officeEdits) OfficeEdit.fromJson(e)];
  final e = list.removeAt(index);
  settings.officeEdits = [for (final x in list) x.toJson()];
  await services.editOffices([e.inverse]);
}

/// Edit dialog for [office] (null = add a new office, prefilled from
/// [template]). Saves the change; returns true if anything changed.
Future<bool> editOffice(BuildContext context, {Office? office, OfficeData? template}) async {
  final l = AppLocalizations.of(context);
  final settings = context.settings;
  final services = context.services;
  final messenger = ScaffoldMessenger.of(context);
  final from = office == null ? null : officeData(office);
  final r = await showDialog<_Result>(context: context, builder: (_) => _OfficeDialog(start: from ?? template, isNew: office == null));
  if (r == null) return false;
  if (r.delete) {
    if (from == null) return false;
    await saveOfficeChange(settings, services, from, null);
    messenger.showSnackBar(SnackBar(content: Text(l.officeRemoved(from.name))));
    return true;
  }
  final to = r.data!;
  if (from != null && from.sameAs(to)) return false;
  await saveOfficeChange(settings, services, from, to);
  messenger.showSnackBar(SnackBar(content: Text(from == null ? l.officeAdded(to.name) : l.officeSaved(to.name))));
  return true;
}

class _Result {
  const _Result.save(this.data) : delete = false;
  const _Result.delete() : data = null, delete = true;

  final OfficeData? data;
  final bool delete;
}

class _OfficeDialog extends StatefulWidget {
  const _OfficeDialog({this.start, required this.isNew});

  final OfficeData? start;
  final bool isNew;

  @override
  State<_OfficeDialog> createState() => _OfficeDialogState();
}

class _OfficeDialogState extends State<_OfficeDialog> {
  static const _types = ['HO', 'SO', 'BO', 'PO'];
  late final _name = TextEditingController(text: widget.isNew ? '' : widget.start?.name ?? '');
  late final _pin = TextEditingController(text: (widget.start?.pincode ?? 0) > 0 ? '${widget.start!.pincode}' : '');
  late final _district = TextEditingController(text: widget.start?.district ?? '');
  late final _state = TextEditingController(text: widget.start?.state ?? '');
  late String _type = widget.start?.type.isNotEmpty == true ? widget.start!.type : (widget.isNew ? 'BO' : '');
  late bool _delivery = widget.start?.delivery ?? true;
  String? _error;

  void _save() {
    final l = AppLocalizations.of(context);
    final pin = int.tryParse(_pin.text.trim());
    final name = _name.text.trim();
    if (name.isEmpty || pin == null || _pin.text.trim().length != 6) {
      setState(() => _error = l.officeInvalid);
      return;
    }
    Navigator.pop(
      context,
      _Result.save(OfficeData(pincode: pin, name: name, type: _type, delivery: _delivery, district: _district.text.trim(), state: _state.text.trim())),
    );
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(l.officeRemoveConfirm(widget.start!.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(key: const ValueKey('office_remove_yes'), onPressed: () => Navigator.pop(c, true), child: Text(l.officeRemove)),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.pop(context, const _Result.delete());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final types = {..._types, if (_type.isNotEmpty) _type};
    return AlertDialog(
      title: Text(widget.isNew ? l.officeAdd : l.officeEdit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(key: const ValueKey('office_name_field'), controller: _name, autofocus: widget.isNew, decoration: InputDecoration(labelText: l.fOffice)),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('office_pin_field'),
              controller: _pin,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(labelText: l.officePin, counterText: ''),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const ValueKey('office_type_field'),
              initialValue: _type,
              decoration: InputDecoration(labelText: l.officeType),
              items: [
                for (final t in types) DropdownMenuItem(value: t, child: Text(t)),
                DropdownMenuItem(value: '', child: Text(l.officeTypeNone)),
              ],
              onChanged: (v) => setState(() => _type = v ?? ''),
            ),
            SwitchListTile(
              key: const ValueKey('office_delivery_field'),
              contentPadding: EdgeInsets.zero,
              value: _delivery,
              title: Text(_delivery ? l.delivery : l.nonDelivery),
              onChanged: (v) => setState(() => _delivery = v),
            ),
            TextField(key: const ValueKey('office_district_field'), controller: _district, decoration: InputDecoration(labelText: l.fDistrict)),
            const SizedBox(height: 8),
            TextField(key: const ValueKey('office_state_field'), controller: _state, decoration: InputDecoration(labelText: l.fState)),
            const SizedBox(height: 8),
            Text(l.editOfficeNameHint, style: Theme.of(context).textTheme.bodySmall),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ],
        ),
      ),
      actions: [
        if (!widget.isNew)
          TextButton.icon(
            key: const ValueKey('office_remove'),
            onPressed: _delete,
            icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            label: Text(l.officeRemove, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(key: const ValueKey('office_save'), onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}
