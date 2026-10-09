import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/core/constants.dart';
import 'package:sorting_sahayak/core/contact.dart';
import 'package:sorting_sahayak/features/settings/contributors_screen.dart';

import 'helpers/app_harness.dart';

void main() {
  test('About shows the same version as pubspec.yaml', () {
    final v = RegExp(r'^version:\s*([\d.]+)\+', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
    expect(kAppVersion, v);
  });

  test('Play Store link uses the app package', () {
    expect(kPlayStoreUrl, endsWith('id=com.posorting.app'));
    expect(File('android/app/build.gradle.kts').readAsStringSync(), contains('applicationId = "com.posorting.app"'));
  });

  testWidgets('Contributors: team with roles and numbers, updates contact, share', (tester) async {
    final h = await Harness.create(tester, sample: false);
    await tester.pumpWidget(h.wrap(const ContributorsScreen()));
    await tester.pump();
    final list = find.byType(Scrollable).first;
    for (final (name, role, phone) in [
      ('Mahesh Rai', 'Design and development', '81056 93721'),
      ('Ranjith', 'App idea and sorting data', '82965 51488'),
      ('Ganesh Gowda', 'PIN code data', '97312 43939'),
      ('Gururaja', 'Sorting extract provider', '87227 79998'),
    ]) {
      await tester.scrollUntilVisible(find.byKey(ValueKey('contributor_$name')), 100, scrollable: list);
      final card = find.byKey(ValueKey('contributor_$name'));
      expect(find.descendant(of: card, matching: find.text(name)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(role)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(phone)), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.byKey(const ValueKey('updates_email')), 100, scrollable: list);
    expect(find.text('maheshraikg@gmail.com'), findsOneWidget);
    expect(find.byKey(const ValueKey('updates_whatsapp')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('share_app')), 100, scrollable: list);
  });
}
