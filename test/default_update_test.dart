import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/core/constants.dart';
import 'package:sorting_sahayak/data/import/scheme_io.dart';
import 'package:sorting_sahayak/data/models/scheme.dart';
import 'package:sorting_sahayak/data/resolver.dart';
import 'package:sorting_sahayak/data/scheme_repo.dart';

import 'helpers/fixture.dart';

/// Assets as they were before the revised Karnataka L1 PH sheet.
Future<Uint8List> _oldAsset(String p) async => File(switch (p) {
  kDefaultSchemeAsset => 'test/fixtures/default_before_l1ph.csv',
  kDefaultAirAsset => 'test/fixtures/air_before_l1ph.csv',
  _ => p,
}).readAsBytesSync();

Future<Uint8List> _asset(String p) async => File(p).readAsBytesSync();

void main() {
  test('an older default install gets the revised Non-TD bags; TD lines stay', () async {
    final repo = SchemeRepo(await memoryUserDb());
    final id = await installDefaultScheme(repo, _oldAsset);
    // The user added a TD line of their own (no offices yet).
    await repo.upsertBag(id, const Bag(code: 'My new line'));
    String? bag(ActiveScheme s, int pin, String cat) => s.bagResolver.resolve(ResolveQuery(pin: pin, category: cat))?.rule.bagCode;
    var s = (await repo.loadActive())!;
    expect(bag(s, 416515, kCatNonTD), 'MARGAON');
    final tdBefore = s.bagResolver.rules.where((r) => r.category == kCatTD).length;

    expect(await updateDefaultNonTd(repo, _asset), isTrue);
    s = (await repo.loadActive())!;
    expect(bag(s, 416515, kCatNonTD), 'MUMBAI');
    expect(bag(s, 620001, kCatNonTD), 'CHENNAI');
    expect(bag(s, 171001, kCatNonTD), 'SHIMLA');
    expect(s.bags.containsKey('MARGAON'), isFalse);
    expect(s.bags.containsKey('TRICHY'), isFalse);
    expect(s.bags.containsKey('SHIMLA'), isTrue);
    expect(s.bags.containsKey('My new line'), isTrue);
    expect(s.bagResolver.rules.where((r) => r.category == kCatTD).length, tdBefore);
    expect(bag(s, 574239, kCatTD), 'Puttur Line');
    expect(s.airResolver.resolve(const ResolveQuery(pin: 900099))?.rule.airCode, 'CCU');
  });
}
