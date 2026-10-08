/// Add or edit one air code rule (PIN, range, prefix, district or state).
library;

import 'package:flutter/material.dart';

import '../../core/fuzzy.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/labels.dart';
import '../../core/pin_utils.dart';
import '../../data/models/scheme.dart';

const _types = [RuleType.exact, RuleType.range, RuleType.prefix, RuleType.district, RuleType.state];

class AirCodeDialog extends StatefulWidget {
  const AirCodeDialog({super.key, this.rule});

  final AirCodeRule? rule;

  @override
  State<AirCodeDialog> createState() => _AirCodeDialogState();
}

class _AirCodeDialogState extends State<AirCodeDialog> {
  late RuleType _type = _types.contains(widget.rule?.match.type) ? widget.rule!.match.type : RuleType.prefix;
  late final _a = TextEditingController(text: _initialA());
  late final _b = TextEditingController(text: widget.rule?.match.pinTo?.toString() ?? '');
  late final _code = TextEditingController(text: widget.rule?.airCode ?? '');
  late final _station = TextEditingController(text: widget.rule?.stationName ?? '');
  late final _via = TextEditingController(text: widget.rule?.viaHub ?? '');
  late final _remarks = TextEditingController(text: widget.rule?.remarks ?? '');
  String? _error;

  String _initialA() {
    final r = widget.rule;
    if (r == null) return '';
    final m = r.match;
    return switch (m.type) {
      RuleType.exact => '${m.pin}',
      RuleType.range => '${m.pinFrom}',
      RuleType.prefix => m.prefix ?? '',
      RuleType.district => r.district ?? m.districtNorm ?? '',
      RuleType.state => r.state ?? m.stateNorm ?? '',
      _ => '',
    };
  }

  void _submit() {
    final l = AppLocalizations.of(context);
    final a = PinUtils.normalizeDigits(_a.text.trim());
    MatchSpec? m;
    String? district, state;
    switch (_type) {
      case RuleType.exact:
        if (PinUtils.isValid(a)) m = MatchSpec.exact(int.parse(a));
      case RuleType.range:
        final b = PinUtils.normalizeDigits(_b.text.trim());
        if (PinUtils.isValid(a) && PinUtils.isValid(b) && int.parse(a) <= int.parse(b)) m = MatchSpec.range(int.parse(a), int.parse(b));
      case RuleType.prefix:
        if (RegExp(r'^[1-9]\d{0,4}$').hasMatch(a)) m = MatchSpec.prefix(a);
      case RuleType.district:
        if (a.isNotEmpty) m = MatchSpec(type: RuleType.district, districtNorm: normalizePlace(a));
        district = a;
      case RuleType.state:
        if (a.isNotEmpty) m = MatchSpec(type: RuleType.state, stateNorm: normalizePlace(a));
        state = a;
      default:
    }
    if (m == null) {
      setState(() => _error = l.invalidRuleKey);
      return;
    }
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = l.airCodeRequired);
      return;
    }
    Navigator.pop(
      context,
      AirCodeRule(
        id: widget.rule?.id,
        match: m,
        district: district,
        state: state,
        airCode: code,
        stationName: _station.text.trim(),
        viaHub: _via.text.trim(),
        remarks: _remarks.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final numeric = _type == RuleType.exact || _type == RuleType.range || _type == RuleType.prefix;
    return AlertDialog(
      title: Text(widget.rule == null ? l.addAirCode : l.editAirCode),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<RuleType>(
              isExpanded: true,
              initialValue: _type,
              decoration: InputDecoration(labelText: l.fType),
              items: [for (final t in _types) DropdownMenuItem(value: t, child: Text(ruleTypeLabel(l, t)))],
              onChanged: (t) => setState(() => _type = t ?? RuleType.prefix),
            ),
            TextField(
              key: const ValueKey('air_dialog_a'),
              controller: _a,
              keyboardType: numeric ? TextInputType.number : TextInputType.text,
              decoration: InputDecoration(
                labelText: switch (_type) {
                  RuleType.exact => l.fPin,
                  RuleType.range => l.fPinFrom,
                  RuleType.prefix => l.fPrefix,
                  RuleType.district => l.fDistrict,
                  _ => l.fState,
                },
              ),
            ),
            if (_type == RuleType.range) TextField(controller: _b, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.fPinTo)),
            TextField(
              key: const ValueKey('air_dialog_code'),
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: l.fAirCode, helperText: l.airCodeNilHint),
            ),
            TextField(controller: _station, decoration: InputDecoration(labelText: l.fStation)),
            TextField(controller: _via, decoration: InputDecoration(labelText: l.via)),
            TextField(controller: _remarks, decoration: InputDecoration(labelText: l.fRemarks)),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(key: const ValueKey('air_dialog_save'), onPressed: _submit, child: Text(l.save)),
      ],
    );
  }
}
