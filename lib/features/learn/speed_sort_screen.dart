/// Speed sort: 60 seconds to sort as many articles as possible. Answers in a
/// row build a combo (×2 from 3 in a row … ×5); a wrong bag costs 3 seconds.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/feedback.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'learn_engine.dart';
import 'learn_screen.dart' show learnSectionLabel;
import 'progress.dart';

const _gameMs = 60000;
const _penaltyMs = 3000;
const _tickMs = 100;

class SpeedSortScreen extends StatefulWidget {
  const SpeedSortScreen({super.key, this.section = LearnSection.all, this.random});

  final LearnSection section;
  final Random? random;

  @override
  State<SpeedSortScreen> createState() => _SpeedSortScreenState();
}

class _SpeedSortScreenState extends State<SpeedSortScreen> {
  late final Random _rnd = widget.random ?? Random();
  List<LearnCard>? _deck;
  int _next = 0;
  LearnCard? _card;
  List<String> _options = const [];
  String? _chosen;
  bool _playing = false, _done = false, _newRecord = false;
  int _leftMs = _gameMs, _score = 0, _combo = 0, _bestCombo = 0, _correct = 0, _wrong = 0;
  Timer? _timer;

  String get _bestKey => widget.section.name;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_deck == null) _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final s = context.services;
    final scheme = s.active;
    if (scheme == null) {
      setState(() => _deck = []);
      return;
    }
    final regions = await s.pinRegions();
    final cards = LearnEngine(scheme, directoryPins: regions.keys, regions: regions, random: _rnd).cards(FlashMode.bag, section: widget.section);
    if (mounted) setState(() => _deck = cards);
  }

  void _start() {
    _deck!.shuffle(_rnd);
    setState(() {
      _playing = true;
      _done = false;
      _newRecord = false;
      _next = 0;
      _leftMs = _gameMs;
      _score = _combo = _bestCombo = _correct = _wrong = 0;
    });
    _deal();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) {
      if (!mounted) return;
      setState(() => _leftMs -= _tickMs);
      if (_leftMs <= 0) _finish();
    });
  }

  void _deal() {
    final deck = _deck!;
    if (_next >= deck.length) {
      deck.shuffle(_rnd);
      _next = 0;
    }
    final c = deck[_next++];
    final answers = {for (final o in deck) if (o.asksOffice == c.asksOffice) o.answer}..remove(c.answer);
    final others = answers.toList()..shuffle(_rnd);
    setState(() {
      _card = c;
      _chosen = null;
      _options = [c.answer, ...others.take(3)]..shuffle(_rnd);
    });
  }

  Future<void> _choose(String o) async {
    if (_chosen != null || !_playing) return;
    final c = _card!;
    final right = o == c.answer;
    final settings = context.settings;
    setState(() {
      _chosen = o;
      if (right) {
        _score += speedPoints(_combo);
        _combo++;
        _bestCombo = max(_bestCombo, _combo);
        _correct++;
      } else {
        _combo = 0;
        _wrong++;
        _leftMs -= _penaltyMs;
      }
    });
    if (right) {
      AppFeedback.success(settings);
    } else {
      AppFeedback.warning(settings);
      final s = context.services;
      await s.user.addMistake(s.active?.scheme.id, 'speed-${widget.section.name}', c.prompt, c.isPin ? c.prefix : null, c.answer, o);
    }
    await Future<void>.delayed(Duration(milliseconds: right ? 180 : 700));
    if (!mounted || !_playing) return;
    if (_leftMs <= 0) {
      _finish();
    } else {
      _deal();
    }
  }

  void _finish() {
    if (!_playing) return;
    _timer?.cancel();
    final settings = context.settings;
    final best = settings.speedBest(_bestKey);
    _newRecord = _score > best;
    if (_newRecord) settings.setSpeedBest(_bestKey, _score);
    settings.addLearnXp(_score ~/ 5);
    setState(() {
      _playing = false;
      _done = true;
      _leftMs = max(0, _leftMs);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final title = widget.section == LearnSection.all ? l.speedSort : '${l.speedSort} · ${learnSectionLabel(l, widget.section)}';
    final deck = _deck;
    if (deck == null) return Scaffold(appBar: AppBar(title: Text(title)), body: const Center(child: CircularProgressIndicator()));
    if (deck.length < 2) return Scaffold(appBar: AppBar(title: Text(title)), body: EmptyState(icon: Icons.bolt, text: l.noCards));
    final best = context.settings.speedBest(_bestKey);
    if (!_playing) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_done ? (_newRecord ? Icons.emoji_events : Icons.flag) : Icons.bolt, size: 88, color: _newRecord ? Colors.amber.shade700 : Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                if (_done) ...[
                  Text(l.timeUp, style: t.headlineSmall),
                  if (_newRecord) Text(l.newRecord, style: t.titleLarge?.copyWith(color: Colors.amber.shade800, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('$_score', key: const ValueKey('speed_final'), style: t.displayLarge?.copyWith(fontWeight: FontWeight.w900)),
                  Text(l.speedSummary(_correct, _wrong, _bestCombo), textAlign: TextAlign.center, style: t.titleMedium),
                  const SizedBox(height: 4),
                  Text(l.xpGained(_score ~/ 5), style: t.titleMedium?.copyWith(color: okColor(context), fontWeight: FontWeight.w800)),
                ] else ...[
                  Text(l.speedSort, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(l.speedRules, textAlign: TextAlign.center, style: t.bodyLarge),
                ],
                const SizedBox(height: 12),
                Text(l.bestScoreN(max(best, _score)), style: t.titleMedium),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const ValueKey('speed_start'),
                  style: FilledButton.styleFrom(minimumSize: const Size(220, 56)),
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(_done ? l.again : l.start, style: const TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final c = _card!;
    final secs = (max(0, _leftMs) / 1000).ceil();
    final mult = comboMultiplier(_combo);
    final question = c.asksOffice ? l.qWhichOfficePin : c.isPin ? l.qWhichBagPin : l.qWhichBagPlace;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.timer, color: secs <= 10 ? Theme.of(context).colorScheme.error : null),
                const SizedBox(width: 4),
                Text('${secs}s', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: secs <= 10 ? Theme.of(context).colorScheme.error : null)),
                const Spacer(),
                if (mult > 1)
                  AnimatedScale(
                    scale: 1.1,
                    duration: const Duration(milliseconds: 150),
                    child: Chip(
                      key: const ValueKey('speed_combo'),
                      avatar: const Icon(Icons.local_fire_department, color: Colors.deepOrange),
                      label: Text(l.comboX(mult), style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                const SizedBox(width: 8),
                Text('$_score', key: const ValueKey('speed_score'), style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: (max(0, _leftMs) / _gameMs).clamp(0, 1).toDouble(), minHeight: 8, borderRadius: BorderRadius.circular(4)),
            const Spacer(),
            Text(c.category == null ? question : '$question · ${categoryLabel(l, c.category!)}', style: t.titleMedium, textAlign: TextAlign.center),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: FittedBox(
                key: ValueKey('${c.key}$_next'),
                child: Text(c.prompt, style: t.displayMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: c.isPin ? 4 : 0)),
              ),
            ),
            const Spacer(),
            for (var i = 0; i < _options.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: FilledButton.tonal(
                  key: ValueKey('speed_opt_$i'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    backgroundColor: _chosen == null
                        ? null
                        : _options[i] == c.answer
                        ? okColor(context).withValues(alpha: 0.45)
                        : _options[i] == _chosen
                        ? Theme.of(context).colorScheme.errorContainer
                        : null,
                  ),
                  onPressed: () => _choose(_options[i]),
                  child: Text(_options[i], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
