/// PIN code quiz: one place for every office ↔ PIN practice – all TD and
/// Non-TD, Mangalore (DK) side, Udupi side, Non-TD, BOs and their SO.
library;

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'flashcards_screen.dart';
import 'pin_book_screen.dart';
import 'quiz_screen.dart';

class PinQuizScreen extends StatelessWidget {
  const PinQuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasScheme = context.services.active != null;
    final t = Theme.of(context).textTheme;
    void open(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    Widget item(String key, IconData icon, Color colour, String title, String sub, LearnSection section, LearnAsk ask) {
      final c = accentFor(context, colour);
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: ValueKey('pinquiz_${key}_quiz'),
                      style: FilledButton.styleFrom(backgroundColor: c, foregroundColor: onColour(c), minimumSize: const Size(0, 46)),
                      onPressed: hasScheme ? () => open(QuizScreen(mode: FlashMode.bag, section: section, ask: ask)) : null,
                      icon: const Icon(Icons.quiz_outlined),
                      label: Text(l.timedQuiz),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: ValueKey('pinquiz_${key}_cards'),
                      style: OutlinedButton.styleFrom(foregroundColor: c, side: BorderSide(color: c), minimumSize: const Size(0, 46)),
                      onPressed: hasScheme ? () => open(FlashcardsScreen(mode: FlashMode.bag, section: section, ask: ask)) : null,
                      icon: const Icon(Icons.style_outlined),
                      label: Text(l.flashcards),
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
