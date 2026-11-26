import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/data/import/scheme_io.dart';
import 'package:sorting_sahayak/features/learn/learn_screen.dart';
import 'package:sorting_sahayak/features/learn/quiz_screen.dart';
import 'package:sorting_sahayak/features/packs/office_packs.dart';
import 'package:sorting_sahayak/features/packs/pack_learn.dart';

import 'helpers/app_harness.dart';

Future<Uint8List> _load(String p) async => File(p).readAsBytesSync();
final _hub = kOfficePacks.firstWhere((p) => p.id == 'hubballi');

Future<Harness> _setUp(WidgetTester tester) async {
  final h = await Harness.create(tester, sample: false);
  await tester.runAsync(() async {
    await installDefaultScheme(h.services.schemes, (p) async => File(p).readAsBytesSync());
    await h.services.reloadActive();
  });
  return h;
}

void main() {
  testWidgets('Hubballi RMS lessons: PIN → bag, area → beat, village → BO', (tester) async {
    final h = await _setUp(tester);
    final x = (await tester.runAsync(() => PackLesson.load(_hub, h.services.directory, _load)))!;
    expect(x.bags, hasLength(190));
    final rnd = Random(1);
    final pinBag = x.pinToBag(rnd);
    expect(pinBag, hasLength(190));
    expect(x.groups, containsAll(['Gadag', 'Haveri', 'Karwar', 'Koppal']));
    final gadag = x.lineQuiz('Gadag', rnd);
    expect(gadag.where((q) => RegExp(r'^\d{6}$').hasMatch(q.card.prompt)), hasLength(22)); // 22 Gadag PINs
    expect(gadag.every((q) => q.options.contains(q.card.answer)), isTrue);
    expect(gadag.firstWhere((q) => q.card.prompt == '582116').card.answer, 'Lakshmeshwar SO');
    final gadagCodes = {
      for (final b in x.bags)
        if (b.group == 'Gadag') b.code,
    };
    expect(gadag.every((q) => gadagCodes.contains(q.card.answer)), isTrue); // only Gadag bags
    final hangal = pinBag.firstWhere((q) => q.card.prompt == '581104');
    expect(hangal.card.answer, 'Hangal SO');
    expect(hangal.options, contains('Hangal SO'));
    expect(hangal.options.toSet(), hasLength(4));
    final toLine = x.officeToLine(rnd);
    expect(toLine.length, greaterThanOrEqualTo(190));
    expect(toLine.firstWhere((q) => q.card.prompt == 'Lakshmeshwar SO').card.answer, 'Gadag');
    expect(toLine.firstWhere((q) => q.card.prompt == 'Hangal SO').card.answer, 'Haveri');
    expect(toLine.every((q) => q.options.contains(q.card.answer) && q.options.toSet().length == 4), isTrue);
    expect(toLine.map((q) => q.card.prompt.toLowerCase()).toSet(), hasLength(toLine.length));
    final beats = x.areaToBeat(rnd);
    expect(beats.length, greaterThan(300));
    expect(beats.where((q) => q.card.answer == 'Dharwad HO · Beat 2'), isNotEmpty);
    expect(beats.every((q) => q.options.contains(q.card.answer)), isTrue);
    final villages = x.villageToBo(rnd);
    expect(villages.length, greaterThan(800));
    expect(villages.every((q) => q.options.contains(q.card.answer)), isTrue);
  });

  testWidgets('Learn shows the office tile once the pack is on; a quiz opens with 20 questions', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final h = await _setUp(tester);
    await tester.pumpWidget(h.wrap(const LearnScreen()));
    await settle(tester);
    expect(find.byKey(const ValueKey('learn_pack_hubballi')), findsNothing);
    await tester.runAsync(() => setPack(h.settings, h.services, _hub, true, _load));
    await tester.pump();
    expect(find.byKey(const ValueKey('learn_pack_hubballi')), findsOneWidget);

    await tester.pumpWidget(h.wrap(PackLearnScreen(pack: _hub, loadAsset: _load)));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
    }
    expect(find.text('Learn Hubballi RMS'), findsOneWidget);
    expect(find.byKey(const ValueKey('packlearn_line_Gadag')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('packlearn_line_Gadag')));
    await tester.tap(find.byKey(const ValueKey('packlearn_line_Gadag')));
    await settle(tester, rounds: 6);
    expect(find.byType(QuizScreen), findsOneWidget);
    expect(find.text('Gadag · line quiz'), findsWidgets);
    await tester.pageBack();
    await settle(tester, rounds: 6);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('packlearn_officeline')), 200);
    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('packlearn_officeline')), matching: find.text('Quiz')),
    );
    await settle(tester, rounds: 6);
    expect(find.byType(QuizScreen), findsOneWidget);
    expect(find.text('Office → line'), findsWidgets);
    await tester.pageBack();
    await settle(tester, rounds: 6);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('packlearn_bag')), -200);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('packlearn_bag')), matching: find.text('Quiz')));
    await settle(tester, rounds: 6);
    expect(find.byType(QuizScreen), findsOneWidget);
    expect(find.text('PIN → bag'), findsWidgets);
    expect(find.textContaining('1 / 20'), findsOneWidget);
  });
}
