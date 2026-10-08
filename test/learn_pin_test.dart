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
    expect(parent.map((c) => '${c.prompt}=${c.answer}'), containsAll(['Kemminje BO=Puttur SO', 'Panemangalore BO=Bantwal SO']));
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
}
