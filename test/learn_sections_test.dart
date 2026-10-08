import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/core/constants.dart';
import 'package:sorting_sahayak/data/import/scheme_io.dart';
import 'package:sorting_sahayak/data/scheme_repo.dart';
import 'package:sorting_sahayak/features/learn/learn_engine.dart';
import 'package:sorting_sahayak/features/learn/learn_screen.dart';

import 'helpers/app_harness.dart';
import 'helpers/fixture.dart';

void main() {
  late LearnEngine engine;
  setUp(() async {
    final repo = SchemeRepo(await memoryUserDb());
    await installDefaultScheme(repo, (p) async => File(p).readAsBytesSync());
    final dir = await fixtureRepo();
    final regions = await dir.pinRegions();
    engine = LearnEngine((await repo.loadActive())!, directoryPins: regions.keys, regions: regions, random: Random(3));
  });

  test('the default scheme has Mangalore TD, Udupi TD and Non-TD sections', () {
    expect(engine.sections(), [LearnSection.all, LearnSection.mangaloreTd, LearnSection.udupiTd, LearnSection.nonTd]);
  });

  test('Mangalore side: TD lines only, never the Udupi line', () {
    final cards = engine.cards(FlashMode.bag, section: LearnSection.mangaloreTd);
    expect(cards, isNotEmpty);
    expect(cards.every((c) => c.category == kCatTD), isTrue);
    expect(cards.any((c) => c.answer.toLowerCase().contains('udupi')), isFalse);
    expect(cards.any((c) => c.answer == 'Puttur Line'), isTrue);
  });

  test('Udupi side: PIN → post office', () {
    final cards = engine.cards(FlashMode.bag, section: LearnSection.udupiTd);
    expect(cards.length, greaterThan(40));
    final c = cards.firstWhere((c) => c.prompt == '574103');
    expect(c.answer, 'Hejamadi');
    expect(c.asksOffice, isTrue);
    expect(cards.firstWhere((c) => c.prompt == '576101').answer, 'Udupi HO');
    final quiz = engine.quiz(FlashMode.bag, section: LearnSection.udupiTd);
    expect(quiz, hasLength(20));
    expect(quiz.every((q) => q.options.length == 4 && q.options.contains(q.card.answer)), isTrue);
  });

  test('Non-TD: state bags only', () {
    final cards = engine.cards(FlashMode.bag, section: LearnSection.nonTd);
    expect(cards, isNotEmpty);
    expect(cards.every((c) => c.category == kCatNonTD), isTrue);
    expect(engine.quiz(FlashMode.bag, section: LearnSection.nonTd).every((q) => q.card.category == kCatNonTD), isTrue);
  });

  testWidgets('Learn screen shows the section chips', (tester) async {
    final h = await Harness.create(tester, sample: false);
    await tester.runAsync(() async {
      await installDefaultScheme(h.services.schemes, (p) async => File(p).readAsBytesSync());
      await h.services.reloadActive();
    });
    await tester.pumpWidget(h.wrap(const LearnScreen()));
    await settle(tester);
    expect(find.byKey(const ValueKey('learn_section_udupiTd')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('learn_section_udupiTd')));
    await tester.pump();
    expect(find.text('Udupi side TD: PIN → which post office.'), findsOneWidget);
  });
}
