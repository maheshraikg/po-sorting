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
import '../../core/constants.dart';
import '../../data/import/scheme_import.dart';
import '../../data/import/scheme_io.dart';
import '../../data/import/table_reader.dart';
import '../../data/models/scheme.dart';
import '../../data/villages.dart';
import '../beats/beats_screen.dart';
import '../settings/village_editor.dart';
import 'pack_learn.dart';

class OfficePack {
  const OfficePack({
    required this.id,
    required this.name,
    required this.area,
    required this.color,
    this.version = 1,
    this.beatsAsset,
    this.villagesAsset,
    this.schemeAsset,
    this.category,
  });

  final String id;

  /// "Dharwad HO", "Hassan district".
  final String name;

  /// Where the data is from, shown under the name.
  final String area;

  /// App colour while this office is chosen.
  final Color color;

  /// Bumped when the pack's data changes; phones with the pack on get the
  /// new data on their next start.
  final int version;
  final String? beatsAsset;
  final String? villagesAsset;

  /// Sorting lines (app scheme format) added to the active scheme as their
  /// own mode [category] next to TD / Non-TD.
  final String? schemeAsset;
  final String? category;
}

const kOfficePacks = [
  OfficePack(
    id: 'hubballi',
    name: 'Hubballi RMS',
    area: 'Dharwad · Hubballi · Haveri · Sirsi · Uttara Kannada',
    color: Color(0xFF00695C),
    version: 1,
    schemeAsset: 'assets/packs/hubballi_rms_scheme.csv',
    category: 'Hubballi RMS',
    beatsAsset: 'assets/beats/hubballi_town_beats.csv',
    villagesAsset: 'assets/villages/uttara_kannada_villages.csv',
  ),
  OfficePack(id: 'hassan', name: 'Hassan district', area: 'Hassan Division', color: Color(0xFF283593), villagesAsset: 'assets/villages/hassan_villages.csv'),
  OfficePack(
    id: 'shimoga',
    name: 'Shivamogga district',
    area: 'Shivamogga Division',
    color: Color(0xFF2E7D32),
    villagesAsset: 'assets/villages/shimoga_villages.csv',
  ),
  OfficePack(
    id: 'chikmagalur',
    name: 'Chikkamagaluru district',
    area: 'Chikkamagaluru Division',
    color: Color(0xFF6A1B9A),
    villagesAsset: 'assets/villages/chikmagalur_villages.csv',
  ),
];

OfficePack? officePackById(String? id) => kOfficePacks.where((p) => p.id == id).firstOrNull;

/// The app colour for the chosen office (null = normal red).
Color? officeColor(Settings s) => officePackById(s.colorPack)?.color;

/// "📍 Dharwad HO" next to the app title while an office is chosen.
class OfficeChip extends StatelessWidget {
  const OfficeChip({super.key, required this.pack});

  final OfficePack pack;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('office_chip'),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.place, size: 16, color: pack.color),
        const SizedBox(width: 4),
        Text(
          pack.name,
          style: TextStyle(color: pack.color, fontSize: 14, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class PackData {
  const PackData(this.beats, this.villages, [this.lines = const []]);

  final List<Beat> beats;
  final List<VillageList> villages;

  /// Sorting rules of the pack's own mode.
  final List<BagRule> lines;

  int get villageCount => villages.fold(0, (n, v) => n + v.villages.length);
}

Future<PackData> loadPack(OfficePack p, Future<Uint8List> Function(String) loadAsset) async {
  var beats = const <Beat>[];
  var villages = const <VillageList>[];
  if (p.beatsAsset != null) beats = beatsFromTable(readTable(await loadAsset(p.beatsAsset!), 'beats.csv'));
  if (p.villagesAsset != null) villages = villageListsFromRows(readTable(await loadAsset(p.villagesAsset!), 'villages.csv').sheets.values.first);
  var lines = const <BagRule>[];
  if (p.schemeAsset != null) {
    final t = readTable(await loadAsset(p.schemeAsset!), 'lines.csv');
    lines = [for (final r in autoImport<BagRule>(t.sheets.values.first, ImportKind.bagRules).rules) r.withCategory(p.category)];
  }
  return PackData(beats, villages, lines);
}

/// Switches [p] on (adds its data) or off (removes it).
Future<void> setPack(
  Settings settings,
  AppServices services,
  OfficePack p,
  bool on,
  Future<Uint8List> Function(String) loadAsset, {
  bool fromUser = true,
}) async {
  final d = await loadPack(p, loadAsset);
  await _setLines(settings, services, p, d, on, fromUser: fromUser);
  if (on) {
    if (d.beats.isNotEmpty) storeBeats(settings, mergeBeats(loadBeats(settings), d.beats).$1);
    if (d.villages.isNotEmpty) addVillageLists(settings, services, d.villages);
  } else {
    if (d.beats.isNotEmpty) storeBeats(settings, loadBeats(settings)..removeWhere((b) => d.beats.any((x) => x.sameBeat(b))));
    if (d.villages.isNotEmpty) removeVillageLists(settings, services, d.villages);
  }
  final versions = {...settings.packVersions}..[p.id] = on ? p.version : 0;
  settings.packVersions = versions..removeWhere((_, v) => v == 0);
  if (!fromUser) return;
  // The app takes the colour of the office switched on last.
  if (on) {
    settings.colorPack = p.id;
  } else if (settings.colorPack == p.id) {
    settings.colorPack = null;
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
  if (settings.enabledPacks == null) {
    settings.enabledPacks = [
      if (settings.beatsSeeded && settings.beats.any((b) => b['office'] == 'Dharwad HO')) 'hubballi',
      ...settings.seededVillageSets.where((s) => kOfficePacks.any((p) => p.id == s)),
    ];
    return;
  }
  // 1.0.42 had a "Dharwad HO" beats pack; it is now part of Hubballi RMS.
  final ids = settings.enabledPacks!;
  if (ids.contains('dharwad')) settings.enabledPacks = [for (final x in ids) x == 'dharwad' ? 'hubballi' : x];
  if (settings.colorPack == 'dharwad') settings.colorPack = 'hubballi';
}

/// Packs switched on whose data changed (new version), or whose lines are
/// missing from the active scheme (another scheme was chosen), are applied
/// again; the user's choices stay.
Future<void> refreshPacks(Settings settings, AppServices services, Future<Uint8List> Function(String) loadAsset) async {
  for (final p in kOfficePacks) {
    if (!(settings.enabledPacks ?? const <String>[]).contains(p.id)) continue;
    final linesMissing = p.category != null && services.active != null && !services.active!.rules.any((r) => r.category == p.category);
    if (settings.packVersions[p.id] == p.version && !linesMissing) continue;
    try {
      await setPack(settings, services, p, true, loadAsset, fromUser: false);
    } catch (_) {
      // Missing asset: keep what the phone has.
    }
  }
}

/// Adds the pack's lines to the active scheme as mode [OfficePack.category]
/// (and opens that mode when the user switched the pack on), or removes them.
Future<void> _setLines(Settings settings, AppServices services, OfficePack p, PackData d, bool on, {required bool fromUser}) async {
  final cat = p.category;
  final id = services.active?.scheme.id;
  if (cat == null || id == null || d.lines.isEmpty) return;
  if (on) {
    await services.schemes.addCategory(cat);
    await services.schemes.replaceCategoryRules(id, cat, d.lines, completeBags(d.lines, const [], kBagPalette.map(colourToHex).toList()));
  } else {
    await services.schemes.replaceCategoryRules(id, cat, const [], const []);
    await services.schemes.deleteCategory(cat);
  }
  await services.reloadActive();
  if (on && fromUser) settings.category = cat;
  if (!on && settings.category == cat) settings.category = kCatTD;
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
            child: Text('${l.officePacksIntro} ${l.officePackColour}', style: t.bodyMedium),
          ),
          for (final p in kOfficePacks)
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    key: ValueKey('pack_${p.id}'),
                    secondary: IconBadge(p.beatsAsset != null ? Icons.route_outlined : Icons.holiday_village_outlined, p.color),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    subtitle: Text(
                      [
                        p.area,
                        if (_sizes[p.id] case final d?) ...[
                          if (d.lines.isNotEmpty) l.officePackLines(d.lines.length),
                          if (d.beats.isNotEmpty) l.officePackBeats(d.beats.length),
                          if (d.villages.isNotEmpty) l.officePackVillages(d.villageCount),
                        ],
                      ].join(' · '),
                    ),
                    value: on.contains(p.id),
                    onChanged: _busy != null ? null : (v) => _toggle(p, v),
                  ),
                  if (on.contains(p.id) && p.category != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 12, 8),
                        child: FilledButton.tonalIcon(
                          key: ValueKey('pack_learn_${p.id}'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PackLearnScreen(pack: p, loadAsset: widget.loadAsset),
                            ),
                          ),
                          icon: const Icon(Icons.school_outlined),
                          label: Text(l.packLearnTitle(p.name)),
                        ),
                      ),
                    ),
                ],
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
