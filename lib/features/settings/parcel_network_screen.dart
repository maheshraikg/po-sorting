/// MPOP parcel hub network (Parcel Directorate letter F.No. 39-04/2025-PD,
/// 24.09.2026, in force from 07.10.2026): 60 L1 hubs, 127 L2 hubs with
/// their L1, and the L2 hubs allowed to close bags to other circles' L1s.
library;

import 'package:flutter/material.dart';

import '../../core/files.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme.dart';
import '../../data/import/table_reader.dart';
import '../lookup/hub_cards.dart' show kL1Accent, kNphAccent;

const String kMpopAsset = 'assets/schemes/mpop_hubs.csv';

class ParcelHub {
  const ParcelHub({required this.level, required this.circle, required this.name, this.l1 = '', this.direct = ''});

  final String level;
  final String circle;
  final String name;

  /// L1 hub an L2 hub is mapped to.
  final String l1;

  /// L1 hubs of other circles this hub may close bags to directly.
  final String direct;

  bool get isL1 => level == 'L1';
}

List<ParcelHub> parseParcelHubs(List<List<String>> rows) => [
  for (final r in rows.skip(1))
    if (r.length >= 3 && r[2].trim().isNotEmpty)
      ParcelHub(level: r[0].trim(), circle: r[1].trim(), name: r[2].trim(), l1: r.length > 3 ? r[3].trim() : '', direct: r.length > 4 ? r[4].trim() : ''),
];

class ParcelNetworkScreen extends StatefulWidget {
  const ParcelNetworkScreen({super.key});

  @override
  State<ParcelNetworkScreen> createState() => _ParcelNetworkScreenState();
}

class _ParcelNetworkScreenState extends State<ParcelNetworkScreen> {
  List<ParcelHub>? _hubs;
  String _q = '';
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    loadAssetBytes(kMpopAsset).then((b) {
      final t = readTable(b, 'mpop.csv');
      if (mounted) setState(() => _hubs = parseParcelHubs(t.sheets[t.defaultSheet]!));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hubs = _hubs;
    final q = _q.trim().toLowerCase();
    bool match(ParcelHub h) => q.isEmpty || '${h.name} ${h.circle} ${h.l1} ${h.direct}'.toLowerCase().contains(q);
    final shown = hubs == null
        ? const <ParcelHub>[]
        : [
            for (final h in hubs)
              if (match(h) && switch (_tab) { 0 => h.isL1, 1 => !h.isL1, _ => h.direct.isNotEmpty }) h,
          ];
    return Scaffold(
      appBar: AppBar(title: Text(l.parcelNetwork)),
      body: hubs == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  color: cs.secondaryContainer,
                  child: Padding(padding: const EdgeInsets.all(12), child: Text(l.parcelNetworkIntro, style: t.bodyMedium)),
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  key: const ValueKey('mpop_tabs'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 0, label: Text('L1 (${hubs.where((h) => h.isL1).length})')),
                    ButtonSegment(value: 1, label: Text('L2 (${hubs.where((h) => !h.isL1).length})')),
                    ButtonSegment(value: 2, label: Text(l.parcelNetworkDirect)),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (v) => setState(() => _tab = v.first),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('mpop_search'),
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.parcelNetworkSearch),
                  onChanged: (v) => setState(() => _q = v),
                ),
                const SizedBox(height: 8),
                for (final h in shown)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: accentFor(context, h.isL1 ? kL1Accent : kNphAccent),
                        foregroundColor: Colors.white,
                        child: Text(h.level, style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                      title: Text(
                        h.isL1 ? h.name : '${h.name}  →  ${h.l1}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      subtitle: Text([
                        if (h.circle.isNotEmpty) h.circle,
                        if (h.direct.isNotEmpty) l.parcelNetworkDirectTo(h.direct),
                      ].join('\n')),
                    ),
                  ),
              ],
            ),
    );
  }
}
