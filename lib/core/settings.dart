import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';

/// User preferences, persisted with shared_preferences (local only).
class Settings extends ChangeNotifier {
  Settings._(this._prefs);

  final SharedPreferences _prefs;

  static Future<Settings> load() async => Settings._(await SharedPreferences.getInstance());

  /// null = follow the device language (fallback English).
  Locale? get locale {
    final code = _prefs.getString('locale');
    return code == null || code.isEmpty ? null : Locale(code);
  }

  set locale(Locale? l) {
    if (l == null) {
      _prefs.remove('locale');
    } else {
      _prefs.setString('locale', l.languageCode);
    }
    notifyListeners();
  }

  ThemeMode get themeMode => ThemeMode.values.firstWhere(
    (m) => m.name == _prefs.getString('themeMode'),
    orElse: () => ThemeMode.system,
  );

  set themeMode(ThemeMode m) {
    _prefs.setString('themeMode', m.name);
    notifyListeners();
  }

  /// Text size for the whole app, on top of the phone's own setting
  /// (1.0 normal … 1.3 huge). Starts at large: sorting is read at arm's length.
  static const List<double> textSizes = [1.0, 1.1, 1.2, 1.3];

  double get textSize => _prefs.getDouble('textSize') ?? 1.1;

  set textSize(double v) {
    _prefs.setDouble('textSize', v);
    notifyListeners();
  }

  /// True once the bundled default scheme was offered (so deleting it does
  /// not bring it back on the next launch).
  bool get defaultSchemeDone => _prefs.getBool('defaultSchemeDone') ?? false;

  set defaultSchemeDone(bool v) => _prefs.setBool('defaultSchemeDone', v);

  /// True once the user accepted the disclaimer on first launch.
  bool get disclaimerAccepted => _prefs.getBool('disclaimerAccepted') ?? false;

  set disclaimerAccepted(bool v) {
    _prefs.setBool('disclaimerAccepted', v);
    notifyListeners();
  }

  bool get ttsEnabled => _prefs.getBool('tts') ?? false;

  set ttsEnabled(bool v) {
    _prefs.setBool('tts', v);
    notifyListeners();
  }

  bool get hapticsEnabled => _prefs.getBool('haptics') ?? true;

  set hapticsEnabled(bool v) {
    _prefs.setBool('haptics', v);
    notifyListeners();
  }

  /// Last mail category chosen on the Sort screen.
  String get category => _prefs.getString('category') ?? kCatTD;

  set category(String v) {
    _prefs.setString('category', v);
    notifyListeners();
  }

  bool get showMismatchField => _prefs.getBool('mismatchField') ?? false;

  set showMismatchField(bool v) {
    _prefs.setBool('mismatchField', v);
    notifyListeners();
  }

  /// Bundled default data version already applied (see kDefaultDataVersion).
  int get defaultDataVersion => _prefs.getInt('defaultDataVersion') ?? 1;

  set defaultDataVersion(int v) => _prefs.setInt('defaultDataVersion', v);

  /// The user's edited copy of a hub table (CSV), or null for the bundled
  /// sheet. [key] is the table's prefs key (nshCsv, l1Csv, nphCsv).
  String? tableCsv(String key) => _prefs.getString(key);

  void setTableCsv(String key, String? v) {
    if (v == null) {
      _prefs.remove(key);
    } else {
      _prefs.setString(key, v);
    }
    notifyListeners();
  }

  String? get nshCsv => tableCsv('nshCsv');

  set nshCsv(String? v) => setTableCsv('nshCsv', v);

  /// The user's own office name fixes: [{pin, type, old, new}], applied to
  /// the directory on every start (so they survive directory updates).
  List<Map<String, Object?>> get officeFixes {
    final raw = _prefs.getString('officeFixes');
    if (raw == null || raw.isEmpty) return const [];
    try {
      return [for (final e in jsonDecode(raw) as List) Map<String, Object?>.from(e as Map)];
    } catch (_) {
      return const [];
    }
  }

  set officeFixes(List<Map<String, Object?>> v) {
    _prefs.setString('officeFixes', jsonEncode(v));
    notifyListeners();
  }

  // ---- Learning progress (XP, level, daily streak, game records) ----

  /// Daily practice reminder: minutes after midnight, or null when off.
  int? get reminderMinutes => _prefs.getInt('reminderMinutes');

  set reminderMinutes(int? v) {
    if (v == null) {
      _prefs.remove('reminderMinutes');
    } else {
      _prefs.setInt('reminderMinutes', v);
    }
    notifyListeners();
  }

  int get learnXp => _prefs.getInt('learnXp') ?? 0;

  /// Day ("yyyy-mm-dd") XP was last earned.
  String get learnLastDay => _prefs.getString('learnLastDay') ?? '';

  int get _storedStreak => _prefs.getInt('learnStreak') ?? 0;

  int get _storedTodayXp => _prefs.getInt('learnTodayXp') ?? 0;

  /// Days in a row with practice; 0 once a day is missed.
  int learnStreak([DateTime? now]) {
    final d = _day(now ?? DateTime.now());
    return learnLastDay == d || learnLastDay == _day((now ?? DateTime.now()).subtract(const Duration(days: 1))) ? _storedStreak : 0;
  }

  int learnTodayXp([DateTime? now]) => learnLastDay == _day(now ?? DateTime.now()) ? _storedTodayXp : 0;

  /// Adds [xp] and updates the daily streak.
  void addLearnXp(int xp, {DateTime? now}) {
    if (xp <= 0) return;
    final t = now ?? DateTime.now();
    final today = _day(t);
    final yesterday = _day(t.subtract(const Duration(days: 1)));
    if (learnLastDay == today) {
      _prefs.setInt('learnTodayXp', _storedTodayXp + xp);
    } else {
      _prefs.setInt('learnStreak', learnLastDay == yesterday ? _storedStreak + 1 : 1);
      _prefs.setInt('learnTodayXp', xp);
      _prefs.setString('learnLastDay', today);
    }
    _prefs.setInt('learnXp', learnXp + xp);
    notifyListeners();
  }

  int speedBest(String key) => _prefs.getInt('speedBest_$key') ?? 0;

  void setSpeedBest(String key, int score) {
    _prefs.setInt('speedBest_$key', score);
    notifyListeners();
  }

  void resetLearnProgress() {
    for (final k in _prefs.getKeys().where((k) => k.startsWith('learn') || k.startsWith('speedBest_')).toList()) {
      _prefs.remove(k);
    }
    notifyListeners();
  }

  static String _day(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}
