/// Village directory sheets ("Name of the village | Name of the PO |
/// Account office | Pincode", taluk title rows, two-row headers) → villages
/// under the matching office of the PIN directory.
library;

import '../core/fuzzy.dart';
import 'directory_repo.dart';
import 'models/office.dart';

class VillageRow {
  const VillageRow({required this.village, required this.po, this.account = '', this.pin});

  final String village;

  /// Post office (usually the BO) that serves the village.
  final String po;
  final String account;
  final int? pin;
}

/// Reads village rows. The header may span two rows ("Name of the" /
/// "village"); rows with only a taluk name and repeated headers are skipped.
List<VillageRow> readVillageSheet(List<List<String>> rows) {
  for (var i = 0; i < rows.length && i < 30; i++) {
    String head(int c) => [if (c < rows[i].length) rows[i][c], if (i + 1 < rows.length && c < rows[i + 1].length) rows[i + 1][c]].join(' ').toLowerCase();
    final width = rows[i].length;
    final heads = [for (var c = 0; c < width; c++) head(c)];
    final cVillage = heads.indexWhere((h) => h.contains('village'));
    final cPin = heads.indexWhere((h) => h.contains('pin'));
    if (cVillage < 0 || cPin < 0) continue;
    var cPo = heads.indexWhere((h) => (RegExp(r'\bpo\b|post|\bbo\b').hasMatch(h) || h == 'office') && !h.contains('account'));
    if (cPo < 0) cPo = heads.indexWhere((h) => h.contains('office') && !h.contains('account'));
    final cAcc = heads.indexWhere((h) => h.contains('account'));
    if (cPo < 0) continue;
    String at(List<String> r, int c) => c >= 0 && c < r.length ? r[c].trim() : '';
    final out = <VillageRow>[];
    for (final r in rows.skip(i + 1)) {
      final village = at(r, cVillage), po = at(r, cPo);
      if (village.isEmpty || po.isEmpty) continue;
      final lv = village.toLowerCase();
      if (lv.contains('village') || lv.startsWith('name of')) continue;
      final p = at(r, cPin).replaceAll(RegExp(r'\.0+$'), '');
      out.add(VillageRow(village: village, po: po, account: at(r, cAcc), pin: RegExp(r'^\d{6}$').hasMatch(p) ? int.parse(p) : null));
    }
    if (out.isNotEmpty) return out;
  }
  return const [];
}

/// "Abbana BO", "Alur S.O (Hassan)" → "abbana", "alur".
String officeKey(String name) =>
    normalizePlace(name.replaceAll(RegExp(r'\(.*?\)'), ' ').replaceAll(RegExp(r'\b(b\.?\s?o|s\.?\s?o|h\.?\s?o|p\.?\s?o)\b\.?', caseSensitive: false), ' '));

/// Short forms: "KH Kote" ~ "Kenchammanahosakote", "C.R.Patna" ~
/// "Channarayapatna", "S.Belagola" ~ "Shravanabelagola" ([raw] is the name
/// as written; normalising would join "kh kote" into one word).
double _abbrev(String raw, String cand) {
  final t = raw.toLowerCase().replaceAll(RegExp(r'\(.*?\)'), ' ').split(RegExp(r'[^a-z]+')).where((w) => w.isNotEmpty).toList();
  if (t.isNotEmpty && RegExp(r'^(bo|so|ho|po)$').hasMatch(t.last)) t.removeLast();
  if (t.length < 2 || t.sublist(0, t.length - 1).any((w) => w.length > 2)) return 0;
  final initials = t.sublist(0, t.length - 1).join();
  final last = t.last;
  final c = cand.replaceAll(' ', '');
  if (last.length < 3 || !c.startsWith(initials[0]) || c.length <= last.length + initials.length) return 0;
  final tail = c.substring(c.length - last.length);
  if (tail == last) return 0.9;
  return phoneticKey(tail) == phoneticKey(last) ? 0.86 : 0;
}

double _score(String raw, String k, String officeName) {
  final o = officeKey(officeName);
  final s = placeSimilarity(k, o);
  final a = _abbrev(raw, o);
  return s > a ? s : a;
}

class VillageMatch {
  const VillageMatch(this.row, this.office);

  final VillageRow row;

  /// The office the village goes under (null = not found).
  final Office? office;
}

/// Finds the office of each row: the PO at its PIN (spelling-tolerant), else
/// a PO of that name in the same sorting district, else the account office.
Future<List<VillageMatch>> matchVillages(DirectoryRepo dir, List<VillageRow> rows) async {
  final byPin = <int, List<Office>>{};
  final byArea = <String, List<Office>>{};
  final cache = <String, Office?>{};
  String? area; // first 3 digits of the last good PIN

  Future<Office?> find(String name, int? pin, String? district) async {
    final k = officeKey(name);
    if (k.length < 3) return null;
    final key = '$k|$pin|$district';
    if (cache.containsKey(key)) return cache[key];
    Office? best;
    var score = 0.0;
    if (pin != null) {
      for (final o in byPin[pin] ??= await dir.officesForPin(pin)) {
        final s = _score(name, k, o.officeName);
        if (s > score) {
          score = s;
          best = o;
        }
      }
      if (score < 0.78) best = null;
    }
    // A loose match at the PIN loses to the exact name elsewhere in the
    // district (the sheet's PIN is sometimes wrong).
    if ((best == null || score < 0.95) && district != null) {
      final atPin = best, pinScore = best == null ? 0.0 : score;
      score = 0;
      best = null;
      final lo = int.parse(district.padRight(6, '0')), hi = int.parse(district.padRight(6, '9'));
      for (final o in byArea[district] ??= await dir.officesInRange(lo, hi)) {
        final s = _score(name, k, o.officeName);
        if (s > score) {
          score = s;
          best = o;
        }
      }
      if (score < 0.86 || (atPin != null && score < 0.97)) {
        best = atPin;
        score = pinScore;
      }
    }
    return cache[key] = best;
  }

  final out = <VillageMatch>[];
  for (final r in rows) {
    if (r.pin != null) area = '${r.pin}'.substring(0, 3);
    final district = r.pin == null ? area : '${r.pin}'.substring(0, 3);
    var o = await find(r.po, r.pin, district);
    if (o == null && r.account.isNotEmpty) o = await find(r.account, r.pin, district);
    out.add(VillageMatch(r, o));
  }
  return out;
}
