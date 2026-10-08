/// Edit the NSH / ICH table: hubs, their circle and PIN series. Changes are
/// kept on the phone; "Reset to sheet" brings back the bundled extract.
library;

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/files.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/widgets.dart';
import '../../data/nsh.dart';

class NshEditorScreen extends StatefulWidget {
  const NshEditorScreen({super.key, this.kind = HubTableKind.nsh});

  final HubTableKind kind;

  @override
  State<NshEditorScreen> createState() => _NshEditorScreenState();
}

class _NshEditorScreenState extends State<NshEditorScreen> {
  String _filter = '';

  Future<void> _save(List<NshHub> hubs) async {
    final t = NshTable(hubs);
    context.settings.setTableCsv(widget.kind.prefsKey, t.toCsv());
    context.services.setTable(widget.kind, t);
    setState(() {});
  }

  Future<void> _edit(List<NshHub> hubs, [int? index]) async {
    final h = await showDialog<NshHub>(context: context, builder: (_) => NshHubDialog(hub: index == null ? null : hubs[index], kind: widget.kind));
    if (h == null || !mounted) return;
    final next = [...hubs];
    if (index == null) {
      next.add(h);
    } else {
      next[index] = h;
    }
    await _save(next);
  }

  Future<void> _reset() async {
    final l = AppLocalizations.of(context);
    if (!await confirm(context, l.nshResetConfirm)) return;
    if (!mounted) return;
    final services = context.services;
    context.settings.setTableCsv(widget.kind.prefsKey, null);
    services.setTable(widget.kind, NshTable.parse(await loadAssetBytes(widget.kind.asset)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hubs = context.services.table(widget.kind)?.hubs ?? const <NshHub>[];
    final edited = context.settings.tableCsv(widget.kind.prefsKey) != null;
    final f = _filter.trim().toLowerCase();
    final shown = [
      for (var i = 0; i < hubs.length; i++)
        if (f.isEmpty || '${hubs[i].name} ${hubs[i].circle} ${hubs[i].series}'.toLowerCase().contains(f)) i,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(hubTableTitle(l, widget.kind)),
        actions: [
          IconButton(tooltip: l.nshReset, onPressed: _reset, icon: const Icon(Icons.restart_alt)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('nsh_add'),
        onPressed: () => _edit(hubs),
        icon: const Icon(Icons.add),
        label: Text(l.nshAddHub),
      ),
      body: Column(
        children: [
          if (edited) Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: WarningBanner(text: l.nshEditedNote, icon: Icons.edit_note)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.nshSearch),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
              children: [
                for (final i in shown)
                  Card(
                    child: ListTile(
                      key: ValueKey('nsh_hub_$i'),
                      title: Text(hubs[i].name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text([
                        '${hubs[i].kind} · ${hubs[i].circle}',
                        if (hubs[i].mappedTo.isNotEmpty) l.ichMappedTo(hubs[i].mappedTo),
                        hubs[i].series,
                      ].join('\n')),
                      isThreeLine: true,
                      onTap: () => _edit(hubs, i),
                      trailing: IconButton(
                        tooltip: l.delete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (!await confirm(context, l.nshDeleteConfirm(hubs[i].name))) return;
                          await _save([...hubs]..removeAt(i));
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String hubTableTitle(AppLocalizations l, HubTableKind k) => switch (k) {
  HubTableKind.nsh => l.nshHubs,
  HubTableKind.l1 => l.rmsL1Hubs,
  HubTableKind.nph => l.nphHubs,
};

class NshHubDialog extends StatefulWidget {
  const NshHubDialog({super.key, this.hub, this.kind = HubTableKind.nsh});

  final NshHub? hub;
  final HubTableKind kind;

  @override
  State<NshHubDialog> createState() => _NshHubDialogState();
}

class _NshHubDialogState extends State<NshHubDialog> {
  late final _name = TextEditingController(text: widget.hub?.name ?? '');
  late String _kind = switch (widget.kind) {
    HubTableKind.nsh => widget.hub?.kind == 'ICH' ? 'ICH' : 'NSH',
    HubTableKind.l1 => 'L1',
    HubTableKind.nph => 'NPH',
  };
  late final _circle = TextEditingController(text: widget.hub?.circle ?? '');
  late final _series = TextEditingController(text: widget.hub?.series ?? '');
  late final _mapped = TextEditingController(text: widget.hub?.mappedTo ?? '');
  String? _error;

  void _submit() {
    final l = AppLocalizations.of(context);
    final name = widget.kind == HubTableKind.nsh ? _name.text.trim().toUpperCase() : _name.text.trim();
    final series = _series.text.trim();
    if (name.isEmpty || seriesTokens(series).isEmpty) {
      setState(() => _error = l.nshInvalid);
      return;
    }
    Navigator.pop(
      context,
      NshHub(name: name, kind: _kind, circle: _circle.text.trim(), series: series, mappedTo: _mapped.text.trim().toUpperCase(), exclude: widget.hub?.exclude ?? const {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.hub == null ? l.nshAddHub : l.nshEditHub),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(key: const ValueKey('nsh_dialog_name'), controller: _name, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: l.nshHubName)),
            const SizedBox(height: 8),
            if (widget.kind == HubTableKind.nsh)
              SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'NSH', label: Text('NSH')), ButtonSegment(value: 'ICH', label: Text('ICH'))],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
            TextField(controller: _circle, decoration: InputDecoration(labelText: l.nshCircle)),
            TextField(
              key: const ValueKey('nsh_dialog_series'),
              controller: _series,
              minLines: 2,
              maxLines: 6,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(labelText: l.nshPinRange, helperText: l.nshSeriesHint, helperMaxLines: 2),
            ),
            if (_kind == 'ICH') TextField(controller: _mapped, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: l.nshMappedField)),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(key: const ValueKey('nsh_dialog_save'), onPressed: _submit, child: Text(l.save)),
      ],
    );
  }
}
