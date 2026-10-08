/// Learn line by line: pick a TD line, study its offices in order, then
/// practise it.
library;

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/scheme.dart';
import 'learn_engine.dart';
import 'quiz_screen.dart';

class LinePickerScreen extends StatelessWidget {
  const LinePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = context.services.active;
    final engine = scheme == null ? null : LearnEngine(scheme);
    final lines = engine?.studyLines() ?? const <Bag>[];
    return Scaffold(
      appBar: AppBar(title: Text(l.learnByLine)),
      body: lines.isEmpty
          ? EmptyState(icon: Icons.format_list_numbered, text: l.noCards)
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final b in lines)
                  Card(
                    child: ListTile(
                      key: ValueKey('study_${b.code}'),
                      leading: CircleAvatar(backgroundColor: parseColour(b.colour) ?? Theme.of(context).colorScheme.primary, radius: 8),
                      title: Text(b.code, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(l.lineOfficesN(engine!.lineStops(b.code).length)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LineStudyScreen(bag: b))),
                    ),
                  ),
              ],
            ),
    );
  }
}

class LineStudyScreen extends StatelessWidget {
  const LineStudyScreen({super.key, required this.bag});

  final Bag bag;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = context.services.active;
    final stops = scheme == null ? const <LineStop>[] : LearnEngine(scheme).lineStops(bag.code);
    final colour = parseColour(bag.colour) ?? Theme.of(context).colorScheme.primary;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(bag.code)),
      floatingActionButton: stops.length < 2
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('practise_line'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(mode: FlashMode.bag, lineCode: bag.code))),
              icon: const Icon(Icons.play_arrow),
              label: Text(l.practiseLine),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(l.studyLineHint, style: t.bodyMedium)),
          for (final s in stops)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colour,
                  foregroundColor: onColour(colour),
                  child: Text(s.position.isEmpty ? '•' : s.position, style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                title: Text(s.office, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: s.pin == null || s.office == '${s.pin}' ? null : Text('${s.pin}', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
            ),
        ],
      ),
    );
  }
}
