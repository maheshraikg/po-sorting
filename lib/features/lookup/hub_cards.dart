/// Hub cards under the PH bag for Non-TD: NSH, NPH (parcel hub) and RMS L1,
/// each a blue card with an arrow tag, the hub name and its air code.
library;

import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme.dart';
import '../../data/nsh.dart';

const Color kHubBlue = Color(0xFF2F5FC4);
const Color kHubBlueDark = Color(0xFF213F86);

Color _blue(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? kHubBlueDark : kHubBlue;

/// Arrow tag on the left of a hub card ("NSH L1 ➜").
class _ArrowTag extends StatelessWidget {
  const _ArrowTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 44,
      child: ClipPath(
        clipper: const _ArrowClipper(),
        child: ColoredBox(
          color: _blue(context),
          child: Padding(
            padding: const EdgeInsets.only(left: 6, right: 18),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, height: 1.1)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrowClipper extends CustomClipper<Path> {
  const _ArrowClipper();

  @override
  Path getClip(Size s) {
    final head = s.width * 0.26;
    final body = s.height * 0.22;
    return Path()
      ..moveTo(0, body)
      ..lineTo(s.width - head, body)
      ..lineTo(s.width - head, 0)
      ..lineTo(s.width, s.height / 2)
      ..lineTo(s.width - head, s.height)
      ..lineTo(s.width - head, s.height - body)
      ..lineTo(0, s.height - body)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Orange air-code chip ("✈ HYD").
class HubAirChip extends StatelessWidget {
  const HubAirChip(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('hub_air_$code'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kAccentOrange,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flight, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
        ],
      ),
    );
  }
}

/// Tag + blue card: name on red, air code, then [children] (white text).
class HubCardShell extends StatelessWidget {
  const HubCardShell({super.key, required this.tag, this.name, this.nameKey, this.air = '', this.children = const [], this.compact = false});

  final String tag;
  final String? name;
  final Key? nameKey;
  final String air;
  final List<Widget> children;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ArrowTag(tag),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            decoration: BoxDecoration(
              color: _blue(context),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: kHubBlue.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            padding: EdgeInsets.all(compact ? 10 : 12),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (name != null || air.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: name == null
                              ? const SizedBox.shrink()
                              : Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: kPostRed, borderRadius: BorderRadius.circular(6)),
                                    child: Text(
                                      name!,
                                      key: nameKey,
                                      style: (compact ? t.titleSmall : t.titleMedium)?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: compact ? 16 : 19, height: 1.15),
                                    ),
                                  ),
                                ),
                        ),
                        if (air.isNotEmpty) ...[const SizedBox(width: 8), HubAirChip(air)],
                      ],
                    ),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

TextStyle? _detail(BuildContext context, {bool bold = false}) =>
    Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: bold ? 1 : 0.85), fontWeight: bold ? FontWeight.w800 : FontWeight.w600);

/// A note on a light band inside a hub card.
Widget _note(BuildContext context, Key key, IconData icon, String text) => Container(
  key: key,
  margin: const EdgeInsets.only(top: 8),
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: Colors.white),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: _detail(context, bold: true))),
    ],
  ),
);

/// PIN range of a hub, shortened to the first whole series when long.
class _Series extends StatefulWidget {
  const _Series({required this.series, required this.matched, this.seriesKey, this.moreKey});

  final String series;
  final String matched;
  final Key? seriesKey;
  final Key? moreKey;

  @override
  State<_Series> createState() => _SeriesState();
}

class _SeriesState extends State<_Series> {
  static const _short = 140;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = widget.series;
    final long = s.length > _short && !_all;
    final cut = long ? (s.lastIndexOf(',', _short) > 0 ? s.lastIndexOf(',', _short) : _short) : s.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(l.nshPinRange, style: _detail(context)?.copyWith(fontSize: 12, letterSpacing: 0.5)),
        Text(long ? '${s.substring(0, cut)}, …' : s, key: widget.seriesKey, style: _detail(context, bold: true)),
        if (long)
          TextButton(
            key: widget.moreKey,
            style: TextButton.styleFrom(foregroundColor: Colors.white, padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
            onPressed: () => setState(() => _all = true),
            child: Text(l.showAll, style: const TextStyle(decoration: TextDecoration.underline)),
          ),
        Text(l.nshMatched(widget.matched), style: _detail(context)?.copyWith(fontSize: 12)),
      ],
    );
  }
}

/// Hubs a partial PIN can still go to.
List<Widget> _possible(BuildContext context, List<NshHub> hubs, {int max = 6}) {
  final l = AppLocalizations.of(context);
  return [
    Text(l.possibleHubsN(hubs.length), style: _detail(context)),
    const SizedBox(height: 4),
    for (final h in hubs.take(max))
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(child: Text('• ${h.name}', style: _detail(context, bold: true)?.copyWith(fontSize: 17))),
            if (hubAirCode(h).isNotEmpty) Text(hubAirCode(h), style: _detail(context, bold: true)?.copyWith(color: const Color(0xFFFFC48A))),
          ],
        ),
      ),
    if (hubs.length > max) Text('+${hubs.length - max}', style: _detail(context)),
    Text(l.typeMoreDigits, style: _detail(context)?.copyWith(fontSize: 12)),
  ];
}

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
    return HubCardShell(
      key: const ValueKey('nsh_card'),
      tag: h.isIch ? 'ICH' : 'NSH L1',
      name: h.name,
      air: hubAirCode(h),
      compact: compact,
      children: [
        if (h.circle.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(h.circle, style: _detail(context, bold: true))),
        if (h.mappedTo.isNotEmpty) Text('➜ ${l.ichMappedTo(h.mappedTo)}', style: _detail(context, bold: true)),
        if (rmsNsh != null && !sameHub(rmsNsh!, h.name) && !(h.mappedTo.isNotEmpty && sameHub(rmsNsh!, h.mappedTo)))
          _note(context, const ValueKey('nsh_rms'), Icons.compare_arrows, l.nshRmsDiffers(rmsNsh!)),
        if (match.alsoListed.isNotEmpty)
          _note(context, const ValueKey('nsh_also'), Icons.info_outline,
              l.nshAlsoListed(match.matched, [h.name, ...match.alsoListed.map((x) => x.name)].join(' / '))),
        _Series(series: h.series, matched: match.matched, seriesKey: const ValueKey('nsh_series')),
      ],
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
    final h = match?.hub;
    return HubCardShell(
      key: const ValueKey('nph_card'),
      tag: 'NPH L1',
      name: h?.name,
      nameKey: const ValueKey('nph_name'),
      air: h == null ? '' : hubAirCode(h),
      compact: compact,
      children: [
        if (h == null && possible.isNotEmpty) ..._possible(context, possible),
        if (h != null && h.circle.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(h.circle, style: _detail(context, bold: true))),
        if (h != null) _Series(series: h.series, matched: match!.matched),
      ],
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
    return HubCardShell(
      key: const ValueKey('l1_card'),
      tag: 'RMS L1',
      name: h?.name,
      nameKey: const ValueKey('l1_name'),
      air: h == null ? '' : hubAirCode(h),
      compact: compact,
      children: [
        if (h == null && possible.isNotEmpty)
          ..._possible(context, possible)
        else if (h == null)
          Text(l.rmsL1None, style: _detail(context, bold: true)),
        if (h != null && h.circle.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(h.circle, style: _detail(context, bold: true))),
        if (h != null) _Series(series: h.series, matched: l1!.matched, seriesKey: const ValueKey('l1_series'), moreKey: const ValueKey('l1_more')),
      ],
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
  Widget build(BuildContext context) => HubCardShell(
    tag: tag,
    children: [
      Text(title, style: _detail(context, bold: true)?.copyWith(fontSize: 12, letterSpacing: 1)),
      const SizedBox(height: 4),
      ..._possible(context, hubs, max: 8),
    ],
  );
}
