// Applies data/directory_corrections.csv to the bundled directory DB without
// rebuilding it from the source CSV.
//
//   dart run tool/apply_directory_corrections.dart [--db assets/db/pincode_directory.db]
//
// After changing the bundled DB, bump kBundledDirectoryVersion in
// lib/data/db.dart so installed apps take the new copy.
import 'dart:io';

import 'package:sorting_sahayak/data/directory_builder.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  final i = args.indexOf('--db');
  final path = i >= 0 && i + 1 < args.length ? args[i + 1] : 'assets/db/pincode_directory.db';
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(File(path).absolute.path);
  final n = await applyNameCorrections(db, parseNameCorrections(File('data/directory_corrections.csv').readAsStringSync()));
  await db.execute('VACUUM');
  await db.close();
  stdout.writeln('$n office names corrected in $path');
}
