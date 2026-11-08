/// Office data packs (More → Office data): extra data from other offices
/// (beats, villages) that a user switches on to see it together with the
/// main data. Off by default; switching off removes the pack's entries
/// again and keeps the user's own additions.
library;

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/files.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/app_services.dart';
import '../../data/beats.dart';
import '../../data/import/table_reader.dart';
import '../../data/villages.dart';
import '../beats/beats_screen.dart';
import '../settings/village_editor.dart';

class OfficePack {
  const OfficePack({required this.id, required this.name, required this.area, this.beatsAsset, this.villagesAsset});

  final String id;

  /// "Dharwad HO", "Hassan district".
  final String name;

  /// Where the data is from, shown under the name.
  final String area;
  final String? beatsAsset;
  final String? villagesAsset;
}

const kOfficePacks = [
  OfficePack(id: 'dharwad', name: 'Dharwad HO', area: 'Dharwad Division · 580001', beatsAsset: 'assets/beats/dharwad_ho_beats.csv'),
  OfficePack(id: 'hassan', name: 'Hassan district', area: 'Hassan Division', villagesAsset: 'assets/villages/hassan_villages.csv'),
  OfficePack(id: 'shimoga', name: 'Shivamogga district', area: 'Shivamogga Division', villagesAsset: 'assets/villages/shimoga_villages.csv'),
  OfficePack(id: 'chikmagalur', name: 'Chikkamagaluru district', area: 'Chikkamagaluru Division', villagesAsset: 'assets/villages/chikmagalur_villages.csv'),
];

class PackData {
  const PackData(this.beats, this.villages);

  final List<Beat> beats;
  final List<VillageList> villages;

  int get villageCount => villages.fold(0, (n, v) => n + v.villages.length);
}

Future<PackData> loadPack(OfficePack p, Future<Uint8List> Function(String) loadAsset) async {
  var beats = const <Beat>[];
  var villages = const <VillageList>[];
  if (p.beatsAsset != null) beats = beatsFromTable(readTable(await loadAsset(p.beatsAsset!), 'beats.csv'));
  if (p.villagesAsset != null) villages = villageListsFromRows(readTable(await loadAsset(p.villagesAsset!), 'villages.csv').sheets.values.first);
  return PackData(beats, villages);
}

/// Switches [p] on (adds its data) or off (removes it).
Future<void> setPack(Settings settings, AppServices services, OfficePack p, bool on, Future<Uint8List> Function(String) loadAsset) async {
  final d = await loadPack(p, loadAsset);
  if (on) {
    if (d.beats.isNotEmpty) storeBeats(settings, mergeBeats(loadBeats(settings), d.beats).$1);
    if (d.villages.isNotEmpty) addVillageLists(settings, services, d.villages);
  } else {
    if (d.beats.isNotEmpty) storeBeats(settings, loadBeats(settings)..removeWhere((b) => d.beats.any((x) => x.sameBeat(b))));
    if (d.villages.isNotEmpty) removeVillageLists(settings, services, d.villages);
  }
  final ids = {...settings.enabledPacks ?? const <String>[]};
  on ? ids.add(p.id) : ids.remove(p.id);
  settings.enabledPacks = [
    for (final x in kOfficePacks)
      if (ids.contains(x.id)) x.id,
  ];
}

/// Phones that got the bundled beats / villages before packs existed keep
/// them, shown as switched on (runs once).
void migratePacks(Settings settings) {
  if (settings.enabledPacks != null) return;
  settings.enabledPacks = [
    if (settings.beatsSeeded && settings.beats.any((b) => b['office'] == 'Dharwad HO')) 'dharwad',
    ...settings.seededVillageSets.where((s) => kOfficePacks.any((p) => p.id == s)),
  ];
}

class OfficePacksScreen extends StatefulWidget {
  const OfficePacksScreen({super.key, this.loadAsset = loadAssetBytes});

  final Future<Uint8List> Function(String path) loadAsset;

  @override
  State<OfficePacksScreen> createState() => _OfficePacksScreenState();
}

class _OfficePacksScreenState extends State<OfficePacksScreen> {
  final _sizes = <String, PackData>{};
  String? _busy;

  @override
  void initState() {
    super.initState();
    for (final p in kOfficePacks) {
      loadPack(p, widget.loadAsset).then((d) {
        if (mounted) setState(() => _sizes[p.id] = d);
      }).ignore();
    }
  }

  Future<void> _toggle(OfficePack p, bool on) async {
    final l = AppLocalizations.of(context);
    final settings = context.settings;
    final services = context.services;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = p.id);
    try {
      await setPack(settings, services, p, on, widget.loadAsset);
      messenger.showSnackBar(SnackBar(content: Text(on ? l.officePackOn(p.name) : l.officePackOff(p.name))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _busy = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final on = context.settings.enabledPacks ?? const <String>[];
    return Scaffold(
      appBar: AppBar(title: Text(l.officePacks)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const IconBadge(Icons.verified_outlined, kPostGreen),
              title: Text(l.officePackMain, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(l.officePackMainSub),
              trailing: Icon(Icons.check_circle, color: cs.primary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(l.officePacksIntro, style: t.bodyMedium),
          ),
          for (final (i, p) in kOfficePacks.indexed)
            Card(
              child: SwitchListTile(
                key: ValueKey('pack_${p.id}'),
                secondary: IconBadge(p.beatsAsset != null ? Icons.route_outlined : Icons.holiday_village_outlined, kAccentCycle[(i + 1) % kAccentCycle.length]),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                subtitle: Text(
                  [
                    p.area,
                    if (_sizes[p.id] case final d?) ...[
                      if (d.beats.isNotEmpty) l.officePackBeats(d.beats.length),
                      if (d.villages.isNotEmpty) l.officePackVillages(d.villageCount),
                    ],
                  ].join(' · '),
                ),
                value: on.contains(p.id),
                onChanged: _busy != null ? null : (v) => _toggle(p, v),
              ),
            ),
          if (_busy != null) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(l.officePacksMore, style: t.bodySmall),
          ),
        ],
      ),
    );
  }
}
