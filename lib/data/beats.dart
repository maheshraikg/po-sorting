/// Postman beats of delivery offices: beat number and the areas (streets,
/// colonies, buildings) it serves. The user's own data, kept in settings:
/// [{office, pin, beat, areas: [..]}].
library;

import '../core/fuzzy.dart';

class Beat {
  const Beat({required this.office, required this.pin, required this.beat, this.areas = const []});

  factory Beat.fromJson(Map<String, Object?> j) => Beat(
    office: j['office'] as String? ?? '',
    pin: (j['pin'] as num?)?.toInt() ?? 0,
    beat: '${j['beat'] ?? ''}',
    areas: [for (final a in (j['areas'] as List? ?? const [])) '$a'],
  );

  final String office;
  final int pin;

  /// Beat number as written ("1", "12A").
  final String beat;
  final List<String> areas;

  Map<String, Object?> toJson() => {'office': office, 'pin': pin, 'beat': beat, 'areas': areas};

  bool sameBeat(Beat o) => o.pin == pin && normalizePlace(o.office) == normalizePlace(office) && o.beat.trim().toLowerCase() == beat.trim().toLowerCase();

  Beat copyWith({String? office, int? pin, String? beat, List<String>? areas}) =>
      Beat(office: office ?? this.office, pin: pin ?? this.pin, beat: beat ?? this.beat, areas: areas ?? this.areas);
}

/// Splits a "Serving areas" cell into areas: commas, semicolons, new lines
/// or runs of 2+ spaces separate them ("Michigan compound,  Adishakti
/// colony" / "Canara Bank  Solanki complex").
List<String> splitAreas(String text) {
  final out = <String>[];
  for (final p in text.replaceAll('"', ' ').replaceAll('‌', '').split(RegExp(r'[,;\n]|\s{2,}'))) {
    final t = p.trim().replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'^[.\-–]+|[.\-–]+$'), '').trim();
    if (t.isNotEmpty && !out.any((x) => x.toLowerCase() == t.toLowerCase())) out.add(t);
  }
  return out;
}

String _beatNo(String s) {
  final t = s.trim();
  final d = double.tryParse(t);
  return d != null && d == d.roundToDouble() ? '${d.toInt()}' : t;
}

/// Reads beats from a sheet like "Beat wise sorting areas": a header row
/// with Post office / Pincode / Beat / Areas (title rows above it are
/// skipped; blank office or PIN cells repeat the row above).
List<Beat> readBeats(List<List<String>> rows) {
  int? head;
  for (var i = 0; i < rows.length && i < 15; i++) {
    final h = rows[i].map((c) => c.toLowerCase()).toList();
    if (h.where((c) => c.trim().isNotEmpty).length >= 3 && h.any((c) => c.contains('beat')) && h.any((c) => c.contains('pin') || c.contains('area'))) {
      head = i;
      break;
    }
  }
  if (head == null) return const [];
  final h = rows[head].map((c) => c.toLowerCase().trim()).toList();
  int col(bool Function(String) test) => h.indexWhere(test);
  final cOffice = col((c) => c.contains('office') || c == 'po' || c.contains('post'));
  final cPin = col((c) => c.contains('pin'));
  final cBeat = col((c) => c.contains('beat'));
  final cAreas = col((c) => c.contains('area') || c.contains('serving') || c.contains('street') || c.contains('locality'));
  if (cBeat < 0 || cAreas < 0) return const [];
  String at(List<String> r, int i) => i >= 0 && i < r.length ? r[i].trim() : '';
  final out = <Beat>[];
  var office = '';
  var pin = 0;
  for (final r in rows.skip(head + 1)) {
    if (at(r, cOffice).isNotEmpty) office = at(r, cOffice);
    final p = int.tryParse(_beatNo(at(r, cPin)));
    if (p != null) pin = p;
    final beat = _beatNo(at(r, cBeat));
    final areas = splitAreas(at(r, cAreas));
    if (beat.isEmpty && areas.isEmpty) continue;
    out.add(Beat(office: office, pin: pin, beat: beat, areas: areas));
  }
  return out;
}

/// Rows for a "Beats" sheet (export / share).
List<List<String>> beatsTable(List<Beat> beats) => [
  ['Name of Post Office', 'Pincode', 'Beat No.', 'Serving Areas'],
  for (final b in beats) [b.office, b.pin == 0 ? '' : '${b.pin}', b.beat, b.areas.join(', ')],
];

/// [beats] with [add] merged in: a beat already there gets the new areas
/// added; others are appended. Returns the list and how many areas / beats
/// were new.
(List<Beat>, int) mergeBeats(List<Beat> beats, List<Beat> add) {
  final out = [...beats];
  var n = 0;
  for (final b in add) {
    final i = out.indexWhere((x) => x.sameBeat(b));
    if (i < 0) {
      out.add(b);
      n++;
      continue;
    }
    final have = out[i].areas;
    final more = [
      for (final a in b.areas)
        if (!have.any((x) => x.toLowerCase() == a.toLowerCase())) a,
    ];
    if (more.isNotEmpty) {
      out[i] = out[i].copyWith(areas: [...have, ...more]);
      n++;
    }
  }
  return (out, n);
}

class BeatHit {
  const BeatHit(this.beat, this.areas, this.score);

  final Beat beat;

  /// The areas that matched (empty when the office / PIN / beat matched).
  final List<String> areas;
  final double score;
}

/// Beats for [query]: an area name (spelling-tolerant), office name, PIN or
/// beat number ("beat 5", "5").
List<BeatHit> searchBeats(List<Beat> beats, String query) {
  final q = normalizePlace(query);
  if (q.isEmpty) return const [];
  final digits = RegExp(r'^\d+$').hasMatch(q.replaceAll(' ', ''));
  final beatQ = RegExp(r'^(beat|b)\s*(\w+)$').firstMatch(q)?.group(2);
  final qk = phoneticKey(q);
  final out = <BeatHit>[];
  for (final b in beats) {
    if (beatQ != null) {
      if (b.beat.toLowerCase() == beatQ) out.add(BeatHit(b, const [], 1));
      continue;
    }
    if (digits) {
      final d = q.replaceAll(' ', '');
      if ('${b.pin}'.startsWith(d) || b.beat == d) out.add(BeatHit(b, const [], b.beat == d ? 1 : 0.9));
      continue;
    }
    final hits = <String>[];
    var best = 0.0;
    for (final a in b.areas) {
      final n = normalizePlace(a);
      double s;
      if (n.contains(q)) {
        s = n.startsWith(q) || n.contains(' $q') ? 1 : 0.95;
      } else if (q.length >= 4) {
        s = placeSimilarity(q, n, queryKey: qk);
        for (final w in n.split(' ')) {
          if (w.length >= 3) {
            final ws = placeSimilarity(q, w, queryKey: qk);
            if (ws > s) s = ws;
          }
        }
      } else {
        s = 0;
      }
      if (s >= 0.78) {
        hits.add(a);
        if (s > best) best = s;
      }
    }
    if (hits.isEmpty && normalizePlace(b.office).contains(q)) best = 0.7;
    if (best > 0) out.add(BeatHit(b, hits, best));
  }
  out.sort((a, b) {
    final c = b.score.compareTo(a.score);
    if (c != 0) return c;
    final p = a.beat.pin.compareTo(b.beat.pin);
    return p != 0 ? p : (int.tryParse(a.beat.beat) ?? 1 << 20).compareTo(int.tryParse(b.beat.beat) ?? 1 << 20);
  });
  return out;
}
