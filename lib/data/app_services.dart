/// Wires repositories together and caches the active scheme in memory.
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'directory_builder.dart' show NameCorrection, OfficeEdit, applyNameCorrections, applyOfficeEdits;
import 'directory_repo.dart';
import 'mismatch.dart';
import 'nsh.dart';
import 'scheme_repo.dart';
import 'sort_engine.dart';
import 'user_repo.dart';

class AppServices extends ChangeNotifier {
  AppServices({required Database directoryDb, required Database userDb})
    : _directoryDb = directoryDb,
      directory = DirectoryRepo(directoryDb),
      schemes = SchemeRepo(userDb),
      user = UserRepo(userDb);

  Database _directoryDb;
  DirectoryRepo directory;
  final SchemeRepo schemes;
  final UserRepo user;

  ActiveScheme? _active;
  List<String> _categories = const [];
  int _recentsVersion = 0;

  /// NSH / ICH table for speed post (bundled NSH sorting extract, or the
  /// user's edited copy).
  NshTable? nsh;

  /// RMS L1 and NPH per PIN (MR RMS sorting data, or the user's copies).
  NshTable? l1;
  NshTable? nph;

  /// NSH per PIN from the RMS data (compared with the NSH extract).
  NshTable? rmsNsh;

  void setNsh(NshTable t) => setTable(HubTableKind.nsh, t);

  NshTable? table(HubTableKind k) => switch (k) {
    HubTableKind.nsh => nsh,
    HubTableKind.l1 => l1,
    HubTableKind.nph => nph,
    HubTableKind.rmsNsh => rmsNsh,
  };

  void setTable(HubTableKind k, NshTable t) {
    switch (k) {
      case HubTableKind.nsh:
        nsh = t;
      case HubTableKind.l1:
        l1 = t;
      case HubTableKind.nph:
        nph = t;
      case HubTableKind.rmsNsh:
        rmsNsh = t;
    }
    notifyListeners();
  }

  ActiveScheme? get active => _active;
  List<String> get categories => _categories;

  /// Bumped whenever recents / favourites change so lists can refresh.
  int get recentsVersion => _recentsVersion;

  Map<int, ({List<String> districts, List<String> states})>? _regions;

  /// All directory PINs with districts/states (cached; for Learn and DMSL diffs).
  Future<Map<int, ({List<String> districts, List<String> states})>> pinRegions() async =>
      _regions ??= await directory.pinRegions();

  SortEngine get engine => SortEngine(directory, _active);
  MismatchChecker get mismatch => MismatchChecker(directory);

  Future<void> init() async {
    await reloadActive();
    // Load the fuzzy-search key cache in the background.
    directory.warmUp().ignore();
  }

  Future<void> reloadActive() async {
    _active = await schemes.loadActive();
    _categories = await schemes.categories();
    notifyListeners();
  }

  void touchRecents() {
    _recentsVersion++;
    notifyListeners();
  }

  /// Renames offices in the directory (the user's own fixes) and refreshes
  /// search. Returns the number renamed.
  Future<int> renameOffices(List<NameCorrection> fixes) async {
    final n = await applyNameCorrections(_directoryDb, fixes);
    if (n > 0) {
      directory = DirectoryRepo(_directoryDb);
      _regions = null;
      notifyListeners();
    }
    return n;
  }

  /// Adds, edits or removes offices in the directory (user changes).
  Future<int> editOffices(List<OfficeEdit> edits) async {
    final n = await applyOfficeEdits(_directoryDb, edits);
    if (n > 0) {
      directory = DirectoryRepo(_directoryDb);
      _regions = null;
      notifyListeners();
    }
    return n;
  }

  /// Swaps in a rebuilt directory database.
  Future<void> replaceDirectory(Database db) async {
    final old = _directoryDb;
    _directoryDb = db;
    directory = DirectoryRepo(db);
    _regions = null;
    notifyListeners();
    await old.close();
    directory.warmUp().ignore();
  }
}
