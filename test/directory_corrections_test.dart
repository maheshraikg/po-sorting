import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/data/directory_builder.dart';
import 'package:sorting_sahayak/data/directory_repo.dart';

import 'helpers/fixture.dart';

void main() {
  test('the corrections file is well formed', () {
    final fixes = parseNameCorrections(File('data/directory_corrections.csv').readAsStringSync());
    expect(fixes.any((f) => f.pincode == 574313 && f.newName == 'Sulliapadavu'), isTrue);
  });

  test('a corrected BO name is shown and found; the old spelling still finds it', () async {
    final db = await fixtureDirectoryDb();
    final n = await applyNameCorrections(db, parseNameCorrections('pincode,office_type,old_name,new_name\n574202,BO,Darbe,Darbe Padavu\n'));
    expect(n, 1);
    final repo = DirectoryRepo(db);
    final offices = await repo.officesInRange(574202, 574202);
    expect(offices.map((o) => o.officeName), contains('Darbe Padavu'));
    expect((await repo.search('Darbe Padavu')).first.office.officeName, 'Darbe Padavu');
    expect((await repo.search('Darbe')).map((h) => h.office.officeName), contains('Darbe Padavu'));
  });
}
