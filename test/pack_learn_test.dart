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
    expect(x.bags, hasLength(97));
    final rnd = Random(1);
    final pinBag = x.pinToBag(rnd);
    expect(pinBag, hasLength(97));
    final hangal = pinBag.firstWhere((q) => q.card.prompt == '581104');
    expect(hangal.card.answer, 'Hangal SO');
    expect(hangal.options, contains('Hangal SO'));
    expect(hangal.options.toSet(), hasLength(4));
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
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('packlearn_bag')), matching: find.text('Quiz')));
    await settle(tester, rounds: 6);
    expect(find.byType(QuizScreen), findsOneWidget);
    expect(find.text('PIN → bag'), findsWidgets);
    expect(find.textContaining('1 / 20'), findsOneWidget);
  });
}
