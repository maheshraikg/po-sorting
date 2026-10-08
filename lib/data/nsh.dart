/// National Sorting Hubs (NSH) and Intra-Circle Hubs (ICH) for speed post
/// from the NSH Mangalore sorting extract. Separate from the Non-TD bag (PH):
/// a PIN has a PH bag and an NSH / ICH.
library;

import 'dart:typed_data';

import 'import/table_reader.dart';

const String kNshAsset = 'assets/schemes/nsh_mangalore.csv';

/// RMS L1 and NPH (parcel hub) per PIN, from the MR RMS sorting data
/// (same columns as the NSH table; Kind = L1 / NPH).
const String kRmsL1Asset = 'assets/schemes/rms_l1.csv';
const String kRmsNphAsset = 'assets/schemes/rms_nph.csv';

/// The editable hub tables: bundled asset, and where the user's copy is kept.
enum HubTableKind {
  nsh(kNshAsset, 'nshCsv'),
  l1(kRmsL1Asset, 'l1Csv'),
  nph(kRmsNphAsset, 'nphCsv');

  const HubTableKind(this.asset, this.prefsKey);

  final String asset;
  final String prefsKey;
}

class NshHub {
  const NshHub({required this.name, required this.kind, required this.circle, required this.series, this.mappedTo = '', this.exclude = const {}});

  /// "MUMBAI NSH", "KOZHIKODE ICH".
  final String name;

  /// "NSH" or "ICH".
  final String kind;
  final String circle;

  /// PIN series as written on the sheet ("400-403, 423-425, 4152, …").
  final String series;

  /// NSH an ICH is mapped to ("KOCHI NSH"), or empty.
  final String mappedTo;

  /// Series to leave out for this hub (normally empty: the sheet decides).
  final Set<String> exclude;

  bool get isIch => kind == 'ICH';
}

class NshMatch {
  const NshMatch(this.hub, this.matched, {this.alsoListed = const []});

  final NshHub hub;

  /// Other hubs the sheet lists the same series under (shown as well, so
  /// nothing is decided that the sheet does not say).
  final List<NshHub> alsoListed;

  /// The series that matched: "4152", "416510-416525" or a full PIN.
  final String matched;
}

/// PIN → NSH / ICH: exact PIN, then 6-digit range, then longest prefix.
class NshTable {
  NshTable(this.hubs) {
    for (final h in hubs) {
      for (final t in seriesTokens(h.series)) {
        if (h.exclude.contains(t.$1)) continue;
        if (t.$2 == null && t.$1.length == 6) {
          _add(_exact[int.parse(t.$1)] ??= [], h);
        } else if (t.$2 != null) {
          _ranges.add((int.parse(t.$1), int.parse(t.$2!), h));
        } else {
          _add(_prefix[t.$1] ??= [], h);
        }
      }
    }
    _ranges.sort((a, b) => (a.$2 - a.$1).compareTo(b.$2 - b.$1));
  }

  final List<NshHub> hubs;
  final _exact = <int, List<NshHub>>{};
  final _ranges = <(int, int, NshHub)>[];
  final _prefix = <String, List<NshHub>>{};

  static void _add(List<NshHub> l, NshHub h) {
    if (!l.contains(h)) l.add(h);
  }

  bool get isEmpty => hubs.isEmpty;

  /// The first hub in sheet order answers; the others are shown with it.
  static NshMatch _match(List<NshHub> hubs, String matched) => NshMatch(hubs.first, matched, alsoListed: hubs.skip(1).toList());

  NshMatch? resolve(String digits) {
    if (digits.length == 6) {
      final pin = int.tryParse(digits);
      if (pin == null) return null;
      final e = _exact[pin];
      if (e != null) return _match(e, digits);
      final inRange = [for (final r in _ranges) if (r.$1 <= pin && pin <= r.$2) r];
      if (inRange.isNotEmpty) {
        final width = inRange.first.$2 - inRange.first.$1;
        final same = [for (final r in inRange) if (r.$2 - r.$1 == width) r];
        return _match([for (final r in same) r.$3], '${same.first.$1}-${same.first.$2}');
      }
    }
    for (var l = digits.length < 6 ? digits.length : 5; l >= 3; l--) {
      final h = _prefix[digits.substring(0, l)];
      if (h != null) return _match(h, digits.substring(0, l));
    }
    return null;
  }

  /// The table as a CSV file (same columns as the bundled sheet).
  String toCsv() => writeCsv([
    ['Hub', 'Kind', 'Circle', 'Series', 'Mapped To', 'Exclude'],
    for (final h in hubs) [h.name, h.kind, h.circle, h.series, h.mappedTo, h.exclude.join(', ')],
  ]);

  static NshTable parse(Uint8List bytes) {
    final t = readTable(bytes, 'nsh.csv');
    final rows = t.sheets[t.defaultSheet]!;
    final head = [for (final h in rows.first) h.trim().toLowerCase()];
    int col(String name) => head.indexOf(name);
    String cell(List<String> r, int i) => i >= 0 && i < r.length ? r[i].trim() : '';
    final hub = col('hub'), kind = col('kind'), circle = col('circle'), series = col('series'), mapped = col('mapped to'), exclude = col('exclude');
    return NshTable([
      for (final r in rows.skip(1))
        if (cell(r, hub).isNotEmpty)
          NshHub(
            name: cell(r, hub),
            kind: cell(r, kind),
            circle: cell(r, circle),
            series: cell(r, series),
            mappedTo: cell(r, mapped),
            exclude: {for (final x in cell(r, exclude).split(',')) if (x.trim().isNotEmpty) x.trim()},
          ),
    ]);
  }
}

/// "400-403, 4152, 416510-416525" → [("400",null)…("403",null), ("4152",null), ("416510","416525")].
/// Short ranges ("400-403") are expanded into single prefixes.
List<(String, String?)> seriesTokens(String series) {
  final out = <(String, String?)>[];
  for (final part in series.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
    final m = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(part);
    if (m == null) {
      if (RegExp(r'^\d{3,6}$').hasMatch(part)) out.add((part, null));
      continue;
    }
    final a = m.group(1)!, b = m.group(2)!;
    if (a.length == 6 && b.length == 6) {
      out.add((a, b));
    } else if (a.length == b.length) {
      for (var i = int.parse(a); i <= int.parse(b); i++) {
        out.add((i.toString().padLeft(a.length, '0'), null));
      }
    }
  }
  return out;
}
