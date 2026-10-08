import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sorting_sahayak/core/settings.dart';
import 'package:sorting_sahayak/data/import/scheme_io.dart';
import 'package:sorting_sahayak/data/scheme_repo.dart';
import 'package:sorting_sahayak/features/learn/learn_engine.dart';
import 'package:sorting_sahayak/features/learn/learn_screen.dart';
import 'package:sorting_sahayak/features/learn/progress.dart';
import 'package:sorting_sahayak/features/learn/speed_sort_screen.dart';

import 'helpers/app_harness.dart';
import 'helpers/fixture.dart';

void main() {
  test('levels and combo points', () {
    expect(levelFor(0).level, 1);
    expect(levelFor(99).level, 1);
    expect(levelFor(100).level, 2);
    expect(levelFor(120).progress(120), closeTo(20 / 150, 1e-9));
    expect(levelFor(99999).next, isNull);
    expect([for (final c in [0, 2, 3, 5, 6, 12, 30]) comboMultiplier(c)], [1, 1, 2, 2, 3, 5, 5]);
    expect(speedPoints(3), 20);
  });

  test('XP builds a daily streak; a missed day resets it', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Settings.load();
    final d1 = DateTime(2026, 10, 1, 9);
    s.addLearnXp(30, now: d1);
    s.addLearnXp(30, now: d1.add(const Duration(hours: 2)));
    expect(s.learnTodayXp(d1), 60);
    expect(s.learnStreak(d1), 1);
    final d2 = DateTime(2026, 10, 2, 8);
    expect(s.learnTodayXp(d2), 0);
    s.addLearnXp(10, now: d2);
    expect(s.learnStreak(d2), 2);
    expect(s.learnStreak(DateTime(2026, 10, 3)), 2);
    expect(s.learnStreak(DateTime(2026, 10, 4)), 0);
    s.addLearnXp(10, now: DateTime(2026, 10, 4));
    expect(s.learnStreak(DateTime(2026, 10, 4)), 1);
    expect(s.learnXp, 80);
  });

  group('line study', () {
    late LearnEngine engine;
    setUp(() async {
      final repo = SchemeRepo(await memoryUserDb());
      await installDefaultScheme(repo, (p) async => File(p).readAsBytesSync());
      engine = LearnEngine((await repo.loadActive())!, random: Random(1));
    });

    test('lists TD lines with their offices in position order', () {
      final lines = engine.studyLines().map((b) => b.code).toList();
      expect(lines, containsAll(['Puttur Line', 'Udupi Line']));
      expect(lines.any((c) => c.contains('BANGALORE')), isFalse);
      final stops = engine.lineStops('Puttur Line');
      expect(stops.first.office, 'Sampaje');
      expect(stops.first.position, '1');
      final positions = [for (final s in stops) int.tryParse(s.position)].whereType<int>().toList();
      expect(positions, orderedEquals([...positions]..sort()));
    });

    test('line quiz asks positions, Udupi line asks offices', () {
      final q = engine.lineQuiz('Puttur Line');
      expect(q, isNotEmpty);
      expect(q.every((x) => x.card.asksPosition && x.options.contains(x.card.answer) && x.options.toSet().length == x.options.length), isTrue);
      final u = engine.lineQuiz('Udupi Line');
      expect(u, hasLength(15));
      expect(u.every((x) => x.card.asksOffice && x.options.length == 4), isTrue);
    });
  });

  testWidgets('speed sort: right answers score and build a combo, game ends at 60 s', (tester) async {
    final h = await Harness.create(tester, sample: false);
    await tester.runAsync(() async {
      await installDefaultScheme(h.services.schemes, (p) async => File(p).readAsBytesSync());
      await h.services.reloadActive();
    });
    await tester.pumpWidget(h.wrap(SpeedSortScreen(section: LearnSection.udupiTd, random: Random(2))));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('speed_start')));
    await tester.pump();
    final answers = {for (final c in LearnEngine(h.services.active!).cards(FlashMode.bag, section: LearnSection.udupiTd)) c.prompt: c.answer};
    for (var i = 0; i < 4; i++) {
      final prompt = answers.keys.firstWhere((p) => find.text(p).evaluate().isNotEmpty);
      await tester.tap(find.widgetWithText(FilledButton, answers[prompt]!));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }
    // 10 + 10 + 10 + 20 (×2 from the 4th in a row).
    expect((tester.widget(find.byKey(const ValueKey('speed_score'))) as Text).data, '50');
    expect(find.byKey(const ValueKey('speed_combo')), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
    await tester.pump();
    expect(find.byKey(const ValueKey('speed_final')), findsOneWidget);
    expect(h.settings.speedBest('udupiTd'), 50);
    expect(h.settings.learnXp, 10);
  });

  testWidgets('Learn screen shows level, streak and the new games', (tester) async {
    final h = await Harness.create(tester, sample: false);
    await tester.runAsync(() async {
      await installDefaultScheme(h.services.schemes, (p) async => File(p).readAsBytesSync());
      await h.services.reloadActive();
    });
    h.settings.addLearnXp(120);
    await tester.pumpWidget(h.wrap(const LearnScreen()));
    await settle(tester);
    expect(find.textContaining('Level 2'), findsOneWidget);
    expect(find.text('130 XP to the next level'), findsOneWidget);
    expect(find.text('1 days'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Learn line by line'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Speed sort game'), findsOneWidget);
  });
}
