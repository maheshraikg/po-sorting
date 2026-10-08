/// PIN book: every TD PIN with its head office and branch offices, to read
/// before the office quizzes.
library;

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme.dart';
import 'learn_engine.dart';
import 'learn_screen.dart';
import 'quiz_screen.dart';

class PinBookScreen extends StatefulWidget {
  const PinBookScreen({super.key, this.section = LearnSection.all});

  final LearnSection section;

  @override
  State<PinBookScreen> createState() => _PinBookScreenState();
}

class _PinBookScreenState extends State<PinBookScreen> {
  List<PinBookEntry>? _entries;
  String _q = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entries == null) _load();
  }

  Future<void> _load() async {
    final s = context.services;
    final scheme = s.active;
    if (scheme == null) {
      setState(() => _entries = const []);
      return;
    }
    final offices = await LearnEngine.loadBranchOffices(s.directory, scheme);
    if (!mounted) return;
    setState(() => _entries = LearnEngine(scheme, branchOffices: offices).pinBook(widget.section));
  }

  bool _matches(PinBookEntry e) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '${e.pin}'.startsWith(q) ||
        (e.head ?? '').toLowerCase().contains(q) ||
        e.line.toLowerCase().contains(q) ||
        e.bos.any((b) => b.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final entries = _entries;
    final scheme = context.services.active;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final shown = entries?.where(_matches).toList();
    final bos = entries?.fold<int>(0, (n, e) => n + e.bos.length) ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text('${l.pinBook} · ${learnSectionLabel(l, widget.section)}')),
      floatingActionButton: entries == null || entries.isEmpty
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('pin_book_quiz'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => QuizScreen(mode: FlashMode.bag, section: widget.section, ask: LearnAsk.office)),
              ),
              icon: const Icon(Icons.quiz_outlined),
              label: Text(l.pinBookQuiz),
            ),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.pinBookEmpty, textAlign: TextAlign.center)))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: TextField(
                    key: const ValueKey('pin_book_search'),
                    decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.pinBookSearch),
                    onChanged: (v) => setState(() => _q = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(l.pinBookCount(entries.length, bos), style: t.bodySmall),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                    itemCount: shown!.length,
                    itemBuilder: (_, i) {
                      final e = shown[i];
                      final colour = parseColour(scheme?.bags[e.line]?.colour) ?? kAccentCycle[e.line.hashCode.abs() % kAccentCycle.length];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(10)),
                                    child: Text('${e.pin}',
                                        style: t.titleLarge?.copyWith(color: onColour(colour), fontWeight: FontWeight.w900, letterSpacing: 2)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(e.head ?? l.pinBookNoHead, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                  ),
                                  Chip(
                                    label: Text(e.line),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: colour.withValues(alpha: 0.15),
                                    side: BorderSide(color: colour.withValues(alpha: 0.5)),
                                  ),
                                ],
                              ),
                              if (e.bos.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(l.pinBookBos(e.bos.length), style: t.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final b in e.bos)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: cs.secondaryContainer,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(b, style: t.bodyMedium?.copyWith(color: cs.onSecondaryContainer, fontWeight: FontWeight.w600)),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
