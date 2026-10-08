/// Learn / practice hub: flashcards, timed quiz, weak areas, PIN basics.
library;

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/import/scheme_io.dart';
import '../../core/files.dart';
import 'flashcards_screen.dart';
import 'learn_engine.dart';
import 'line_study_screen.dart';
import 'progress.dart';
import 'speed_sort_screen.dart';
import 'pin_basics_screen.dart';
import 'quiz_screen.dart';
import 'weak_areas_screen.dart';

String learnSectionLabel(AppLocalizations l, LearnSection s) => switch (s) {
  LearnSection.all => l.learnSectionAll,
  LearnSection.mangaloreTd => l.learnSectionMangaloreTd,
  LearnSection.udupiTd => l.learnSectionUdupiTd,
  LearnSection.nonTd => l.learnSectionNonTd,
};

String _sectionHint(AppLocalizations l, LearnSection s) => switch (s) {
  LearnSection.all => l.learnSectionAllHint,
  LearnSection.mangaloreTd => l.learnSectionMangaloreTdHint,
  LearnSection.udupiTd => l.learnSectionUdupiTdHint,
  LearnSection.nonTd => l.learnSectionNonTdHint,
};

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  LearnSection _section = LearnSection.all;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = context.services;
    final scheme = services.active;
    final sections = scheme == null ? const <LearnSection>[] : LearnEngine(scheme).sections();
    final section = sections.contains(_section) ? _section : LearnSection.all;
    void open(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    Widget tile(IconData icon, String title, String sub, VoidCallback? onTap) => Card(
      child: ListTile(
        leading: Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        enabled: onTap != null,
      ),
    );
    final hasAir = scheme != null && !scheme.airResolver.isEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(l.navLearn)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (scheme == null)
            WarningBanner(
              text: l.learnNeedsScheme,
              icon: Icons.school_outlined,
              action: TextButton(
                onPressed: () async {
                  await installSampleScheme(services.schemes, loadAssetBytes);
                  await services.reloadActive();
                },
                child: Text(l.useSample),
              ),
            )
          else
            ListTile(
              title: Text(scheme.scheme.name),
              subtitle: Text(l.learnFromScheme),
              trailing: scheme.scheme.isSample ? const SampleChip() : null,
            ),
          const _ProgressCard(),
          if (sections.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(l.learnSection, style: Theme.of(context).textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final s in sections)
                    ChoiceChip(
                      key: ValueKey('learn_section_${s.name}'),
                      label: Text(learnSectionLabel(l, s)),
                      selected: s == section,
                      onSelected: (_) => setState(() => _section = s),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(_sectionHint(l, section), style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
          tile(Icons.style_outlined, l.flashcards, l.flashcardsSub, scheme == null ? null : () => open(FlashcardsScreen(mode: FlashMode.bag, section: section))),
          tile(Icons.timer_outlined, l.timedQuiz, l.timedQuizSub, scheme == null ? null : () => open(QuizScreen(mode: FlashMode.bag, section: section))),
          tile(Icons.bolt, l.speedSort, l.speedSortSub, scheme == null ? null : () => open(SpeedSortScreen(section: section))),
          tile(Icons.format_list_numbered, l.learnByLine, l.learnByLineSub, scheme == null ? null : () => open(const LinePickerScreen())),
          tile(Icons.flight_takeoff, l.airFlashcards, l.airFlashcardsSub, hasAir ? () => open(const FlashcardsScreen(mode: FlashMode.air)) : null),
          tile(Icons.quiz_outlined, l.airQuiz, l.airQuizSub, hasAir ? () => open(const QuizScreen(mode: FlashMode.air)) : null),
          tile(Icons.hub_outlined, l.hubFlashcards, l.hubFlashcardsSub, scheme != null && !scheme.hubResolver.isEmpty ? () => open(const FlashcardsScreen(mode: FlashMode.hub)) : null),
          tile(Icons.trending_down, l.weakAreas, l.weakAreasSub, () => open(const WeakAreasScreen())),
          tile(Icons.menu_book_outlined, l.pinBasics, l.pinBasicsSub, () => open(const PinBasicsScreen())),
        ],
      ),
    );
  }
}

String levelTitle(AppLocalizations l, int rank) => switch (rank) {
  0 => l.levelBeginner,
  1 => l.levelLearner,
  2 => l.levelSorter,
  3 => l.levelSkilled,
  4 => l.levelExpert,
  _ => l.levelMaster,
};

/// Level, XP to the next level, daily goal and streak.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final st = context.settings;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final xp = st.learnXp;
    final lv = levelFor(xp);
    final today = st.learnTodayXp();
    final streak = st.learnStreak();
    final goalDone = today >= kDailyGoalXp;
    return Card(
      key: const ValueKey('learn_progress'),
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  child: Text('${lv.level}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${l.levelN(lv.level)} · ${levelTitle(l, lv.rank)}', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: cs.onPrimaryContainer)),
                      Text(lv.next == null ? l.xpTotal(xp) : l.xpToNext(lv.next! - xp), style: t.bodySmall?.copyWith(color: cs.onPrimaryContainer)),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Icon(Icons.local_fire_department, color: streak > 0 ? Colors.deepOrange : cs.outline, size: 30),
                    Text(l.streakDays(streak), style: t.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: cs.onPrimaryContainer)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: lv.progress(xp), minHeight: 8, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(goalDone ? Icons.check_circle : Icons.flag_outlined, size: 18, color: goalDone ? okColor(context) : cs.onPrimaryContainer),
                const SizedBox(width: 6),
                Expanded(child: Text(goalDone ? l.dailyGoalDone : l.dailyGoal(today, kDailyGoalXp), style: t.bodyMedium?.copyWith(color: cs.onPrimaryContainer))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
