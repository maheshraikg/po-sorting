import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/core/constants.dart';
import 'package:sorting_sahayak/data/import/scheme_io.dart';
import 'package:sorting_sahayak/data/scheme_repo.dart';
import 'package:sorting_sahayak/features/learn/learn_engine.dart';

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
}
