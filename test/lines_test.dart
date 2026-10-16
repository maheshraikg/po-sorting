import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/core/constants.dart';
import 'package:sorting_sahayak/data/models/scheme.dart';
import 'package:sorting_sahayak/features/lines/lines_screen.dart';

import 'helpers/app_harness.dart';

void main() {
  testWidgets('Non-TD prefix line lists its real PINs and offices', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(const LineDetailScreen(code: 'NT-61', category: kCatNonTD)));
    await settle(tester, rounds: 6);
    expect(find.text('671xxx'), findsOneWidget);
    expect(find.text('Kasargod'), findsWidgets);
    expect(find.text('2 PINs – tap to see all'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('area_671xxx')));
    await tester.pumpAndSettle();
    expect(find.text('671121'), findsOneWidget);
    expect(find.text('671543'), findsOneWidget);
    expect(find.text('Kasaragod HO'), findsOneWidget);
  });

  testWidgets('remove a PIN series from a Non-TD line; add buttons open the rule dialog', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(const LineDetailScreen(code: 'NT-61', category: kCatNonTD)));
    await settle(tester, rounds: 6);
    expect(find.byKey(const ValueKey('line_add_office')), findsOneWidget);
    expect(find.byKey(const ValueKey('line_add_pin')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('remove_671xxx')));
    await tester.pumpAndSettle();
    expect(find.text('Remove 671xxx from NT-61?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm_remove')));
    await settle(tester, rounds: 6);
    await tester.pumpAndSettle();
    expect(find.text('671xxx'), findsNothing);
    final left = h.services.active!.rules.where((r) => r.bagCode == 'NT-61').toList();
    expect(left.map((r) => r.match.type), [RuleType.office]);
    // The office row can be removed too.
    await tester.tap(find.byKey(const ValueKey('remove_Kasaragod')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_remove')));
    await settle(tester, rounds: 6);
    await tester.pumpAndSettle();
    expect(h.services.active!.rules.where((r) => r.bagCode == 'NT-61'), isEmpty);

    await tester.tap(find.byKey(const ValueKey('line_add_pin')));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('make a new line, then remove a line', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(const LinesScreen()));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('new_line')));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).first, 'Kateel Line');
    await tester.tap(find.text('Save'));
    await settle(tester, rounds: 6);
    await tester.pumpAndSettle();
    // Opened on the new (empty) line, ready to add offices / PINs.
    expect(find.byKey(const ValueKey('line_add_office')), findsOneWidget);
    expect(h.services.active!.bags.containsKey('Kateel Line'), isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('lines_filter')), 'Kateel');
    await tester.pumpAndSettle();
    expect(find.text('Kateel Line'), findsOneWidget);

    // Remove it again.
    await tester.tap(find.byKey(const ValueKey('remove_line_Kateel Line')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_remove_line')));
    await settle(tester, rounds: 6);
    await tester.pumpAndSettle();
    expect(h.services.active!.bags.containsKey('Kateel Line'), isFalse);
    expect(find.text('Kateel Line'), findsNothing);
  });

  testWidgets('edit an office, a PIN series and the line on a line', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(const LineDetailScreen(code: 'NT-61', category: kCatNonTD)));
    await settle(tester, rounds: 6);
    // Office row → rule dialog.
    await tester.tap(find.byKey(const ValueKey('edit_Kasaragod')));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    // PIN series → rule dialog.
    await tester.tap(find.byKey(const ValueKey('edit_671xxx')));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    // Line name / colour.
    await tester.tap(find.byKey(const ValueKey('edit_line')));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).at(1), 'Kasaragod side');
    await tester.tap(find.text('Save'));
    await settle(tester, rounds: 6);
    await tester.pumpAndSettle();
    expect(h.services.active!.bags['NT-61']!.name, 'Kasaragod side');
  });

  testWidgets('move a whole line, or one stop, from Non-TD to TD', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    List<BagRule> on(String mode) => h.services.active!.rules.where((r) => r.bagCode == 'NT-61' && r.category == mode).toList();
    final before = on(kCatNonTD).length;
    expect(before, greaterThan(1));
    await tester.pumpWidget(h.wrap(const LineDetailScreen(code: 'NT-61', category: kCatNonTD)));
    await settle(tester, rounds: 6);
    // One stop only.
    await tester.tap(find.byKey(const ValueKey('line_move_mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move_all')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('move_stop_0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('move_to_TD')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('move_mode_go')));
    await settle(tester, rounds: 6);
    expect(on(kCatTD), isNotEmpty);
    expect(on(kCatNonTD).length, lessThan(before));
    expect(find.text('Moved 1 to TD'), findsOneWidget);
    // The rest of the line.
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.tap(find.byKey(const ValueKey('line_move_mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move_mode_go')));
    await settle(tester, rounds: 6);
    expect(on(kCatNonTD), isEmpty);
    expect(on(kCatTD).length, before);
  });

  testWidgets('rename TD / Non-TD to the office own names', (tester) async {
    final h = await Harness.create(tester);
    h.settings.categoryNames = {kCatTD: 'Local'};
    await tester.pumpWidget(h.wrap(const LinesScreen()));
    await settle(tester);
    expect(find.text('Local'), findsOneWidget);
    h.settings.categoryNames = {};
    await tester.pumpAndSettle();
    expect(find.text('Local'), findsNothing);
  });
}
