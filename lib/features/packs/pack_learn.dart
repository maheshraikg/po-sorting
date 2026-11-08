/// Learn an office pack's data (e.g. Hubballi RMS) for new sorting
/// assistants: PIN → bag, office → bag, office → PIN, area → beat and
/// village → BO quizzes, and a study list of every bag with its offices.
library;

import 'dart:math';

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/files.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/beats.dart';
import '../../data/directory_repo.dart';
import '../../data/models/office.dart';
import '../../data/villages.dart';
import '../learn/learn_engine.dart';
import '../learn/quiz_screen.dart';
import 'office_packs.dart';

/// One bag of the pack: its PIN, list name and the offices at that PIN.
class PackBag {
  const PackBag(this.code, this.group, this.pin, this.offices);

  final String code;
  final String group;
  final int pin;
  final List<Office> offices;
}

/// The pack's learning material.
class PackLesson {
  PackLesson(this.bags, this.data);

  final List<PackBag> bags;
  final PackData data;

  static Future<PackLesson> load(OfficePack p, DirectoryRepo dir, Future<Uint8List> Function(String) loadAsset) async {
    final d = await loadPack(p, loadAsset);
    final bags = <PackBag>[];
    for (final r in d.lines) {
      final pin = r.match.pin;
      if (pin == null) continue;
      bags.add(PackBag(r.bagCode, r.bagName, pin, await dir.officesForPin(pin)));
    }
    return PackLesson(bags, d);
  }

  int get officeCount => bags.fold(0, (n, b) => n + b.offices.length);

  /// [answer] plus up to 3 other answers, nearby ones (same list / district)
  /// first so the choice is not given away.
  static List<String> _options(String answer, List<String> near, List<String> all, Random rnd) {
    final opts = <String>{answer};
    for (final pool in [near, all]) {
      for (final o in [...pool]..shuffle(rnd)) {
        if (opts.length >= 4) break;
        if (o != answer) opts.add(o);
      }
    }
    return opts.toList()..shuffle(rnd);
  }

  List<QuizQuestion> pinToBag([Random? random]) {
    final rnd = random ?? Random();
    final all = [for (final b in bags) b.code];
    return [
      for (final b in bags)
        QuizQuestion(
          LearnCard(key: 'packbag:${b.pin}', prompt: '${b.pin}', answer: b.code, answerDetail: b.group, prefix: '${b.pin}'.substring(0, 3)),
          _options(
            b.code,
            [
              for (final x in bags)
                if (x.group == b.group) x.code,
            ],
            all,
            rnd,
          ),
        ),
    ];
  }

  List<QuizQuestion> officeToBag([Random? random]) {
    final rnd = random ?? Random();
    final all = [for (final b in bags) b.code];
    return [
      for (final b in bags)
        for (final o in b.offices)
          QuizQuestion(
            LearnCard(
              key: 'packoffice:${o.pincode}:${o.officeName}',
              prompt: '${o.officeName} ${o.officeType}'.trim(),
              answer: b.code,
              answerDetail: '${b.pin} · ${b.group}',
              isPin: false,
            ),
            _options(
              b.code,
              [
                for (final x in bags)
                  if (x.group == b.group) x.code,
              ],
              all,
              rnd,
            ),
          ),
    ];
  }

  List<QuizQuestion> officeToPin([Random? random]) {
    final rnd = random ?? Random();
    final all = [for (final b in bags) '${b.pin}'];
    return [
      for (final b in bags)
        for (final o in b.offices)
          QuizQuestion(
            LearnCard(
              key: 'packpin:${o.pincode}:${o.officeName}',
              prompt: '${o.officeName} ${o.officeType}'.trim(),
              answer: '${b.pin}',
              answerDetail: b.code,
              isPin: false,
              asksPin: true,
            ),
            _options(
              '${b.pin}',
              [
                for (final x in bags)
                  if ('${x.pin}'.substring(0, 4) == '${b.pin}'.substring(0, 4)) '${x.pin}',
              ],
              all,
              rnd,
            ),
          ),
    ];
  }

  /// Area → "Office · Beat N" (up to 3 areas per beat).
  List<QuizQuestion> areaToBeat([Random? random]) {
    final rnd = random ?? Random();
    String label(Beat b) => '${b.office} · Beat ${b.beat}';
    final all = [for (final b in data.beats) label(b)];
    return [
      for (final b in data.beats)
        for (final a in ([...b.areas]..shuffle(rnd)).take(3))
          QuizQuestion(
            LearnCard(key: 'packbeat:${b.pin}:${b.beat}:$a', prompt: a, answer: label(b), answerDetail: '${b.pin}', isPin: false),
            _options(
              label(b),
              [
                for (final x in data.beats)
                  if (x.office == b.office) label(x),
              ],
              all,
              rnd,
            ),
          ),
    ];
  }

  /// Village → "BO – PIN".
  List<QuizQuestion> villageToBo([Random? random]) {
    final rnd = random ?? Random();
    String label(VillageList v) => '${v.office} – ${v.pin}';
    final all = {for (final v in data.villages) label(v)}.toList();
    return [
      for (final v in data.villages)
        for (final name in v.villages)
          QuizQuestion(
            LearnCard(key: 'packvillage:${v.pin}:$name', prompt: name, answer: label(v), isPin: false),
            _options(
              label(v),
              [
                for (final x in data.villages)
                  if ('${x.pin}'.substring(0, 4) == '${v.pin}'.substring(0, 4)) label(x),
              ],
              all,
              rnd,
            ),
          ),
    ];
  }
}

class PackLearnScreen extends StatefulWidget {
  const PackLearnScreen({super.key, required this.pack, this.loadAsset = loadAssetBytes});

  final OfficePack pack;
  final Future<Uint8List> Function(String path) loadAsset;

  @override
  State<PackLearnScreen> createState() => _PackLearnScreenState();
}

class _PackLearnScreenState extends State<PackLearnScreen> {
  PackLesson? _lesson;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lesson == null) {
      PackLesson.load(widget.pack, context.services.directory, widget.loadAsset).then((x) {
        if (mounted) setState(() => _lesson = x);
      });
    }
  }

  void _quiz(String kind, String title, List<QuizQuestion> qs) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => QuizScreen(mode: FlashMode.bag, questions: qs, kind: 'pack-${widget.pack.id}-$kind', title: title),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = widget.pack;
    final x = _lesson;
    Widget tile(String key, IconData icon, int i, String title, String sub, List<QuizQuestion> Function() build) => Card(
      child: ListTile(
        key: ValueKey('packlearn_$key'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: IconBadge(icon, accentAt(context, i), size: 46),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        subtitle: Text(sub),
        trailing: FilledButton.tonal(onPressed: () => _quiz(key, title, build()), child: Text(l.pinQuizStart)),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.packLearnTitle(p.name))),
      body: x == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [p.color, Color.lerp(p.color, Colors.black, 0.3)!]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(l.packLearnIntro, style: t.bodyMedium?.copyWith(color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(
                        [
                          l.officePackLines(x.bags.length),
                          l.packLearnOffices(x.officeCount),
                          if (x.data.beats.isNotEmpty) l.officePackBeats(x.data.beats.length),
                          if (x.data.villages.isNotEmpty) l.officePackVillages(x.data.villageCount),
                        ].join(' · '),
                        style: t.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    key: const ValueKey('packlearn_study'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: IconBadge(Icons.menu_book_outlined, p.color, size: 46),
                    title: Text(l.packLearnStudy, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    subtitle: Text(l.packLearnStudySub),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PackStudyScreen(pack: p, lesson: x),
                      ),
                    ),
                  ),
                ),
                if (x.bags.isNotEmpty) ...[
                  tile('bag', Icons.pin_outlined, 1, l.packLearnPinBag, l.packLearnPinBagSub, x.pinToBag),
                  tile('office', Icons.markunread_mailbox_outlined, 2, l.packLearnOfficeBag, l.packLearnOfficeBagSub, x.officeToBag),
                  tile('pin', Icons.dialpad, 3, l.packLearnOfficePin, l.packLearnOfficePinSub, x.officeToPin),
                ],
                if (x.data.beats.isNotEmpty) tile('beat', Icons.route_outlined, 4, l.packLearnAreaBeat, l.packLearnAreaBeatSub, x.areaToBeat),
                if (x.data.villages.isNotEmpty)
                  tile('village', Icons.holiday_village_outlined, 5, l.packLearnVillageBo, l.packLearnVillageBoSub, x.villageToBo),
              ],
            ),
    );
  }
}

/// Every bag of the pack with its PIN and offices, searchable.
class PackStudyScreen extends StatefulWidget {
  const PackStudyScreen({super.key, required this.pack, required this.lesson});

  final OfficePack pack;
  final PackLesson lesson;

  @override
  State<PackStudyScreen> createState() => _PackStudyScreenState();
}

class _PackStudyScreenState extends State<PackStudyScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final q = _q.trim().toLowerCase();
    final bags = [
      for (final b in widget.lesson.bags)
        if (q.isEmpty || '${b.pin}'.startsWith(q) || b.code.toLowerCase().contains(q) || b.offices.any((o) => o.officeName.toLowerCase().contains(q))) b,
    ];
    String? group;
    return Scaffold(
      appBar: AppBar(title: Text(l.packLearnStudy)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              key: const ValueKey('packstudy_search'),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.pinBookSearch),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              children: [
                for (final b in bags) ...[
                  if (b.group != group) ...[
                    () {
                      group = b.group;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                        child: Text(
                          b.group,
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: widget.pack.color),
                        ),
                      );
                    }(),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: widget.pack.color, borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                  '${b.pin}',
                                  style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(b.code, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                          if (b.offices.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final o in b.offices)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(8)),
                                    child: Text(
                                      '${o.officeName} ${o.officeType}'.trim(),
                                      style: t.bodyMedium?.copyWith(color: cs.onSecondaryContainer, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
