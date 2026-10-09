/// Non-TD result: a slim PH bag card and compact NSH / NPH / RMS L1 tiles,
/// sized so the whole answer fits on one phone screen. Tap a tile for the
/// full PIN range and notes.
library;

import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart' show bagColour;
import '../../data/models/scheme.dart';
import '../../data/nsh.dart';

const Color kNshAccent = Color(0xFF4F46E5);
const Color kIchAccent = Color(0xFF0369A1);
const Color kNphAccent = Color(0xFF0F766E);
const Color kL1Accent = Color(0xFF9333EA);

/// PH / bag for a Non-TD PIN: bag colour, name, state and PIN range in one
/// short card; [trailing] holds the air code.
class PhCard extends StatelessWidget {
  const PhCard({super.key, required this.bag, required this.label, this.series, this.trailing});

  final Bag bag;
  final String label;
  final String? series;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bg = bagColour(context, bag);
    final fg = onColour(bg);
    final t = Theme.of(context).textTheme;
    final deep = Color.lerp(bg, Colors.black, 0.22)!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [bg, deep]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: bg.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label.toUpperCase(), style: t.labelSmall?.copyWith(color: fg.withValues(alpha: 0.8), letterSpacing: 1.4, fontWeight: FontWeight.w800)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(bag.code, style: t.headlineMedium?.copyWith(color: fg, fontWeight: FontWeight.w900, height: 1.05)),
                ),
                if (bag.name.isNotEmpty && bag.name != bag.code)
                  Text(bag.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w700)),
                if (series != null)
                  Text(series!, key: const ValueKey('ph_series'), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(color: fg.withValues(alpha: 0.9), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Soft air-code chip ("✈ HYD").
class HubAirChip extends StatelessWidget {
  const HubAirChip(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final c = accentFor(context, kAccentOrange);
    return Container(
      key: ValueKey('hub_air_$code'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withValues(alpha: 0.45))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flight, size: 15, color: c),
          const SizedBox(width: 3),
          Text(code, style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.8)),
        ],
      ),
    );
  }
}

/// One compact hub row: accent stripe, tag + circle, hub name, PIN range on
/// one line and the air code; tap to show [details].
class HubTile extends StatefulWidget {
  const HubTile({
    super.key,
    required this.tag,
    required this.accent,
    required this.icon,
    this.name,
    this.nameKey,
    this.subtitle = '',
    this.series = '',
    this.seriesKey,
    this.air = '',
    this.notes = const [],
    this.details = const [],
  });

  final String tag;
  final Color accent;
  final IconData icon;
  final String? name;
  final Key? nameKey;

  /// Circle, or "Can be one of 3" for a partial PIN.
  final String subtitle;
  final String series;
  final Key? seriesKey;
  final String air;

  /// Always shown (sheet / RMS differences).
  final List<Widget> notes;

  /// Shown after a tap.
  final List<Widget> details;

  @override
  State<HubTile> createState() => _HubTileState();
}

class _HubTileState extends State<HubTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final a = accentFor(context, widget.accent);
    final canOpen = widget.details.isNotEmpty || widget.series.length > 40;
    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: a.withValues(alpha: 0.3),
      child: InkWell(
        onTap: canOpen ? () => setState(() => _open = !_open) : null,
        child: Container(
          decoration: BoxDecoration(border: Border(left: BorderSide(color: a, width: 6))),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: a.withValues(alpha: 0.13), shape: BoxShape.circle),
                    child: Icon(widget.icon, color: a, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: widget.tag, style: TextStyle(color: a, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            if (widget.subtitle.isNotEmpty) TextSpan(text: '  ·  ${widget.subtitle}', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.labelMedium,
                        ),
                        if (widget.name != null)
                          Text(widget.name!, key: widget.nameKey, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900, height: 1.15)),
                        if (widget.series.isNotEmpty)
                          Text(widget.series, key: widget.seriesKey, maxLines: _open ? null : 1, overflow: _open ? null : TextOverflow.ellipsis,
                              style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (widget.air.isNotEmpty) ...[const SizedBox(width: 6), HubAirChip(widget.air)],
                  if (canOpen) Icon(_open ? Icons.expand_less : Icons.expand_more, color: cs.outline, size: 20),
                ],
              ),
              ...widget.notes,
              if (_open) ...widget.details,
            ],
          ),
        ),
      ),
    );
  }
}

Widget _note(BuildContext context, Key key, IconData icon, String text, Color colour) {
  final c = accentFor(context, colour);
  return Container(
    key: key,
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800, color: c))),
      ],
    ),
  );
}

Widget _matched(BuildContext context, String matched) => Padding(
  padding: const EdgeInsets.only(top: 4, left: 48),
  child: Text(AppLocalizations.of(context).nshMatched(matched), style: Theme.of(context).textTheme.bodySmall),
);

/// Names of the hubs a partial PIN can still go to, with air codes.
List<Widget> _possibleDetails(BuildContext context, List<NshHub> hubs) => [
  const SizedBox(height: 4),
  for (final h in hubs)
    Padding(
      padding: const EdgeInsets.only(left: 48, bottom: 2),
      child: Text('• ${h.name}${hubAirCode(h).isEmpty ? '' : '  ✈ ${hubAirCode(h)}'}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
    ),
  Padding(
    padding: const EdgeInsets.only(left: 48),
    child: Text(AppLocalizations.of(context).typeMoreDigits, style: Theme.of(context).textTheme.bodySmall),
  ),
];

String _possibleName(List<NshHub> hubs) => hubs.length <= 2 ? hubs.map((h) => h.name).join(' / ') : '${hubs.take(2).map((h) => h.name).join(' / ')} …';

/// NSH / ICH for speed post.
class NshCard extends StatelessWidget {
  const NshCard({super.key, required this.match, this.compact = false, this.rmsNsh});

  final NshMatch match;
  final bool compact;

  /// NSH for this PIN in the RMS data; shown when it differs from the sheet.
  final String? rmsNsh;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = match.hub;
    final accent = h.isIch ? kIchAccent : kNshAccent;
    return HubTile(
      key: const ValueKey('nsh_card'),
      tag: h.isIch ? 'ICH' : 'NSH L1',
      accent: accent,
      icon: Icons.local_shipping_outlined,
      name: h.name,
      subtitle: h.circle,
      series: h.series,
      seriesKey: const ValueKey('nsh_series'),
      air: hubAirCode(h),
      notes: [
        if (h.mappedTo.isNotEmpty) _note(context, const ValueKey('nsh_mapped'), Icons.arrow_forward, l.ichMappedTo(h.mappedTo), accent),
        if (rmsNsh != null && !sameHub(rmsNsh!, h.name) && !(h.mappedTo.isNotEmpty && sameHub(rmsNsh!, h.mappedTo)))
          _note(context, const ValueKey('nsh_rms'), Icons.compare_arrows, l.nshRmsDiffers(rmsNsh!), kAccentAmber),
        if (match.alsoListed.isNotEmpty)
          _note(context, const ValueKey('nsh_also'), Icons.info_outline,
              l.nshAlsoListed(match.matched, [h.name, ...match.alsoListed.map((x) => x.name)].join(' / ')), kAccentAmber),
      ],
      details: [_matched(context, match.matched)],
    );
  }
}

/// NPH parcel hub, from the MR RMS sorting data.
class NphCard extends StatelessWidget {
  const NphCard({super.key, this.match, this.possible = const [], this.compact = false});

  final NshMatch? match;
  final List<NshHub> possible;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = match?.hub;
    return HubTile(
      key: const ValueKey('nph_card'),
      tag: 'NPH L1',
      accent: kNphAccent,
      icon: Icons.inventory_2_outlined,
      name: h?.name ?? _possibleName(possible),
      nameKey: h == null ? null : const ValueKey('nph_name'),
      subtitle: h?.circle ?? l.possibleHubsN(possible.length).replaceAll(':', ''),
      series: h?.series ?? '',
      air: h == null ? '' : hubAirCode(h),
      details: h == null ? _possibleDetails(context, possible) : [_matched(context, match!.matched)],
    );
  }
}

/// RMS L1 / L2 for the PIN, from the MR RMS sorting data.
class RmsL1Card extends StatelessWidget {
  const RmsL1Card({super.key, this.l1, this.compact = false, this.possible = const []});

  final NshMatch? l1;
  final bool compact;

  /// For a partial PIN with several L1s: the ones it can still be.
  final List<NshHub> possible;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = l1?.hub;
    final none = h == null && possible.isEmpty;
    return HubTile(
      key: const ValueKey('l1_card'),
      tag: 'RMS L1',
      accent: kL1Accent,
      icon: Icons.alt_route,
      name: h?.name ?? (none ? l.rmsL1None : _possibleName(possible)),
      nameKey: h == null ? null : const ValueKey('l1_name'),
      subtitle: h?.circle ?? (none ? '' : l.possibleHubsN(possible.length).replaceAll(':', '')),
      series: h?.series ?? '',
      seriesKey: const ValueKey('l1_series'),
      air: h == null ? '' : hubAirCode(h),
      details: h != null ? [_matched(context, l1!.matched)] : none ? const [] : _possibleDetails(context, possible),
    );
  }
}

/// Partial PIN that more than one NSH takes: list them.
class PossibleHubsCard extends StatelessWidget {
  const PossibleHubsCard({super.key, required this.title, required this.hubs, this.tag = 'NSH L1'});

  final String title;
  final String tag;
  final List<NshHub> hubs;

  @override
  Widget build(BuildContext context) => HubTile(
    tag: tag,
    accent: kNshAccent,
    icon: Icons.local_shipping_outlined,
    name: _possibleName(hubs),
    subtitle: AppLocalizations.of(context).possibleHubsN(hubs.length).replaceAll(':', ''),
    details: _possibleDetails(context, hubs),
  );
}
