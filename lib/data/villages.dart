/// Villages the user adds under a post office (usually a BO), so a search
/// for the village finds its office and PIN. The user's own data, kept in
/// settings: [{pin, office, villages: [..]}].
library;

import '../core/fuzzy.dart';

class VillageList {
  const VillageList({required this.pin, required this.office, required this.villages});

  factory VillageList.fromJson(Map<String, Object?> j) => VillageList(
    pin: (j['pin'] as num?)?.toInt() ?? 0,
    office: j['office'] as String? ?? '',
    villages: [for (final v in (j['villages'] as List? ?? const [])) '$v'],
  );

  final int pin;
  final String office;
  final List<String> villages;

  Map<String, Object?> toJson() => {'pin': pin, 'office': office, 'villages': villages};
}

class VillageHit {
  const VillageHit(this.pin, this.officeNorm, this.village, this.score);

  final int pin;
  final String officeNorm;
  final String village;
  final double score;
}

String _key(int pin, String office) => '$pin|${normalizePlace(office)}';

class VillageBook {
  VillageBook(List<VillageList> lists) {
    for (final l in lists) {
      if (l.villages.isEmpty) continue;
      final k = _key(l.pin, l.office);
      final mine = _byOffice[k] ??= [];
      for (final v in l.villages) {
        if (!mine.contains(v)) mine.add(v);
      }
    }
  }

  factory VillageBook.fromJson(List<Map<String, Object?>> json) => VillageBook([for (final j in json) VillageList.fromJson(j)]);

  static final empty = VillageBook(const []);

  final Map<String, List<String>> _byOffice = {};

  bool get isEmpty => _byOffice.isEmpty;

  /// Villages under the office [name] with [pin].
  List<String> of(int pin, String name) => _byOffice[_key(pin, name)] ?? const [];

  /// Villages whose name looks like [query] (spelling-tolerant), best first.
  List<VillageHit> find(String query, {double min = 0.6}) {
    final q = normalizePlace(query);
    if (q.length < 2) return const [];
    final qk = phoneticKey(q);
    final out = <VillageHit>[];
    _byOffice.forEach((k, villages) {
      final i = k.indexOf('|');
      final pin = int.parse(k.substring(0, i));
      final office = k.substring(i + 1);
      for (final v in villages) {
        final n = normalizePlace(v);
        var s = n == q ? 1.0 : (n.startsWith(q) ? 0.97 : placeSimilarity(q, n, queryKey: qk));
        if (s < min && n.split(' ').any((w) => w == q || (q.length >= 3 && w.startsWith(q)))) s = 0.9;
        if (s >= min) out.add(VillageHit(pin, office, v, s));
      }
    });
    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }
}

/// [lists] with the villages of office [name] / [pin] set to [villages]
/// (empty removes the entry).
List<VillageList> setVillages(List<VillageList> lists, int pin, String name, List<String> villages) {
  final k = _key(pin, name);
  final clean = <String>[];
  for (final v in villages) {
    final t = v.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isNotEmpty && !clean.any((c) => normalizePlace(c) == normalizePlace(t))) clean.add(t);
  }
  return [
    for (final l in lists)
      if (_key(l.pin, l.office) != k) l,
    if (clean.isNotEmpty) VillageList(pin: pin, office: name, villages: clean),
  ];
}

/// Moves villages from an office to its new name / PIN after an edit.
List<VillageList> moveVillages(List<VillageList> lists, int fromPin, String fromName, int toPin, String toName) {
  final from = _key(fromPin, fromName);
  if (from == _key(toPin, toName)) return lists;
  final moving = [
    for (final l in lists)
      if (_key(l.pin, l.office) == from) ...l.villages,
  ];
  if (moving.isEmpty) return lists;
  final rest = [
    for (final l in lists)
      if (_key(l.pin, l.office) != from) l,
  ];
  final existing = VillageBook(rest).of(toPin, toName);
  return setVillages(rest, toPin, toName, [...existing, ...moving]);
}
