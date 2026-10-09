/// Non-TD result: a slim PH bag card and compact NSH / NPH / RMS L1 tiles,
/// sized so the whole answer fits on one phone screen. Tap a tile for the
/// full PIN range and notes.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  const PhCard({super.key, required this.bag, required this.label, this.series, this.trailing, this.minHeight = 0});

  final double minHeight;

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
    return Semantics(
      label: label,
      child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [bg, deep]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: bg.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      constraints: BoxConstraints(minHeight: minHeight),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    bag.code,
                    style: t.headlineMedium?.copyWith(color: fg, fontSize: 36, fontWeight: FontWeight.w900, height: 1.05),
                  ),
                ),
                // State and PIN range on one line (the range wraps whole).
                Text.rich(
                  TextSpan(children: [
                    if (bag.name.isNotEmpty && bag.name != bag.code) TextSpan(text: series == null ? bag.name : '${bag.name}  ·  '),
                    if (series != null) TextSpan(text: series, style: TextStyle(color: fg.withValues(alpha: 0.92), fontWeight: FontWeight.w800)),
                  ]),
                  key: const ValueKey('ph_series'),
                  style: t.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
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
    const c = Colors.white;
    return Container(
      key: ValueKey('hub_air_$code'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFB923C), kAccentOrange]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flight, size: 19, color: c),
          const SizedBox(width: 3),
          Text(
            code,
            style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}

/// Filled heading pill: "🚚 NSH L1" in white on the accent colour.
class HubTag extends StatelessWidget {
  const HubTag(this.text, this.colour, this.icon, {super.key});

  final String text;
  final Color colour;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 4, offset: const Offset(0, 1))],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: colour),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(color: colour, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 0.8),
        ),
      ],
    ),
  );
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
    this.nameSmall = false,
    this.body = const [],
    this.minHeight = 0,
  });

  /// Grows the tile to this height (content centred), to fill the screen.
  final double minHeight;

  /// Shown under the name (the possible hubs of a partial PIN).
  final List<Widget> body;

  /// Name is a message ("No L1 …"), shown smaller.
  final bool nameSmall;

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

  /// Everything about the hub in a sheet: full name, every PIN code range,
  /// notes and what matched.
  void _showAll(BuildContext context) {
    final a = widget.accent;
    final deep = Color.lerp(a, Colors.black, 0.35)!;
    final l = AppLocalizations.of(context);
    final ranges = [for (final x in widget.series.split(',')) if (x.trim().isNotEmpty) x.trim()];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: ranges.length > 20 ? 0.75 : 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => Container(
          key: const ValueKey('hub_sheet'),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, deep]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
              children: [
                Center(
                  child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(3))),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    HubTag(widget.tag, a, widget.icon),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.subtitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))),
                    if (widget.air.isNotEmpty) HubAirChip(widget.air),
                  ],
                ),
                if (widget.name != null) ...[
                  const SizedBox(height: 10),
                  Text(widget.name!, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15)),
                ],
                ...widget.notes,
                ...widget.body,
                if (ranges.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('${l.nshPinRange} (${ranges.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xE6FFFFFF), letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Wrap(
                    key: const ValueKey('hub_sheet_ranges'),
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in ranges)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                          child: Text(r, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                    ],
                  ),
                ],
                ...widget.details,
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = widget.accent;
    final deep = Color.lerp(a, Colors.black, 0.35)!;
    const soft = Color(0xE6FFFFFF);
    final canOpen = widget.details.isNotEmpty || widget.series.isNotEmpty || widget.notes.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: a.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, deep]),
          ),
          child: InkWell(
            onTap: canOpen ? () => _showAll(context) : null,
            child: Container(
              constraints: BoxConstraints(minHeight: widget.minHeight),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: soft),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Heading row: tag, circle, air code, arrow.
                    Row(
                      children: [
                        HubTag(widget.tag, a, widget.icon),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(widget.subtitle, style: t.labelLarge?.copyWith(fontSize: 16, color: soft, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        if (widget.air.isNotEmpty) ...[const SizedBox(width: 6), HubAirChip(widget.air)],
                        if (canOpen) const Icon(Icons.chevron_right, color: soft, size: 26),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Hub name in full, across the card.
                    if (widget.name != null)
                      Text(
                        widget.name!,
                        key: widget.nameKey,
                        style: widget.nameSmall
                            ? t.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: soft)
                            : t.titleLarge?.copyWith(fontSize: widget.name!.contains('\n') ? 19 : 22, fontWeight: FontWeight.w900, height: 1.12, color: Colors.white),
                      ),
                    ...widget.body,
                    // Every PIN range, full card width.
                    if (widget.series.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 4),
                        child: Text(
                          widget.series,
                          key: widget.seriesKey,
                          // Long lists a little smaller, so all of them fit.
                          style: t.bodyLarge?.copyWith(fontSize: widget.series.length > 60 ? 14 : 16, fontWeight: FontWeight.w800, color: soft, height: 1.18),
                        ),
                      ),
                    ...widget.notes,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _note(BuildContext context, Key key, IconData icon, String text, Color colour) {
  const c = Colors.white;
  return Container(
    key: key,
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: colour == kAccentAmber ? 0.24 : 0.16),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800, color: c),
          ),
        ),
      ],
    ),
  );
}

Widget _matched(BuildContext context, String matched) => Padding(
  padding: const EdgeInsets.only(top: 4, left: 2),
  child: Text(AppLocalizations.of(context).nshMatched(matched), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xE6FFFFFF))),
);

/// Names of the hubs a partial PIN can still go to, with air codes.
List<Widget> _possibleDetails(BuildContext context, List<NshHub> hubs) => [
  const SizedBox(height: 4),
  for (final h in hubs)
    Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Text(
        '• ${h.name}${hubAirCode(h).isEmpty ? '' : '  (${hubAirCode(h)})'}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
      ),
    ),
  Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Text(AppLocalizations.of(context).typeMoreDigits, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xE6FFFFFF))),
  ),
];

/// Every hub a partial PIN can still go to, one per line, with air codes.
/// PIN ranges of [series] a PIN starting with [prefix] can fall in.
String seriesFor(String series, String prefix) {
  if (prefix.isEmpty) return series;
  final lo = int.parse(prefix.padRight(6, '0')), hi = int.parse(prefix.padRight(6, '9'));
  bool hit(String t) {
    final m = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(t);
    if (m != null) {
      final a = m.group(1)!, b = m.group(2)!;
      if (a.length == 6 && b.length == 6) return int.parse(a) <= hi && int.parse(b) >= lo;
      // Short range ("515-518"): compare as prefixes.
      final n = a.length;
      final p = prefix.length >= n ? int.parse(prefix.substring(0, n)) : null;
      if (p != null) return int.parse(a) <= p && p <= int.parse(b);
      final pa = int.parse(prefix), sa = int.parse(a.substring(0, prefix.length)), sb = int.parse(b.substring(0, prefix.length));
      return sa <= pa && pa <= sb;
    }
    return t.startsWith(prefix) || prefix.startsWith(t);
  }

  return [for (final t in series.split(',').map((x) => x.trim())) if (t.isNotEmpty && hit(t)) t].join(', ');
}

/// Each hub a partial PIN can still go to: name, air code and its PIN
/// ranges for the digits typed.
List<Widget> _possibleBody(BuildContext context, List<NshHub> hubs, String prefix) => [
  for (final h in hubs) ...[
    const SizedBox(height: 4),
    Text(
      '• ${h.name}${hubAirCode(h).isEmpty ? '' : '  (${hubAirCode(h)})'}',
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15),
    ),
    if (seriesFor(h.series, prefix).isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Text(seriesFor(h.series, prefix), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xE6FFFFFF), height: 1.18)),
      ),
  ],
];


/// NSH / ICH for speed post.
class NshCard extends StatelessWidget {
  const NshCard({super.key, required this.match, this.compact = false, this.rmsNsh, this.minHeight = 0});

  final double minHeight;

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
      minHeight: minHeight,
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
          _note(
            context,
            const ValueKey('nsh_also'),
            Icons.info_outline,
            l.nshAlsoListed(match.matched, [h.name, ...match.alsoListed.map((x) => x.name)].join(' / ')),
            kAccentAmber,
          ),
      ],
      details: [_matched(context, match.matched)],
    );
  }
}

/// NPH parcel hub, from the MR RMS sorting data.
class NphCard extends StatelessWidget {
  const NphCard({super.key, this.match, this.possible = const [], this.compact = false, this.minHeight = 0, this.prefix = ''});

  /// Digits typed (partial PIN), for the ranges of the possible hubs.
  final String prefix;

  final double minHeight;

  final NshMatch? match;
  final List<NshHub> possible;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = match?.hub;
    return HubTile(
      minHeight: minHeight,
      key: const ValueKey('nph_card'),
      tag: 'NPH L1',
      accent: kNphAccent,
      icon: Icons.inventory_2_outlined,
      name: h?.name,
      body: h == null ? _possibleBody(context, possible, prefix) : const [],
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
  const RmsL1Card({super.key, this.l1, this.compact = false, this.possible = const [], this.minHeight = 0, this.prefix = ''});

  /// Digits typed (partial PIN), for the ranges of the possible hubs.
  final String prefix;

  final double minHeight;

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
      minHeight: minHeight,
      key: const ValueKey('l1_card'),
      tag: 'RMS L1',
      accent: kL1Accent,
      icon: Icons.alt_route,
      name: h?.name ?? (none ? l.rmsL1None : null),
      body: h == null && !none ? _possibleBody(context, possible, prefix) : const [],
      nameKey: h == null ? null : const ValueKey('l1_name'),
      subtitle: h?.circle ?? (none ? '' : l.possibleHubsN(possible.length).replaceAll(':', '')),
      series: h?.series ?? '',
      seriesKey: const ValueKey('l1_series'),
      air: h == null ? '' : hubAirCode(h),
      nameSmall: none,
      details: h != null
          ? [_matched(context, l1!.matched)]
          : none
          ? const []
          : _possibleDetails(context, possible),
    );
  }
}

/// Partial PIN that more than one NSH takes: list them.
class PossibleHubsCard extends StatelessWidget {
  const PossibleHubsCard({super.key, required this.title, required this.hubs, this.tag = 'NSH L1', this.minHeight = 0, this.prefix = ''});

  final String prefix;

  final double minHeight;

  final String title;
  final String tag;
  final List<NshHub> hubs;

  @override
  Widget build(BuildContext context) => HubTile(
    minHeight: minHeight,
    tag: tag,
    accent: kNshAccent,
    icon: Icons.local_shipping_outlined,
    body: _possibleBody(context, hubs, prefix),
    subtitle: AppLocalizations.of(context).possibleHubsN(hubs.length).replaceAll(':', ''),
    details: _possibleDetails(context, hubs),
  );
}


/// Cards one under the other, each at its own natural height plus a share
/// (by [weights]) of the space left in [height], so together they fill it
/// (each grows by at most half its height).
/// When they need more than [height], they keep their natural height (and
/// the page scrolls) – never squeezed or scaled.
class FillColumn extends MultiChildRenderObjectWidget {
  const FillColumn({super.key, required this.height, required this.weights, this.gap = 8, required super.children});

  final double height;
  final List<double> weights;
  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFillColumn(height, weights, gap);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderFillColumn)
      ..fillHeight = height
      ..weights = weights
      ..gap = gap
      ..markNeedsLayout();
  }
}

class _FillParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderFillColumn extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _FillParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _FillParentData> {
  _RenderFillColumn(this.fillHeight, this.weights, this.gap);

  double fillHeight;
  List<double> weights;
  double gap;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FillParentData) child.parentData = _FillParentData();
  }

  @override
  void performLayout() {
    final w = constraints.maxWidth;
    final kids = <RenderBox>[];
    var c = firstChild;
    while (c != null) {
      kids.add(c);
      c = childAfter(c);
    }
    final natural = [for (final k in kids) k.getMinIntrinsicHeight(w)];
    final used = natural.fold<double>(0, (a, b) => a + b) + gap * (kids.length - 1);
    final spare = (fillHeight - used).clamp(0.0, double.infinity);
    final wsum = [for (var i = 0; i < kids.length; i++) i < weights.length ? weights[i] : 1.0].fold<double>(0, (a, b) => a + b);
    var y = 0.0;
    for (var i = 0; i < kids.length; i++) {
      final weight = i < weights.length ? weights[i] : 1.0;
      // At most half again its own height: on tablets the cards stay
      // cards instead of tall empty boxes.
      final h = natural[i] + (wsum == 0 ? 0 : (spare * weight / wsum).clamp(0.0, natural[i] * 0.5));
      kids[i].layout(BoxConstraints.tightFor(width: w, height: h), parentUsesSize: true);
      (kids[i].parentData! as _FillParentData).offset = Offset(0, y);
      y += h + gap;
    }
    size = constraints.constrain(Size(w, kids.isEmpty ? 0 : y - gap));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
