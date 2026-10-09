/// Builds flashcards and quiz questions from the active scheme.
library;

import 'dart:math';

import '../../core/constants.dart';
import '../../core/fuzzy.dart';
import '../../data/directory_repo.dart';
import '../../data/models/office.dart';
import '../../data/models/scheme.dart';
import '../../data/resolver.dart';
import '../../data/scheme_repo.dart';

enum FlashMode { bag, air, hub }

/// Part of the scheme practised with bag flashcards / quiz.
enum LearnSection {
  all,

  /// TD lines on the Mangalore side (every TD line except the Udupi side).
  mangaloreTd,

  /// TD articles for the Udupi side: PIN → post office.
  udupiTd,

  /// Branch offices on TD lines: BO name → PIN.
  bo,

  /// Non-TD bags.
  nonTd,
}

/// What the questions ask: the line / bag, the office's PIN code, the
/// office at a PIN (with its BOs), or the office a BO comes under.
enum LearnAsk { sort, pin, office, parent }

/// One PIN of the PIN book: its head office, its branch offices and line.
class PinBookEntry {
  const PinBookEntry({required this.pin, this.head, this.bos = const [], this.line = ''});

  final int pin;

  /// "Puttur SO" (null when the directory has only BOs at this PIN).
  final String? head;
  final List<String> bos;
  final String line;
}

/// Quiz kinds (see QuizScreen) that are office ↔ PIN practice.
bool isPinQuizKind(String kind) =>
    kind == 'quiz-bag-bo' || kind.endsWith('-pin') || kind.endsWith('-office') || kind.endsWith('-parent');

final _sixDigits = RegExp(r'^\d{6}$');
final _parentAnswer = RegExp(r' – \d{6}$');

/// Practice from past mistakes: each question with its right answer, the
/// wrong choice made before and other answers of the same kind.
List<QuizQuestion> mistakeQuiz(List<({String kind, String question, String correct, String? chosen})> mistakes, {Random? random, int count = 20}) {
  final rnd = random ?? Random();
  int type(String kind, String answer) => kind.endsWith('-parent') || _parentAnswer.hasMatch(answer) ? 2 : _sixDigits.hasMatch(answer) ? 1 : 0;
  final byType = <int, Set<String>>{};
  for (final m in mistakes) {
    (byType[type(m.kind, m.correct)] ??= {}).add(m.correct);
  }
  final out = <QuizQuestion>[];
  for (final m in mistakes.take(count)) {
    final t = type(m.kind, m.correct);
    final others = {...byType[t]!}..remove(m.correct);
    final opts = <String>{m.correct};
    if (m.chosen != null && m.chosen!.isNotEmpty && m.chosen != m.correct) opts.add(m.chosen!);
    for (final o in others.toList()..shuffle(rnd)) {
      if (opts.length >= 4) break;
      opts.add(o);
    }
    if (opts.length < 2) continue;
    final card = LearnCard(
      key: 'mistake:${m.question}',
      prompt: m.question,
      answer: m.correct,
      isPin: _sixDigits.hasMatch(m.question),
      asksPin: t == 1,
      asksParent: t == 2,
      asksOffice: t == 0 && _sixDigits.hasMatch(m.question),
      category: m.kind.contains('-nonTd') ? kCatNonTD : null,
    );
    out.add(QuizQuestion(card, opts.toList()..shuffle(rnd)));
  }
  return out..shuffle(rnd);
}

/// The Udupi-side TD line(s): any bag whose code or name says "Udupi".
bool isUdupiSideBag(Bag b) => '${b.code} ${b.name}'.toLowerCase().contains('udupi');

final _officeSuffix = RegExp(r'\s+(S\.?O|B\.?O|P\.?O)\.?$', caseSensitive: false);

/// "Hejamadi SO" → "Hejamadi", "Udupi HO SO" → "Udupi HO".
String _officeLabel(BagRule r) => (r.officeName ?? r.remarks).trim().replaceFirst(_officeSuffix, '').trim();

class LearnCard {
  const LearnCard({
    required this.key,
    required this.prompt,
    required this.answer,
    this.answerDetail = '',
    this.prefix,
    this.isPin = true,
    this.category,
    this.asksOffice = false,
    this.asksPosition = false,
    this.asksPin = false,
    this.asksParent = false,
    this.near,
  });

  /// The answer is the SO / HO this branch office comes under.
  final bool asksParent;

  /// PIN the card is about: quiz choices come from nearby PINs, so the
  /// answer is not given away by a far-off district.
  final int? near;

  /// The answer is the PIN of this branch office.
  final bool asksPin;

  /// Cards with the same kind share answer options (bag / office / PIN / position).
  int get answerKind => asksParent ? 4 : asksOffice ? 1 : asksPin ? 2 : asksPosition ? 3 : 0;

  /// The answer is the office's position on its line.
  final bool asksPosition;

  /// The answer is the post office with this PIN (Udupi side), not a bag.
  final bool asksOffice;

  /// Mode the question is asked in (TD / Non-TD); null = any.
  final String? category;

  /// Stable id for Leitner boxes, e.g. "bag:574201".
  final String key;

  /// PIN or place name shown on the card.
  final String prompt;

  /// Bag code / air code / hub route.
  final String answer;
  final String answerDetail;

  /// First three digits (for weak-area stats).
  final String? prefix;
  final bool isPin;
}

/// One stop of a line, for study mode.
class LineStop {
  const LineStop({required this.office, this.position = '', this.pin});

  final String office;
  final String position;
  final int? pin;
}

class QuizQuestion {
  const QuizQuestion(this.card, this.options);

  final LearnCard card;
  final List<String> options;
}

/// Leitner intervals by box (1 = new / wrong, 5 = well known).
const List<Duration> kLeitnerIntervals = [
  Duration.zero,
  Duration.zero,
  Duration(days: 1),
  Duration(days: 3),
  Duration(days: 7),
  Duration(days: 14),
];

int nextBox(int box, bool correct) => correct ? min(box + 1, 5) : 1;

int dueAfter(int box, DateTime now) => now.add(kLeitnerIntervals[box]).millisecondsSinceEpoch;

class LearnEngine {
  LearnEngine(
    this.scheme, {
    Iterable<int> directoryPins = const [],
    this._regions = const {},
    this.branchOffices = const [],
    this.otherOffices = const [],
    Random? random,
  })
    : _pins = directoryPins.toList()..sort(),
      _rnd = random ?? Random();

  final ActiveScheme scheme;

  /// Offices (all types) at the TD PINs of the scheme, for BO practice; see
  /// [loadBranchOffices].
  final List<Office> branchOffices;

  /// Offices outside the TD area, for "office → PIN" in Non-TD.
  final List<Office> otherOffices;
  final List<int> _pins;
  final Map<int, ({List<String> districts, List<String> states})> _regions;
  final Random _rnd;

  List<int> _pinsIn(int lo, int hi) {
    var a = _lowerBound(lo);
    final out = <int>[];
    while (a < _pins.length && _pins[a] <= hi) {
      out.add(_pins[a++]);
    }
    return out;
  }

  int _lowerBound(int v) {
    var lo = 0, hi = _pins.length;
    while (lo < hi) {
      final m = (lo + hi) >> 1;
      if (_pins[m] < v) {
        lo = m + 1;
      } else {
        hi = m;
      }
    }
    return lo;
  }

  /// Representative PINs for a rule (up to [n]).
  List<int> _samplePins(MatchSpec m, {int n = 2}) {
    List<int> pool;
    switch (m.type) {
      case RuleType.exact:
        return [m.pin!];
      case RuleType.range:
        pool = _pinsIn(m.pinFrom!, m.pinTo!);
        if (pool.isEmpty) pool = {m.pinFrom!, m.pinTo!}.toList();
      case RuleType.prefix:
        final p = m.prefix!;
        pool = _pinsIn(int.parse(p.padRight(6, '0')), int.parse(p.padRight(6, '9')));
      default:
        return const [];
    }
    pool.shuffle(_rnd);
    return pool.take(n).toList();
  }

  ResolveQuery _q(int pin, String? category) {
    final r = _regions[pin];
    return ResolveQuery(pin: pin, districtNorms: r?.districts ?? const [], stateNorms: r?.states ?? const [], category: category);
  }

  /// Sections of the scheme that have something to practise.
  List<LearnSection> sections() {
    final has = <LearnSection>{};
    for (final r in scheme.bagResolver.rules) {
      final cat = r.category;
      final udupi = isUdupiSideBag(scheme.bagFor(r));
      if (cat == null || cat.isEmpty || cat == kCatTD) {
        has.add(udupi ? LearnSection.udupiTd : LearnSection.mangaloreTd);
        if (r.match.type == RuleType.exact) has.add(LearnSection.bo);
      }
      if (cat == null || cat.isEmpty || cat == kCatNonTD) has.add(LearnSection.nonTd);
    }
    if (has.length < 2) return const [];
    return [LearnSection.all, ...LearnSection.values.where(has.contains)];
  }

  List<LearnCard> cards(FlashMode mode, {Set<int>? onlyPins, LearnSection section = LearnSection.all, LearnAsk ask = LearnAsk.sort}) {
    if (mode == FlashMode.bag && onlyPins == null) {
      if (ask == LearnAsk.pin || (section == LearnSection.bo && ask != LearnAsk.parent)) return pinCards(section);
      if (ask == LearnAsk.office) return officeCards(section);
      if (ask == LearnAsk.parent) return parentCards();
    }
    if (mode == FlashMode.bag && onlyPins == null && section != LearnSection.all) {
      if (section == LearnSection.udupiTd) return _udupiCards();
      if (section == LearnSection.bo) return _boCards();
      final udupiCodes = {for (final b in scheme.bags.values) if (isUdupiSideBag(b)) b.code};
      bool td(String? c) => c == null || c == kCatTD;
      bool nonTd(String? c) => c == null || c == kCatNonTD;
      return [
        for (final c in cards(mode))
          if (section == LearnSection.nonTd ? nonTd(c.category) : td(c.category) && !udupiCodes.contains(c.answer)) c,
      ];
    }
    final out = <String, LearnCard>{};
    // A card is asked in the mode (TD / Non-TD / …) of the rule it came from.
    void addPin(int pin, [String? category]) {
      final key = '${mode.name}:${category ?? ''}:$pin';
      if (out.containsKey(key)) return;
      final q = _q(pin, category);
      switch (mode) {
        case FlashMode.bag:
          final r = scheme.bagResolver.resolve(q);
          if (r == null || r.level == RuleType.fallback) return;
          final bag = scheme.bagFor(r.rule);
          out[key] = LearnCard(key: key, prompt: '$pin', answer: bag.code, answerDetail: bag.name, prefix: '$pin'.substring(0, 3), category: category);
        case FlashMode.air:
          final r = scheme.airResolver.resolve(q);
          if (r == null) return;
          out[key] = LearnCard(key: key, prompt: '$pin', answer: r.rule.airCode, answerDetail: r.rule.stationName, prefix: '$pin'.substring(0, 3));
        case FlashMode.hub:
          final r = scheme.hubResolver.resolve(q);
          if (r == null) return;
          out[key] = LearnCard(key: key, prompt: '$pin', answer: r.rule.route, answerDetail: r.rule.remarks, prefix: '$pin'.substring(0, 3));
      }
    }

    if (onlyPins != null) {
      for (final p in onlyPins) {
        addPin(p);
      }
      return out.values.toList();
    }
    final rules = switch (mode) {
      FlashMode.bag => scheme.bagResolver.rules,
      FlashMode.air => scheme.airResolver.rules,
      FlashMode.hub => scheme.hubResolver.rules,
    };
    for (final Matchable r in rules) {
      final m = r.match;
      final cat = r.category == null || r.category!.isEmpty ? null : r.category;
      for (final p in _samplePins(m)) {
        addPin(p, cat);
      }
      // Name-based rules: office / district / state prompts.
      final name = switch (r) {
        BagRule b => b.officeName ?? b.district ?? b.state,
        AirCodeRule a => a.district ?? a.state,
        HubRule h => h.officeName ?? h.district ?? h.state,
        _ => null,
      };
      if (name != null && (m.type == RuleType.office || m.type == RuleType.district || m.type == RuleType.state)) {
        final key = '${mode.name}:${cat ?? ''}:${m.key}';
        final answer = switch (r) {
          BagRule b => (scheme.bagFor(b).code, scheme.bagFor(b).name),
          AirCodeRule a => (a.airCode, a.stationName),
          HubRule h => (h.route, h.remarks),
          _ => ('', ''),
        };
        out[key] = LearnCard(key: key, prompt: name, answer: answer.$1, answerDetail: answer.$2, isPin: false, category: cat);
      }
    }
    return out.values.toList();
  }

  /// PINs of the TD lines (exact PIN rules) → line.
  Map<int, String> _tdPinLines() => {
    for (final r in scheme.bagResolver.rules)
      if (_isTdRule(r) && r.match.type == RuleType.exact && r.match.pin != null) r.match.pin!: r.bagCode,
  };

  /// Offices at the TD PINs of [scheme] (branch offices and their SO / HO).
  static Future<List<Office>> loadBranchOffices(DirectorySource dir, ActiveScheme scheme) async {
    final pins = LearnEngine(scheme)._tdPinLines().keys.toSet();
    final prefixes = {for (final p in pins) p ~/ 1000};
    final out = <Office>[];
    for (final p in prefixes) {
      for (final o in await dir.officesInRange(p * 1000, p * 1000 + 999)) {
        if (pins.contains(o.pincode)) out.add(o);
      }
    }
    return out;
  }

  /// Branch offices on TD lines: BO name → PIN (answer shows SO and line).
  List<LearnCard> _boCards() {
    final lines = _tdPinLines();
    final byPin = <int, List<Office>>{};
    for (final o in branchOffices) {
      (byPin[o.pincode] ??= []).add(o);
    }
    final out = <String, LearnCard>{};
    for (final e in byPin.entries) {
      final line = lines[e.key];
      if (line == null) continue;
      final so = e.value.where((o) => o.officeType != 'BO').map((o) => o.officeName).firstOrNull;
      for (final o in e.value.where((o) => o.officeType == 'BO')) {
        final key = 'bo:${e.key}:${o.officeName}';
        out[key] = LearnCard(
          key: key,
          prompt: '${o.officeName} BO',
          answer: '${e.key}',
          answerDetail: so == null ? line : '$so · $line',
          prefix: '${e.key}'.substring(0, 3),
          isPin: false,
          category: kCatTD,
          asksPin: true,
          near: e.key,
        );
      }
    }
    return out.values.toList();
  }

  /// Offices at the TD PINs grouped by PIN, in PIN order, for the PIN book.
  List<PinBookEntry> pinBook(LearnSection section) {
    final lines = _tdPinLines();
    final udupi = {for (final b in scheme.bags.values) if (isUdupiSideBag(b)) b.code};
    final byPin = <int, List<Office>>{};
    for (final o in branchOffices) {
      final line = lines[o.pincode];
      if (line == null) continue;
      if (section == LearnSection.udupiTd && !udupi.contains(line)) continue;
      if (section == LearnSection.mangaloreTd && udupi.contains(line)) continue;
      (byPin[o.pincode] ??= []).add(o);
    }
    final pins = byPin.keys.toList()..sort();
    return [
      for (final p in pins)
        () {
          final os = byPin[p]!;
          final head = os.where((o) => o.officeType != 'BO').toList()
            ..sort((a, b) => _headRank(a.officeType).compareTo(_headRank(b.officeType)));
          final bos = [for (final o in os) if (o.officeType == 'BO') o.officeName]..sort();
          return PinBookEntry(pin: p, head: head.isEmpty ? null : '${head.first.officeName} ${head.first.officeType}'.trim(), bos: bos, line: lines[p]!);
        }(),
    ];
  }

  static int _headRank(String type) => switch (type) { 'HO' => 0, 'SO' => 1, 'PO' => 2, _ => 3 };

  /// "Which office has this PIN?": PIN → head office; the answer also lists
  /// the branch offices at that PIN, so they are learnt together.
  List<LearnCard> officeCards(LearnSection section) {
    final out = <String, LearnCard>{};
    if (section != LearnSection.nonTd) {
      for (final e in pinBook(section == LearnSection.bo ? LearnSection.all : section)) {
        if (e.head == null) continue;
        final key = 'office:${e.pin}';
        out[key] = LearnCard(
          key: key,
          prompt: '${e.pin}',
          answer: e.head!,
          answerDetail: e.bos.isEmpty ? e.line : '${e.line} · BO: ${e.bos.join(', ')}',
          prefix: '${e.pin}'.substring(0, 3),
          category: kCatTD,
          asksOffice: true,
          near: e.pin,
        );
      }
    }
    if (section == LearnSection.all || section == LearnSection.nonTd) {
      final lines = _tdPinLines();
      final seen = <int>{};
      final sorted = otherOffices.where((o) => o.officeType != 'BO' && !lines.containsKey(o.pincode)).toList()
        ..sort((a, b) => _headRank(a.officeType).compareTo(_headRank(b.officeType)));
      for (final o in sorted) {
        if (!seen.add(o.pincode)) continue;
        final key = 'office:${o.pincode}';
        out[key] = LearnCard(
          key: key,
          prompt: '${o.pincode}',
          answer: '${o.officeName} ${o.officeType}'.trim(),
          answerDetail: '${o.district}, ${o.state}',
          prefix: '${o.pincode}'.substring(0, 3),
          category: kCatNonTD,
          asksOffice: true,
          near: o.pincode,
        );
      }
    }
    return out.values.toList();
  }

  /// "This BO comes under which office?": BO → SO / HO at its PIN.
  List<LearnCard> parentCards() {
    final out = <String, LearnCard>{};
    for (final e in pinBook(LearnSection.all)) {
      if (e.head == null) continue;
      for (final bo in e.bos) {
        final key = 'parent:${e.pin}:$bo';
        out[key] = LearnCard(
          key: key,
          prompt: '$bo BO',
          answer: '${e.head!} – ${e.pin}',
          answerDetail: e.line,
          prefix: '${e.pin}'.substring(0, 3),
          isPin: false,
          category: kCatTD,
          asksParent: true,
          near: e.pin,
        );
      }
    }
    return out.values.toList();
  }

  /// "Which PIN for this office?" for a section: head / sub offices of the
  /// Mangalore-side or Udupi-side TD lines, branch offices, or Non-TD
  /// offices elsewhere (shown with district and state).
  List<LearnCard> pinCards(LearnSection section) {
    if (section == LearnSection.bo) return _boCards();
    final lines = _tdPinLines();
    final udupi = {for (final b in scheme.bags.values) if (isUdupiSideBag(b)) b.code};
    const heads = {'HO', 'SO', 'PO'};
    final out = <String, LearnCard>{};
    void add(Office o, String detail, String category) {
      final key = 'pin:${o.pincode}:${o.officeName}:${o.officeType}';
      out[key] = LearnCard(
        key: key,
        prompt: '${o.officeName} ${o.officeType}',
        answer: '${o.pincode}',
        answerDetail: detail,
        prefix: '${o.pincode}'.substring(0, 3),
        isPin: false,
        category: category,
        asksPin: true,
        near: o.pincode,
      );
    }

    final tdWanted = section == LearnSection.all || section == LearnSection.mangaloreTd || section == LearnSection.udupiTd;
    if (tdWanted) {
      for (final o in branchOffices) {
        if (!heads.contains(o.officeType)) continue;
        final line = lines[o.pincode];
        if (line == null) continue;
        final isUdupi = udupi.contains(line);
        if (section == LearnSection.udupiTd && !isUdupi) continue;
        if (section == LearnSection.mangaloreTd && isUdupi) continue;
        add(o, line, kCatTD);
      }
    }
    if (section == LearnSection.all || section == LearnSection.nonTd) {
      for (final o in otherOffices) {
        if (!heads.contains(o.officeType) || lines.containsKey(o.pincode)) continue;
        add(o, '${o.district}, ${o.state}', kCatNonTD);
      }
    }
    if (section == LearnSection.all) {
      for (final c in _boCards()) {
        out[c.key] = c;
      }
    }
    return out.values.toList();
  }

  /// Udupi-side TD: every PIN on the Udupi line → its post office.
  List<LearnCard> _udupiCards() {
    final out = <String, LearnCard>{};
    for (final r in scheme.bagResolver.rules) {
      final cat = r.category;
      if (cat != null && cat.isNotEmpty && cat != kCatTD) continue;
      final bag = scheme.bagFor(r);
      if (!isUdupiSideBag(bag)) continue;
      final office = _officeLabel(r);
      if (office.isEmpty) continue;
      for (final p in _samplePins(r.match, n: 1)) {
        final key = 'udupi:$p';
        out[key] = LearnCard(key: key, prompt: '$p', answer: office, answerDetail: bag.code, prefix: '$p'.substring(0, 3), category: kCatTD, asksOffice: true);
      }
    }
    return out.values.toList();
  }

  /// [count] questions with 4 options each (fewer when the scheme has fewer
  /// distinct answers).
  List<QuizQuestion> quiz(FlashMode mode, {int count = 20, LearnSection section = LearnSection.all, LearnAsk ask = LearnAsk.sort}) {
    final all = cards(mode, section: section, ask: ask)..shuffle(_rnd);
    final answers = all.map((c) => c.answer).toSet().toList();
    if (answers.length < 2) return const [];
    final byKind = <int, List<String>>{};
    final nearOf = <int, Map<String, int>>{};
    for (final c in all) {
      final l = byKind[c.answerKind] ??= [];
      if (!l.contains(c.answer)) l.add(c.answer);
      if (c.near != null) (nearOf[c.answerKind] ??= {}).putIfAbsent(c.answer, () => c.near!);
    }
    final picked = <LearnCard>[];
    while (picked.length < count && all.isNotEmpty) {
      picked.addAll(all.take(count - picked.length));
      if (all.length < count) break;
    }
    return [
      for (final c in picked)
        () {
          var others = byKind[c.answerKind]!.where((a) => a != c.answer).toList()..shuffle(_rnd);
          // Choices from nearby PINs, so the answer is not obvious.
          final near = nearOf[c.answerKind];
          if (c.near != null && near != null) {
            int dist(String a) => ((near[a] ?? 0) - c.near!).abs();
            others = (others..sort((a, b) => dist(a).compareTo(dist(b)))).take(6).toList()..shuffle(_rnd);
          }
          final opts = [c.answer, ...others.take(3)]..shuffle(_rnd);
          return QuizQuestion(c, opts);
        }(),
    ];
  }

  bool _isTdRule(BagRule r) => r.category == null || r.category!.isEmpty || r.category == kCatTD;

  /// TD lines that have offices or PINs to study, in line order.
  List<Bag> studyLines() {
    final codes = {for (final r in scheme.bagResolver.rules) if (_isTdRule(r)) r.bagCode}..removeWhere((c) => lineStops(c).isEmpty);
    return [for (final c in scheme.bagOrder) if (codes.contains(c)) scheme.bags[c]!, for (final c in codes) if (!scheme.bags.containsKey(c)) Bag(code: c)];
  }

  /// Offices / PINs of a TD line, in position order (stops without a
  /// position last, by PIN).
  List<LineStop> lineStops(String bagCode) {
    final offices = <({String office, String position})>[];
    final pins = <({String office, String position, int pin})>[];
    final seen = <String>{};
    for (final r in scheme.bagResolver.rules) {
      if (r.bagCode != bagCode || !_isTdRule(r)) continue;
      final m = r.match;
      final office = _officeLabel(r);
      final position = r.section.trim();
      if (m.type == RuleType.office && office.isNotEmpty) {
        if (seen.add('o|${office.toLowerCase()}|$position')) offices.add((office: office, position: position));
      } else if (m.type == RuleType.exact && m.pin != null) {
        if (seen.add('p|${m.pin}')) pins.add((office: office, position: position, pin: m.pin!));
      }
    }
    // The same office often has both a name rule and a PIN rule, spelt a
    // little differently ("Guthigare" / "Guthigar"): show it once, with its PIN.
    final pinOf = <int, int>{};
    final used = <int>{};
    for (var i = 0; i < offices.length; i++) {
      var best = -1;
      var bestScore = 0.0;
      for (var j = 0; j < pins.length; j++) {
        if (used.contains(j) || pins[j].office.isEmpty) continue;
        if (pins[j].position.isNotEmpty && offices[i].position.isNotEmpty && pins[j].position != offices[i].position) continue;
        final score = placeSimilarity(normalizePlace(offices[i].office), normalizePlace(pins[j].office));
        if (score > bestScore) {
          bestScore = score;
          best = j;
        }
      }
      if (best >= 0 && bestScore >= 0.75) {
        pinOf[i] = pins[best].pin;
        used.add(best);
      }
    }
    final out = <LineStop>[
      for (var i = 0; i < offices.length; i++) LineStop(office: offices[i].office, position: offices[i].position, pin: pinOf[i]),
      for (var j = 0; j < pins.length; j++)
        if (!used.contains(j)) LineStop(office: pins[j].office.isEmpty ? '${pins[j].pin}' : pins[j].office, position: pins[j].position, pin: pins[j].pin),
    ];
    int pos(LineStop s) => int.tryParse(s.position) ?? 1 << 30;
    out.sort((a, b) {
      final c = pos(a).compareTo(pos(b));
      if (c != 0) return c;
      return (a.pin ?? 0).compareTo(b.pin ?? 0);
    });
    return out;
  }

  /// Practice for one line: office → position, or PIN → office for stops
  /// without a position.
  List<QuizQuestion> lineQuiz(String bagCode, {int count = 15}) {
    final stops = lineStops(bagCode);
    final cards = <LearnCard>[
      for (final s in stops)
        if (s.position.isNotEmpty)
          LearnCard(key: 'line:$bagCode:${s.office}', prompt: s.office, answer: s.position, answerDetail: bagCode, isPin: false, category: kCatTD, asksPosition: true)
        else if (s.pin != null && s.office != '${s.pin}')
          LearnCard(key: 'line:$bagCode:${s.pin}', prompt: '${s.pin}', answer: s.office, answerDetail: bagCode, prefix: '${s.pin}'.substring(0, 3), category: kCatTD, asksOffice: true),
    ]..shuffle(_rnd);
    final out = <QuizQuestion>[];
    for (final c in cards.take(count)) {
      final answers = {for (final o in cards) if (o.asksPosition == c.asksPosition) o.answer}..remove(c.answer);
      if (answers.isEmpty) continue;
      final others = answers.toList()..shuffle(_rnd);
      out.add(QuizQuestion(c, [c.answer, ...others.take(3)]..shuffle(_rnd)));
    }
    return out;
  }

  /// Builds an engine with the directory data the [section] / [ask] needs.
  static Future<LearnEngine> load(
    DirectorySource dir,
    ActiveScheme scheme, {
    required Map<int, ({List<String> districts, List<String> states})> regions,
    LearnSection section = LearnSection.all,
    LearnAsk ask = LearnAsk.sort,
    Random? random,
  }) async {
    final asksOffices = ask != LearnAsk.sort;
    final needTd = section == LearnSection.bo || (asksOffices && section != LearnSection.nonTd);
    final needOther = (ask == LearnAsk.pin || ask == LearnAsk.office) && (section == LearnSection.nonTd || section == LearnSection.all);
    final td = needTd ? await loadBranchOffices(dir, scheme) : const <Office>[];
    final other = needOther ? await dir.randomOffices(600) : const <Office>[];
    return LearnEngine(scheme, directoryPins: regions.keys, regions: regions, branchOffices: td, otherOffices: other, random: random);
  }
}
