/// PIN code quiz: one place for every office ↔ PIN practice – all TD and
/// Non-TD, Mangalore (DK) side, Udupi side, Non-TD, BOs and their SO.
library;

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/user_repo.dart';
import 'flashcards_screen.dart';
import 'learn_engine.dart';
import 'pin_book_screen.dart';
import 'quiz_screen.dart';

/// Quiz count, best and last score of one quiz kind.
class PinQuizStats {
  const PinQuizStats(this.count, this.best, this.last);

  final int count;
  final int best;
  final int last;

  static Map<String, PinQuizStats> of(List<QuizRecord> history) {
    final by = <String, List<QuizRecord>>{};
    for (final r in history) {
      (by[r.kind] ??= []).add(r);
    }
    return {
      for (final e in by.entries)
        e.key: PinQuizStats(e.value.length, e.value.map((r) => r.percent.round()).reduce((a, b) => a > b ? a : b), e.value.last.percent.round()),
    };
  }
}

class PinQuizScreen extends StatefulWidget {
  const PinQuizScreen({super.key});

  @override
  State<PinQuizScreen> createState() => _PinQuizScreenState();
}

class _PinQuizScreenState extends State<PinQuizScreen> {
  Map<String, PinQuizStats> _stats = const {};
  List<QuizRecord> _pinHistory = const [];
  int _mistakes = 0;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) _load();
  }

  Future<void> _load() async {
    _loaded = true;
    final s = context.services;
    final id = s.active?.scheme.id;
    final h = (await s.user.quizHistory(schemeId: id, limit: 2000)).where((r) => isPinQuizKind(r.kind)).toList();
    final m = await s.user.mistakes(schemeId: id, kinds: isPinQuizKind);
    if (!mounted) return;
    setState(() {
      _pinHistory = h;
      _stats = PinQuizStats.of(h);
      _mistakes = m.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasScheme = context.services.active != null;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    Future<void> open(Widget w) async {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => w));
      if (mounted) await _load();
    }

    Widget item(String key, IconData icon, Color colour, String title, String sub, LearnSection section, LearnAsk ask) {
      final c = accentFor(context, colour);
      final st = _stats[QuizScreen.kindFor(FlashMode.bag, section, ask)];
      return Card(
        key: ValueKey('pinquiz_$key'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(icon, colour),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        Text(sub, style: t.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (st == null)
                Text(l.pinQuizNotTried, key: ValueKey('pinquiz_${key}_stats'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant))
              else ...[
                Text(l.pinQuizStats(st.count, '${st.best}', '${st.last}'), key: ValueKey('pinquiz_${key}_stats'), style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: st.best / 100, minHeight: 6, borderRadius: BorderRadius.circular(3), color: c, backgroundColor: c.withValues(alpha: 0.15)),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: ValueKey('pinquiz_${key}_quiz'),
                      style: FilledButton.styleFrom(backgroundColor: c, foregroundColor: onColour(c), minimumSize: const Size(0, 46)),
                      onPressed: hasScheme ? () => open(QuizScreen(mode: FlashMode.bag, section: section, ask: ask)) : null,
                      icon: const Icon(Icons.quiz_outlined),
                      label: Text(l.pinQuizStart),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: ValueKey('pinquiz_${key}_cards'),
                      style: OutlinedButton.styleFrom(foregroundColor: c, side: BorderSide(color: c), minimumSize: const Size(0, 46)),
                      onPressed: hasScheme ? () => open(FlashcardsScreen(mode: FlashMode.bag, section: section, ask: ask)) : null,
                      icon: const Icon(Icons.style_outlined),
                      label: Text(l.pinQuizCards),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
      child: Text(text, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.pinQuiz)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (!hasScheme) WarningBanner(text: l.learnNeedsScheme),
          Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 4), child: Text(l.pinQuizIntro)),
          _ProgressSummary(history: _pinHistory, mistakes: _mistakes, onMistakes: () => open(const PinMistakesScreen())),
          Card(
            key: const ValueKey('pinquiz_book'),
            child: ListTile(
              leading: const IconBadge(Icons.auto_stories_outlined, kAccentTeal),
              title: Text(l.pinBook, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(l.pinBookSub),
              trailing: const Icon(Icons.chevron_right),
              enabled: hasScheme,
              onTap: () => open(const PinBookScreen()),
            ),
          ),
          header(l.pinQuizOfficeToPin),
          item('all', Icons.apps, kAccentIndigo, l.pinQuizAll, l.pinQuizAllSub, LearnSection.all, LearnAsk.pin),
          item('dk', Icons.location_city, kPostRed, l.pinQuizDk, l.pinQuizDkSub, LearnSection.mangaloreTd, LearnAsk.pin),
          item('udupi', Icons.waves, kAccentTeal, l.pinQuizUdupi, l.pinQuizUdupiSub, LearnSection.udupiTd, LearnAsk.pin),
          item('nontd', Icons.public, kAccentAmber, l.pinQuizNonTd, l.pinQuizNonTdSub, LearnSection.nonTd, LearnAsk.pin),
          header(l.pinQuizPinToOffice),
          item('office_all', Icons.apps, kAccentIndigo, l.pinQuizAll, l.pinQuizOfficeAllSub, LearnSection.all, LearnAsk.office),
          item('office_dk', Icons.location_city, kPostRed, l.pinQuizDk, l.pinQuizOfficeSideSub, LearnSection.mangaloreTd, LearnAsk.office),
          item('office_udupi', Icons.waves, kAccentTeal, l.pinQuizUdupi, l.pinQuizOfficeSideSub, LearnSection.udupiTd, LearnAsk.office),
          item('office_nontd', Icons.public, kAccentAmber, l.pinQuizNonTd, l.pinQuizOfficeNonTdSub, LearnSection.nonTd, LearnAsk.office),
          header(l.pinQuizBos),
          item('bo_pin', Icons.home_work_outlined, kPostGreen, l.pinQuizBoPin, l.pinQuizBoPinSub, LearnSection.bo, LearnAsk.pin),
          item('bo_so', Icons.account_tree_outlined, kAccentPurple, l.pinQuizBoSo, l.pinQuizBoSoSub, LearnSection.bo, LearnAsk.parent),
        ],
      ),
    );
  }
}

/// Quizzes taken, average score and mistakes to fix (PIN quizzes only).
class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({required this.history, required this.mistakes, required this.onMistakes});

  final List<QuizRecord> history;
  final int mistakes;
  final VoidCallback onMistakes;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final avg = history.isEmpty ? 0 : (history.map((r) => r.percent).reduce((a, b) => a + b) / history.length).round();
    final recent = history.length <= 5 ? history : history.sublist(history.length - 5);
    final recentAvg = recent.isEmpty ? 0 : (recent.map((r) => r.percent).reduce((a, b) => a + b) / recent.length).round();
    Widget stat(String value, String label, Color colour) => Expanded(
      child: Column(
        children: [
          Text(value, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: accentFor(context, colour))),
          Text(label, style: t.labelSmall, textAlign: TextAlign.center),
        ],
      ),
    );
    return Card(
      key: const ValueKey('pinquiz_progress'),
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.pinQuizProgress, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: cs.onPrimaryContainer)),
            const SizedBox(height: 8),
            Row(
              children: [
                stat('${history.length}', l.pinQuizTaken, kAccentIndigo),
                stat('$avg%', l.pinQuizAverage, kPostGreen),
                stat('$recentAvg%', l.pinQuizRecent, kSkyDeep),
                stat('$mistakes', l.pinQuizMistakes, kPostRed),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('pinquiz_mistakes'),
              onPressed: onMistakes,
              icon: const Icon(Icons.error_outline),
              label: Text(l.myMistakes),
            ),
          ],
        ),
      ),
    );
  }
}

/// Office ↔ PIN questions answered wrongly: the right answer, the wrong
/// choice and how often; practise them until they are right.
class PinMistakesScreen extends StatefulWidget {
  const PinMistakesScreen({super.key});

  @override
  State<PinMistakesScreen> createState() => _PinMistakesScreenState();
}

class _PinMistakesScreenState extends State<PinMistakesScreen> {
  List<Mistake>? _list;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_list == null) _load();
  }

  Future<void> _load() async {
    final s = context.services;
    final m = await s.user.mistakes(schemeId: s.active?.scheme.id, kinds: isPinQuizKind);
    if (mounted) setState(() => _list = m);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final list = _list;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final qs = list == null ? const <QuizQuestion>[] : mistakeQuiz([for (final m in list) (kind: m.kind, question: m.question, correct: m.correct, chosen: m.chosen)]);
    return Scaffold(
      appBar: AppBar(title: Text(l.myMistakes)),
      floatingActionButton: qs.isEmpty
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('mistakes_practise'),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(mode: FlashMode.bag, questions: qs)));
                if (mounted) await _load();
              },
              icon: const Icon(Icons.replay),
              label: Text(l.practiseMistakes),
            ),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
          ? EmptyState(icon: Icons.emoji_events_outlined, text: l.noPinMistakes)
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(l.mistakesIntro, style: t.bodySmall)),
                for (final m in list)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.errorContainer,
                        foregroundColor: cs.onErrorContainer,
                        child: Text('${m.wrong}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                      title: Text('${m.question}  →  ${m.correct}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        [if (m.chosen != null && m.chosen!.isNotEmpty) l.youChose(m.chosen!), l.wrongTimes(m.wrong)].join(' · '),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
