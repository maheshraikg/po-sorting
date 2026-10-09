import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/core/constants.dart';
import 'package:sorting_sahayak/data/import/scheme_io.dart';
import 'package:sorting_sahayak/data/models/office.dart';
import 'package:sorting_sahayak/data/scheme_repo.dart';
import 'package:sorting_sahayak/features/learn/learn_engine.dart';
import 'package:sorting_sahayak/features/learn/learn_screen.dart';
import 'package:sorting_sahayak/features/learn/pin_book_screen.dart';
import 'package:sorting_sahayak/features/learn/pin_quiz_screen.dart';
import 'package:sorting_sahayak/features/learn/quiz_screen.dart';

import 'helpers/app_harness.dart';
import 'helpers/fixture.dart';

void main() {
  late LearnEngine engine;
  setUp(() async {
    final repo = SchemeRepo(await memoryUserDb());
    await installDefaultScheme(repo, (p) async => File(p).readAsBytesSync());
    final dir = await fixtureRepo();
    final scheme = (await repo.loadActive())!;
    engine = await LearnEngine.load(dir, scheme, regions: await dir.pinRegions(), ask: LearnAsk.pin, random: Random(5));
  });

  List<String> prompts(LearnSection s) => engine.cards(FlashMode.bag, section: s, ask: LearnAsk.pin).map((c) => '${c.prompt}=${c.answer}').toList();

  test('office → PIN: Mangalore side, Udupi side, BOs and Non-TD', () {
    final mlr = prompts(LearnSection.mangaloreTd);
    expect(mlr, contains('Puttur SO=574201'));
    expect(mlr, contains('Mangalore HO=575001'));
    expect(mlr.any((p) => p.contains(' BO=')), isFalse);
    expect(mlr.any((p) => p.endsWith('=576105')), isFalse);
    final bo = prompts(LearnSection.bo);
    expect(bo, contains('Darbe BO=574202'));
    final nonTd = prompts(LearnSection.nonTd);
    expect(nonTd, contains('Puttur SO=517583')); // Andhra Pradesh
    expect(nonTd.any((p) => p.endsWith('=574201')), isFalse);
    final all = engine.cards(FlashMode.bag, ask: LearnAsk.pin);
    expect(all.every((c) => c.asksPin), isTrue);
    expect(all.where((c) => c.category == kCatNonTD), isNotEmpty);
  });

  test('PIN quiz: 4 choices, the right PIN among them', () {
    final q = engine.quiz(FlashMode.bag, section: LearnSection.mangaloreTd, ask: LearnAsk.pin);
    expect(q, isNotEmpty);
    expect(q.every((x) => x.options.contains(x.card.answer) && x.options.every((o) => RegExp(r'^\d{6}$').hasMatch(o))), isTrue);
  });

  test('PIN book: PIN with its office and BOs', () {
    final book = engine.pinBook(LearnSection.all);
    final puttur = book.firstWhere((e) => e.pin == 574201);
    expect(puttur.head, 'Puttur SO');
    final darbe = book.firstWhere((e) => e.bos.contains('Darbe'));
    expect(darbe.pin, 574202);
    expect(book.map((e) => e.pin).toList(), [...book.map((e) => e.pin)]..sort());
  });

  test('PIN → office and BO → its SO quizzes', () {
    final office = engine.cards(FlashMode.bag, section: LearnSection.mangaloreTd, ask: LearnAsk.office);
    expect(office.map((c) => '${c.prompt}=${c.answer}'), contains('574201=Puttur SO'));
    expect(office.every((c) => c.asksOffice && c.near != null), isTrue);
    // BOs carry the PIN of the office they come under.
    final withBos = LearnEngine(engine.scheme, random: Random(1), branchOffices: [
      ...engine.branchOffices,
      const Office(pincode: 574201, officeName: 'Kemminje', officeType: 'BO'),
      const Office(pincode: 574211, officeName: 'Panemangalore', officeType: 'BO'),
    ]);
    expect(withBos.pinBook(LearnSection.all).firstWhere((e) => e.pin == 574201).bos, ['Kemminje']);
    final parent = withBos.cards(FlashMode.bag, section: LearnSection.bo, ask: LearnAsk.parent);
    expect(parent.map((c) => '${c.prompt}=${c.answer}'), containsAll(['Kemminje BO=Puttur SO – 574201', 'Panemangalore BO=Bantwal SO – 574211']));
    expect(parent.every((c) => c.asksParent), isTrue);
    final q = withBos.quiz(FlashMode.bag, section: LearnSection.bo, ask: LearnAsk.parent);
    expect(q, hasLength(2));
    expect(q.every((x) => x.options.length == 2 && x.options.contains(x.card.answer)), isTrue);
    final oc = withBos.cards(FlashMode.bag, section: LearnSection.mangaloreTd, ask: LearnAsk.office).firstWhere((c) => c.prompt == '574201');
    expect(oc.answerDetail, contains('Kemminje'));
  });

  testWidgets('PIN book lists each PIN with its office; BO section asks for the SO', (tester) async {
    final h = await Harness.create(tester, sample: false);
    await tester.runAsync(() async {
      await installDefaultScheme(h.services.schemes, (p) async => File(p).readAsBytesSync());
      await h.services.reloadActive();
    });
    await tester.pumpWidget(h.wrap(const PinBookScreen()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await settle(tester);
    expect(find.text('574201'), findsOneWidget);
    expect(find.text('Puttur SO'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('pin_book_search')), 'darbe');
    await tester.pump();
    expect(find.text('Darbe'), findsOneWidget);
    expect(find.text('574201'), findsNothing);

    await tester.pumpWidget(h.wrap(const LearnScreen()));
    await settle(tester);
    expect(find.text('Office name'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('learn_section_bo')));
    await tester.pump();
    expect(find.text('Its SO'), findsOneWidget);
    expect(find.text('Office name'), findsNothing);
  });

  testWidgets('PIN code quiz section: all, DK side, Udupi side, Non-TD, BO → PIN, BO → SO', (tester) async {
    final h = await Harness.create(tester, sample: false);
    await tester.runAsync(() async {
      await installDefaultScheme(h.services.schemes, (p) async => File(p).readAsBytesSync());
      await h.services.reloadActive();
    });
    await tester.pumpWidget(h.wrap(const LearnScreen()));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('learn_pin_quiz')));
    await settle(tester);
    for (final k in ['all', 'dk', 'udupi', 'nontd', 'bo_pin', 'bo_so']) {
      await tester.scrollUntilVisible(find.byKey(ValueKey('pinquiz_$k')), 200, scrollable: find.byType(Scrollable).last);
      expect(find.byKey(ValueKey('pinquiz_$k')), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.byKey(const ValueKey('pinquiz_dk_quiz')), -200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.byKey(const ValueKey('pinquiz_dk_quiz')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await settle(tester);
    expect(find.text('Which PIN for this office · TD'), findsOneWidget);
  });

  test('mistake practice: right answer, the wrong choice and same-kind options', () {
    final q = mistakeQuiz([
      (kind: 'quiz-bag-mangaloreTd-pin', question: 'Puttur SO', correct: '574201', chosen: '574202'),
      (kind: 'quiz-bag-mangaloreTd-pin', question: 'Bantwal SO', correct: '574211', chosen: null),
      (kind: 'quiz-bag-bo-parent', question: 'Kemminje BO', correct: 'Puttur SO – 574201', chosen: 'Bantwal SO – 574211'),
    ], random: Random(2));
    final puttur = q.firstWhere((x) => x.card.prompt == 'Puttur SO');
    expect(puttur.options, containsAll(['574201', '574202', '574211']));
    expect(puttur.card.asksPin, isTrue);
    final bo = q.firstWhere((x) => x.card.prompt == 'Kemminje BO');
    expect(bo.card.asksParent, isTrue);
    expect(bo.options, unorderedEquals(['Puttur SO – 574201', 'Bantwal SO – 574211']));
    expect(isPinQuizKind('quiz-bag-bo'), isTrue);
    expect(isPinQuizKind('quiz-bag-mangaloreTd'), isFalse);
  });

  testWidgets('PIN quiz shows progress per quiz and the mistakes list', (tester) async {
    final h = await Harness.create(tester, sample: false);
    await tester.runAsync(() async {
      await installDefaultScheme(h.services.schemes, (p) async => File(p).readAsBytesSync());
      await h.services.reloadActive();
      final id = h.services.active!.scheme.id;
      final kind = QuizScreen.kindFor(FlashMode.bag, LearnSection.mangaloreTd, LearnAsk.pin);
      await h.services.user.addQuiz(id, kind, 14, 20, 60000);
      await h.services.user.addQuiz(id, kind, 18, 20, 60000);
      await h.services.user.addQuiz(id, 'quiz-bag-mangaloreTd', 5, 20, 60000); // not a PIN quiz
      await h.services.user.addMistake(id, kind, 'Puttur SO', '574', '574201', '574202');
      await h.services.user.addMistake(id, kind, 'Puttur SO', '574', '574201', '574211');
    });
    await tester.pumpWidget(h.wrap(const PinQuizScreen()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(tester);
    final stats = find.byKey(const ValueKey('pinquiz_dk_stats'));
    await tester.scrollUntilVisible(stats, 200, scrollable: find.byType(Scrollable).last);
    expect((tester.widget<Text>(stats)).data, startsWith('2 quizzes · best 90% · last '));
    await tester.scrollUntilVisible(find.byKey(const ValueKey('pinquiz_mistakes')), -200, scrollable: find.byType(Scrollable).last);
    expect(find.text('80%'), findsWidgets); // average of 70 and 90
    await tester.tap(find.byKey(const ValueKey('pinquiz_mistakes')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(tester);
    expect(find.text('Puttur SO  →  574201'), findsOneWidget);
    expect(find.textContaining('Wrong 2 times'), findsOneWidget);
    expect(find.byKey(const ValueKey('mistakes_practise')), findsOneWidget);
  });
}
