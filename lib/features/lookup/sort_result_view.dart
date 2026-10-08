/// The full answer for one PIN: air code, badge, hub route, bag, offices and
/// PIN structure. Shared by Sort, Scan and Find PIN.
library;

import 'package:flutter/material.dart';


import '../../core/app_scope.dart';
import '../../core/constants.dart';
import '../../core/feedback.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/labels.dart';
import '../../core/pin_utils.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../core/files.dart';
import '../../data/import/scheme_import.dart';
import '../../data/import/scheme_io.dart';
import '../../data/models/office.dart';
import '../../data/models/scheme.dart';
import '../../data/nsh.dart';
import '../../data/sort_engine.dart';
import '../schemes/import_wizard.dart';
import '../schemes/scheme_editor.dart';
import 'air_badge.dart';

class SortResultView extends StatelessWidget {
  const SortResultView({super.key, required this.result, this.showBreakdown = true, this.onEdited});

  final SortResult result;
  final bool showBreakdown;

  /// Called after the user changed the scheme from this view.
  final VoidCallback? onEdited;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final r = result;
    final services = context.services;
    final scheme = services.active;
    const gap = SizedBox(height: 10);
    final children = <Widget>[];

    if (r.digits.isEmpty) return const SizedBox.shrink();
    if (r.breakdown == null && !r.valid) {
      children.add(WarningBanner(text: l.invalidPin, icon: Icons.error_outline));
    } else if (!r.complete) {
      // Partial PIN: sorting district + likely bag.
      final s = r.prefixSummary;
      if (s != null) {
        children.add(
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(l.sortingDistrictN(r.digits.substring(0, 3)), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                s.districts.isEmpty
                    ? l.prefixNotInDirectory
                    : '${s.districts.take(5).join(', ')}${s.districts.length > 5 ? '…' : ''}\n${s.states.join(', ')}',
              ),
            ),
          ),
        );
        children.add(gap);
      }
      final nshPart = r.category == kCatNonTD && r.digits.length >= 3 ? services.nsh?.resolve(r.digits) : null;
      if (nshPart != null) {
        children.add(NshCard(match: nshPart, compact: true));
        children.add(gap);
      }
      if (r.likelyBag != null) {
        children.add(Text(l.likelyBag, style: Theme.of(context).textTheme.labelLarge));
        children.add(BagCard(bag: r.likelyBag!, compact: true));
        children.add(gap);
      }
      if (r.possibleBags.length > 1) {
        children.add(
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Text('${l.possibleBags}: '),
              for (final b in r.possibleBags)
                Chip(
                  label: Text(b.code),
                  backgroundColor: bagColour(context, b).withValues(alpha: 0.35),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        );
        children.add(gap);
      }
    } else {
      final air = isAirCategory(r.category);
      if (air) {
        children.add(
          AirCodeCard(
            air: r.air,
            onSpeak: r.air == null ? null : () => AppFeedback.speak(context.settings, AppFeedback.spell(r.air!.rule.airCode), force: true),
          ),
        );
        children.add(gap);
      }
      if (r.connectivity != null) {
        children.add(ConnectivityBadge(connectivity: r.connectivity!, defaulted: r.connectivityDefaulted));
        children.add(gap);
      }
      if (isParcelCategory(r.category) && scheme != null) {
        children.add(HubRouteCard(hub: r.hub, versionName: scheme.dmsl?.versionName));
        children.add(gap);
      }
      if (scheme == null) {
        // No scheme yet: the delivery office is the main answer.
        final o = r.offices.firstOrNull;
        if (o != null) {
          children.add(OfficeHeadline(office: o, more: r.offices.length - 1));
          children.add(gap);
        }
      } else if (r.bag != null) {
        final pin = int.tryParse(r.digits);
        children.add(BagCard(
          bag: r.bag!,
          rule: r.bagRule,
          level: r.bagLevel,
          label: r.category == kCatNonTD ? l.phBag : null,
          series: r.category == kCatNonTD ? scheme.pinSeries(r.bag!.code, category: kCatNonTD) : null,
          trailing: pin == null || !r.complete ? null : AirBadge(lo: pin, hi: pin, foreground: onColour(bagColour(context, r.bag!))),
        ));
        children.add(gap);
      } else if (r.otherBag == null) {
        children.add(WarningBanner(text: l.noBagRule));
        children.add(gap);
      }
      final nsh = r.category == kCatNonTD ? services.nsh?.resolve(r.digits) : null;
      if (nsh != null) {
        children.add(NshCard(match: nsh));
        children.add(gap);
      }
      if (scheme != null && r.otherBag != null) {
        children.add(WarningBanner(text: l.otherModeHint(categoryLabel(l, r.otherCategory!), r.otherBag!.label), icon: Icons.swap_horiz));
        children.add(gap);
      }
      final schemeId = scheme?.scheme.id;
      if (schemeId != null && r.valid) {
        children.add(_EditButtons(result: r, schemeId: schemeId, onEdited: onEdited));
        children.add(gap);
      }
      if (r.notInDirectory) {
        children.add(WarningBanner(text: l.pinNotInDirectory));
        children.add(gap);
      }
      if (r.offices.isNotEmpty) {
        children.add(_OfficeList(key: ValueKey('offices_${r.digits}'), offices: r.offices));
        children.add(gap);
      }
    }
    if (showBreakdown && r.breakdown != null) children.add(PinBreakdownView(breakdown: r.breakdown!));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// Text to read out after a full PIN: "Bag 12" / air code spelled.
String spokenResult(AppLocalizations l, SortResult r) {
  final parts = <String>[];
  if (r.air != null) parts.add(AppFeedback.spell(r.air!.rule.airCode));
  if (r.bag != null) parts.add(AppFeedback.spellDigits(r.bag!.code));
  if (r.bag == null && r.air == null && PinUtils.isValid(r.digits)) parts.add(l.noBagRule);
  return parts.join('. ');
}

/// Big office name + district for a PIN (used when no scheme is active).
class OfficeHeadline extends StatelessWidget {
  const OfficeHeadline({super.key, required this.office, this.more = 0});

  final Office office;
  final int more;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.primary, Color.lerp(c.primary, c.secondary, 0.6)!]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${office.officeName} ${office.officeType}',
              style: t.headlineMedium?.copyWith(color: c.onPrimary, fontWeight: FontWeight.w900),
            ),
          ),
          Text('${office.district}, ${office.state}', style: t.titleMedium?.copyWith(color: c.onPrimary)),
          if (more > 0) Text(l.andMore(more), style: t.bodyMedium?.copyWith(color: c.onPrimary.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

/// Compact "no scheme" bar with direct actions.
class NoSchemeBar extends StatelessWidget {
  const NoSchemeBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final services = context.services;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(color: c.secondaryContainer, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: c.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.noSchemeShort,
              style: TextStyle(color: c.onSecondaryContainer, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportWizard(kind: ImportKind.bagRules))),
            child: Text(l.importShort),
          ),
          TextButton(
            onPressed: () async {
              await installSampleScheme(services.schemes, loadAssetBytes);
              await services.reloadActive();
            },
            child: Text(l.sampleShort),
          ),
        ],
      ),
    );
  }
}

/// "Change bag for this PIN" (a PIN-only override, or edits the PIN's own
/// rule) and, when a wider rule matched, a button to edit that rule.
class _EditButtons extends StatelessWidget {
  const _EditButtons({required this.result, required this.schemeId, this.onEdited});

  final SortResult result;
  final int schemeId;
  final VoidCallback? onEdited;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final r = result;
    final rule = r.bagRule;
    final own = rule != null && rule.match.type == RuleType.exact && rule.category == r.category ? rule : null;
    Future<void> run(BagRule? edit) async {
      final ok = await editRuleFor(context, schemeId: schemeId, rule: edit, pin: r.digits, category: r.category, bagCode: r.bag?.code);
      if (ok && context.mounted) {
        toast(context, l.savedSortingUpdated);
        onEdited?.call();
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        OutlinedButton.icon(
          key: const ValueKey('change_bag'),
          icon: const Icon(Icons.edit_outlined),
          label: Text(l.changeBagHere),
          onPressed: () => run(own),
        ),
        if (rule != null && own == null && rule.match.type != RuleType.fallback)
          TextButton.icon(icon: const Icon(Icons.rule), label: Text(l.editRuleX(rule.describe)), onPressed: () => run(rule)),
      ],
    );
  }
}

/// Delivery offices of a PIN: the first 12, then "Show all N" for the rest.
class _OfficeList extends StatefulWidget {
  const _OfficeList({super.key, required this.offices});

  final List<Office> offices;

  @override
  State<_OfficeList> createState() => _OfficeListState();
}

class _OfficeListState extends State<_OfficeList> {
  static const _first = 12;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final offices = widget.offices;
    final shown = _all ? offices : offices.take(_first);
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(l.deliveryOfficesN(offices.length), style: Theme.of(context).textTheme.labelLarge),
          ),
          for (final o in shown) OfficeTile(office: o),
          if (!_all && offices.length > _first)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: TextButton.icon(
                key: const ValueKey('offices_show_all'),
                onPressed: () => setState(() => _all = true),
                icon: const Icon(Icons.expand_more),
                label: Text(l.showAllN(offices.length)),
              ),
            ),
        ],
      ),
    );
  }
}

/// NSH / ICH for speed post, shown under the PH bag: hub, circle and the PIN
/// series the hub takes (from the NSH sorting extract).
class NshCard extends StatelessWidget {
  const NshCard({super.key, required this.match, this.compact = false});

  final NshMatch match;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final h = match.hub;
    final accent = h.isIch ? kSkyDeep : cs.primary;
    return Container(
      key: const ValueKey('nsh_card'),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        border: Border.all(color: accent, width: 2),
      ),
      padding: EdgeInsets.fromLTRB(16, compact ? 10 : 14, 16, compact ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  h.isIch ? l.ichLabel : l.nshLabel,
                  style: t.labelMedium?.copyWith(color: accent, letterSpacing: 1.2, fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(8)),
                child: Text(h.kind, style: t.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(h.name, style: (compact ? t.headlineSmall : t.headlineMedium)?.copyWith(fontWeight: FontWeight.w900, height: 1.1)),
          ),
          Text(h.circle, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
          if (h.mappedTo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Icon(Icons.arrow_forward, size: 18, color: accent),
                const SizedBox(width: 4),
                Expanded(child: Text(l.ichMappedTo(h.mappedTo), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: accent))),
              ]),
            ),
          if (match.alsoListed.isNotEmpty)
            Container(
              key: const ValueKey('nsh_also'),
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: cs.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.nshAlsoListed(match.matched, [h.name, ...match.alsoListed.map((x) => x.name)].join(' / ')),
                      style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: cs.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(l.nshPinRange, style: t.labelMedium?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
          Text(h.series, key: const ValueKey('nsh_series'), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          Text(l.nshMatched(match.matched), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
