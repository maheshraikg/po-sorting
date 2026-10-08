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

class LineStudyScreen extends StatefulWidget {
  const LineStudyScreen({super.key, required this.bag});

  final Bag bag;

  @override
  State<LineStudyScreen> createState() => _LineStudyScreenState();
}

class _LineStudyScreenState extends State<LineStudyScreen> {
  /// Branch office names per PIN of this line.
  Map<int, List<String>> _bos = const {};
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadBos();
    }
  }

  Future<void> _loadBos() async {
    final s = context.services;
    final scheme = s.active;
    if (scheme == null) return;
    final offices = await LearnEngine.loadBranchOffices(s.directory, scheme);
    final out = <int, List<String>>{};
    for (final o in offices) {
      if (o.officeType == 'BO') (out[o.pincode] ??= []).add(o.officeName);
    }
    if (mounted) setState(() => _bos = out);
  }

  @override
  Widget build(BuildContext context) {
    final bag = widget.bag;
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
                subtitle: s.pin == null || _bos[s.pin] == null ? null : Text(l.boList(_bos[s.pin]!.join(', ')), style: t.bodySmall),
                trailing: s.pin == null || s.office == '${s.pin}' ? null : Text('${s.pin}', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
            ),
        ],
      ),
    );
  }
}
