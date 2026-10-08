import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/core/constants.dart';
import 'package:sorting_sahayak/features/settings/contributors_screen.dart';

import 'helpers/app_harness.dart';

void main() {
  test('About shows the same version as pubspec.yaml', () {
    final v = RegExp(r'^version:\s*([\d.]+)\+', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
    expect(kAppVersion, v);
  });

  testWidgets('Contributors lists the developer and the data contributors', (tester) async {
    final h = await Harness.create(tester, sample: false);
    await tester.pumpWidget(h.wrap(const ContributorsScreen()));
    await tester.pump();
    expect(find.text('Mahesh Rai'), findsOneWidget);
    expect(find.text('81056 93721'), findsOneWidget);
    expect(find.byKey(const ValueKey('contact_call')), findsOneWidget);
    expect(find.byKey(const ValueKey('contact_whatsapp')), findsOneWidget);
    expect(find.text('Developed by'), findsOneWidget);
    expect(find.text('Ganesh Sir'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Ranjith'), 100, scrollable: find.byType(Scrollable).first);
    expect(find.text('Ranjith'), findsOneWidget);
    expect(find.text('Sorting data provided by'), findsOneWidget);
  });
}
