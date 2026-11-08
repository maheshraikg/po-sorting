/// Beat list (More → Beat list): postman beats of delivery offices with the
/// areas each beat serves. Search an area to find its beat; add, edit,
/// remove beats or import a beat sheet. Kept apart from the Sort screen.
library;

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/files.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/beats.dart';
import '../../data/import/table_reader.dart';
import '../packs/office_packs.dart';

List<Beat> loadBeats(Settings s) => [for (final j in s.beats) Beat.fromJson(j)];

void storeBeats(Settings s, List<Beat> beats) => s.beats = [for (final b in beats) b.toJson()];

/// Beats from a picked file / asset (any sheet that has a beat header).
List<Beat> beatsFromTable(TableFile t) {
  for (final name in [if (t.sheets.containsKey('Beats')) 'Beats', ...t.sheets.keys]) {
    final b = readBeats(t.sheets[name]!);
    if (b.isNotEmpty) return b;
  }
  return const [];
}

class BeatsScreen extends StatefulWidget {
  const BeatsScreen({super.key, this.loadAsset = loadAssetBytes});

  /// Loads bundled office packs (tests pass a file reader).
  final Future<Uint8List> Function(String path) loadAsset;

  @override
  State<BeatsScreen> createState() => _BeatsScreenState();
}

class _BeatsScreenState extends State<BeatsScreen> {
  String _q = '';
  String? _office;

  Future<void> _import() async {
    final l = AppLocalizations.of(context);
    final s = context.settings;
    final messenger = ScaffoldMessenger.of(context);
    final f = await pickTableFile();
    if (f == null) return;
    List<Beat> b;
    try {
      b = beatsFromTable(readTable(f.bytes, f.name));
    } catch (_) {
      b = const [];
    }
    if (b.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l.beatsNoneInFile)));
      return;
    }
    final (merged, n) = mergeBeats(loadBeats(s), b);
    storeBeats(s, merged);
    messenger.showSnackBar(SnackBar(content: Text(l.beatsImported(n))));
  }

  Future<void> _export() async {
    final l = AppLocalizations.of(context);
    final beats = loadBeats(context.settings);
    await shareFiles({
      'Beats.xlsx': writeXlsx({'Beats': beatsTable(beats)}),
    }, text: l.beatList);
  }

  Future<void> _edit(Beat? beat, {Beat? template}) async {
    final s = context.settings;
    final l = AppLocalizations.of(context);
    final r = await showDialog<_BeatResult>(
      context: context,
      builder: (_) => _BeatDialog(beat: beat ?? template),
    );
    if (r == null) return;
    final list = loadBeats(s);
    final i = beat == null ? -1 : list.indexWhere((x) => x.sameBeat(beat));
    if (r.delete) {
      if (i >= 0) list.removeAt(i);
    } else if (i >= 0) {
      list[i] = r.beat!;
    } else {
      list.add(r.beat!);
    }
    storeBeats(s, list);
    if (mounted) toast(context, r.delete ? l.beatRemoved(beat!.beat) : l.beatSaved(r.beat!.beat));
  }

  Future<void> _removeOffice(String office) async {
    final l = AppLocalizations.of(context);
    final s = context.settings;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(l.beatsRemoveOfficeQ(office)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(key: const ValueKey('beats_remove_office_yes'), onPressed: () => Navigator.pop(d, true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true) return;
    storeBeats(s, loadBeats(s)..removeWhere((b) => b.office == office));
    setState(() => _office = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final beats = loadBeats(context.settings);
    final offices = {for (final b in beats) b.office}.toList()..sort();
    final mine = _office == null ? beats : beats.where((b) => b.office == _office).toList();
    final hits = _q.trim().isEmpty
        ? [
            for (final b
                in mine..sort((a, b) => a.pin != b.pin ? a.pin.compareTo(b.pin) : (int.tryParse(a.beat) ?? 1 << 20).compareTo(int.tryParse(b.beat) ?? 1 << 20)))
              BeatHit(b, const [], 0),
          ]
        : searchBeats(mine, _q);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.beatList),
        actions: [
          PopupMenuButton<String>(
            key: const ValueKey('beats_menu'),
            onSelected: (v) => switch (v) {
              'import' => _import(),
              'export' => _export(),
              'packs' => Navigator.push(context, MaterialPageRoute(builder: (_) => OfficePacksScreen(loadAsset: widget.loadAsset))),
              _ => _removeOffice(v.substring(7)),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'import',
                child: ListTile(leading: const Icon(Icons.upload_file), title: Text(l.beatsImport)),
              ),
              PopupMenuItem(
                value: 'export',
                child: ListTile(leading: const Icon(Icons.ios_share), title: Text(l.beatsExport)),
              ),
              PopupMenuItem(
                value: 'packs',
                child: ListTile(leading: const Icon(Icons.business_outlined), title: Text(l.officePacks)),
              ),
              if (_office != null)
                PopupMenuItem(
                  value: 'remove:$_office',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: cs.error),
                    title: Text(l.beatsRemoveOffice(_office!)),
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('beat_add'),
        onPressed: () => _edit(
          null,
          template: mine.isEmpty ? null : Beat(office: mine.last.office, pin: mine.last.pin, beat: ''),
        ),
        icon: const Icon(Icons.add),
        label: Text(l.beatAdd),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            decoration: BoxDecoration(
              gradient: headerGradient(context),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                TextField(
                  key: const ValueKey('beats_search'),
                  onChanged: (v) => setState(() => _q = v),
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    hintText: l.beatsSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: cs.surfaceContainerLowest,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                if (offices.length > 1) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(label: Text(l.beatsAllOffices), selected: _office == null, onSelected: (_) => setState(() => _office = null)),
                        ),
                        for (final o in offices)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(label: Text(o), selected: _office == o, onSelected: (_) => setState(() => _office = o)),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(beats.isEmpty ? '' : l.beatsCount(hits.length, offices.length), style: t.bodySmall),
            ),
          ),
          Expanded(
            child: beats.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: EmptyState(
                      icon: Icons.route_outlined,
                      text: l.beatsEmpty,
                      action: FilledButton.icon(onPressed: _import, icon: const Icon(Icons.upload_file), label: Text(l.beatsImport)),
                    ),
                  )
                : hits.isEmpty
                ? Center(
                    child: Padding(padding: const EdgeInsets.all(24), child: Text(l.noResults)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                    itemCount: hits.length,
                    itemBuilder: (_, i) => _BeatCard(hit: hits[i], query: _q, onTap: () => _edit(hits[i].beat)),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BeatCard extends StatelessWidget {
  const _BeatCard({required this.hit, required this.query, required this.onTap});

  final BeatHit hit;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final b = hit.beat;
    final colour = kAccentCycle[(int.tryParse(b.beat) ?? b.beat.hashCode).abs() % kAccentCycle.length];
    final matched = hit.areas.toSet();
    return Card(
      key: ValueKey('beat_${b.pin}_${b.beat}'),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      l.beatNo(b.beat),
                      style: t.titleLarge?.copyWith(color: onColour(colour), fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.office, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        if (b.pin > 0)
                          Text(
                            '${b.pin}',
                            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_outlined, color: cs.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 8),
              if (matched.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in hit.areas)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colour.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colour),
                        ),
                        child: Text(a, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Text(
                [
                  for (final a in b.areas)
                    if (!matched.contains(a)) a,
                ].join(', '),
                style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BeatResult {
  const _BeatResult.save(this.beat) : delete = false;
  const _BeatResult.delete() : beat = null, delete = true;

  final Beat? beat;
  final bool delete;
}

class _BeatDialog extends StatefulWidget {
  const _BeatDialog({this.beat});

  final Beat? beat;

  @override
  State<_BeatDialog> createState() => _BeatDialogState();
}

class _BeatDialogState extends State<_BeatDialog> {
  late final bool _isNew = widget.beat == null || widget.beat!.beat.isEmpty;
  late final _office = TextEditingController(text: widget.beat?.office ?? '');
  late final _pin = TextEditingController(text: (widget.beat?.pin ?? 0) > 0 ? '${widget.beat!.pin}' : '');
  late final _beat = TextEditingController(text: widget.beat?.beat ?? '');
  late final _areas = TextEditingController(text: widget.beat?.areas.join(', ') ?? '');
  String? _error;

  @override
  void dispose() {
    for (final c in [_office, _pin, _beat, _areas]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final l = AppLocalizations.of(context);
    final pin = int.tryParse(_pin.text.trim());
    if (_office.text.trim().isEmpty || _beat.text.trim().isEmpty || (_pin.text.trim().isNotEmpty && (pin == null || _pin.text.trim().length != 6))) {
      setState(() => _error = l.beatInvalid);
      return;
    }
    Navigator.pop(context, _BeatResult.save(Beat(office: _office.text.trim(), pin: pin ?? 0, beat: _beat.text.trim(), areas: splitAreas(_areas.text))));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(_isNew ? l.beatAdd : l.beatEdit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('beat_office'),
              controller: _office,
              decoration: InputDecoration(labelText: l.fOffice),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('beat_pin'),
                    controller: _pin,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(labelText: l.officePin, counterText: ''),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextField(
                    key: const ValueKey('beat_no'),
                    controller: _beat,
                    autofocus: _isNew,
                    decoration: InputDecoration(labelText: l.beatNoLabel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('beat_areas'),
              controller: _areas,
              minLines: 4,
              maxLines: 10,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.beatAreas, helperText: l.beatAreasHint, helperMaxLines: 2, alignLabelWithHint: true),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: cs.error)),
              ),
          ],
        ),
      ),
      actions: [
        if (!_isNew)
          TextButton.icon(
            key: const ValueKey('beat_delete'),
            onPressed: () => Navigator.pop(context, const _BeatResult.delete()),
            icon: Icon(Icons.delete_outline, color: cs.error),
            label: Text(l.delete, style: TextStyle(color: cs.error)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(key: const ValueKey('beat_save'), onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}
