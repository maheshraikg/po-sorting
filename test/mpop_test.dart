import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/data/import/table_reader.dart';
import 'package:sorting_sahayak/data/nsh.dart';
import 'package:sorting_sahayak/features/settings/parcel_network_screen.dart';

void main() {
  test('MPOP 07.10.2026: NPH hubs follow the revised L1 / L2 network', () {
    final nph = NshTable.parse(File(kRmsNphAsset).readAsBytesSync());
    String hub(String pin) => nph.resolve(pin)!.hub.name;
    expect(hub('590001'), 'Hubballi PH / Belagavi PH'); // Belagavi: L1 -> L2 of Hubli
    expect(hub('670001'), 'Kozhikode PH / Kannur PH'); // Kannur now under Kozhikode
    expect(hub('570001'), 'Bengaluru Parcel Hub / Mysuru PH');
    expect(hub('680001'), 'Thrissur PH'); // Thrissur is an L1 hub now
    expect(hub('574201'), isNot(contains('/'))); // Mangalore stays L1
  });

  test('MPOP list: 60 L1, 127 L2 with their L1, 52 direct bag closures', () {
    final t = readTable(File(kMpopAsset).readAsBytesSync(), 'mpop.csv');
    final hubs = parseParcelHubs(t.sheets[t.defaultSheet]!);
    expect(hubs.where((h) => h.isL1).length, 60);
    expect(hubs.where((h) => !h.isL1).length, 127);
    expect(hubs.where((h) => h.direct.isNotEmpty).length, 52);
    expect(hubs.where((h) => !h.isL1).every((h) => h.l1.isNotEmpty), isTrue);
    expect(hubs.firstWhere((h) => h.name == 'Mysuru').l1, 'Bangalore');
  });
}
