/// Cleans the data.gov.in "All India Pincode Directory" CSV and writes the
/// offline SQLite directory. Pure Dart (no Flutter imports) so it is shared
/// by `tool/build_directory_db.dart` and the in-app "Update PIN directory".
library;

import 'package:csv/csv.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../core/fuzzy.dart';

const int kDirectorySchemaVersion = 1;

/// Cleaned directory row ready for insertion.
class OfficeRecord {
  OfficeRecord({
    required this.pincode,
    required this.officeName,
    required this.officeType,
    required this.delivery,
    required this.division,
    required this.region,
    required this.circle,
    required this.district,
    required this.state,
    this.taluk = '',
    this.latitude,
    this.longitude,
  });

  final int pincode;
  final String officeName;
  final String officeType;
  final String delivery;
  final String division;
  final String region;
  final String circle;
  final String district;
  final String state;
  final String taluk;
  final double? latitude;
  final double? longitude;

  String get dedupeKey =>
      '$pincode|$officeName|$officeType|$delivery|$division|$region|$circle|$district|$state|$taluk|$latitude|$longitude';

  List<Object?> toList() => [
    pincode, officeName, officeType, delivery, division, region, circle, district, state, taluk, latitude, longitude, //
  ];

  static OfficeRecord fromList(List<Object?> l) => OfficeRecord(
    pincode: l[0] as int,
    officeName: l[1] as String,
    officeType: l[2] as String,
    delivery: l[3] as String,
    division: l[4] as String,
    region: l[5] as String,
    circle: l[6] as String,
    district: l[7] as String,
    state: l[8] as String,
    taluk: l[9] as String,
    latitude: l[10] as double?,
    longitude: l[11] as double?,
  );
}

/// Column synonyms (lower-cased, spaces/underscores removed).
const Map<String, List<String>> _columnSynonyms = {
  'circle': ['circlename', 'circle'],
  'region': ['regionname', 'region'],
  'division': ['divisionname', 'division'],
  'office': ['officename', 'office', 'postoffice', 'poname'],
  'pincode': ['pincode', 'pin', 'pincodes', 'postalcode'],
  'officetype': ['officetype', 'type'],
  'delivery': ['delivery', 'deliverystatus'],
  'district': ['district', 'districtname'],
  'state': ['statename', 'state'],
  'taluk': ['taluk', 'taluka', 'tehsil'],
  'latitude': ['latitude', 'lat'],
  'longitude': ['longitude', 'long', 'lng', 'lon'],
};

String _headerKey(Object? h) => '$h'.toLowerCase().replaceAll(RegExp(r'[\s_\-.]'), '');

/// Maps logical column → index. Throws [FormatException] when the required
/// office / pincode columns are missing.
Map<String, int> detectDirectoryColumns(List<Object?> header) {
  final keys = header.map(_headerKey).toList();
  final out = <String, int>{};
  _columnSynonyms.forEach((field, syns) {
    for (final s in syns) {
      final i = keys.indexOf(s);
      if (i >= 0) {
        out[field] = i;
        break;
      }
    }
  });
  if (!out.containsKey('office') || !out.containsKey('pincode')) {
    throw FormatException('CSV needs at least officename and pincode columns; found: ${header.join(', ')}');
  }
  return out;
}

final RegExp _typeSuffix = RegExp(
  r'\s*[\s(]\s*(G\.?\s?P\.?\s?O|H\.?\s?P\.?\s?O|B\.?\s?O|S\.?\s?O|H\.?\s?O|P\.?\s?O)\s*\.?\s*\)?\s*$',
  caseSensitive: false,
);

/// Title-cases "ACHALAPUR" / "achalapur east" → "Achalapur East", keeping
/// short all-caps tokens with dots (e.g. "N.I.T.K") upper-case.
String titleCase(String s) {
  final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
  return t.replaceAllMapped(RegExp(r"[A-Za-z][A-Za-z']*"), (m) {
    final w = m[0]!;
    final start = m.start;
    // Letter directly followed by a dot and part of an abbreviation: keep upper.
    final end = m.end;
    final isAbbr = w.length == 1 && end < t.length && t[end] == '.';
    if (isAbbr) return w.toUpperCase();
    if (start > 0 && t[start - 1] == "'") return w.toLowerCase();
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  });
}

/// Splits "Puttur S.O" → ("Puttur", "SO").
(String, String) splitOfficeType(String rawName) {
  final m = _typeSuffix.firstMatch(rawName);
  if (m == null) return (rawName.trim(), '');
  final type = m[1]!.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
  return (rawName.substring(0, m.start).trim(), type == 'GPO' || type == 'HPO' ? 'HO' : type);
}

double? _coord(Object? v) {
  final s = '${v ?? ''}'.trim();
  if (s.isEmpty || s.toUpperCase() == 'NA' || s.toUpperCase() == 'NULL') return null;
  final d = double.tryParse(s.replaceAll(RegExp(r'[^0-9.\-]'), ''));
  if (d == null || d == 0) return null;
  return d;
}

String _delivery(Object? v) {
  final s = '${v ?? ''}'.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  if (s.startsWith('non')) return 'Non-Delivery';
  return 'Delivery';
}

String _normType(String t) {
  final u = t.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
  if (u == 'BO' || u == 'SO' || u == 'HO' || u == 'PO') return u;
  if (u == 'GPO' || u == 'HPO') return 'HO';
  if (u.startsWith('B')) return 'BO';
  if (u.startsWith('S')) return 'SO';
  if (u.startsWith('H')) return 'HO';
  return u.isEmpty ? '' : 'PO';
}

/// Parses and cleans CSV text. When [stateFilter] is given, keeps only that
/// state (case-insensitive, e.g. "Karnataka"). [onProgress] gets 0..1.
List<OfficeRecord> parseDirectoryCsv(
  String content, {
  String? stateFilter,
  void Function(double progress)? onProgress,
}) {
  final rows = Csv(dynamicTyping: false).decode(content.startsWith('﻿') ? content.substring(1) : content);
  if (rows.isEmpty) return [];
  final cols = detectDirectoryColumns(rows.first);
  String cell(List<dynamic> r, String f) {
    final i = cols[f];
    if (i == null || i >= r.length) return '';
    return '${r[i] ?? ''}'.trim();
  }

  final seen = <String>{};
  final out = <OfficeRecord>[];
  final filter = stateFilter?.trim().toLowerCase();
  for (var n = 1; n < rows.length; n++) {
    if (onProgress != null && n % 5000 == 0) onProgress(n / rows.length);
    final r = rows[n];
    final pin = int.tryParse(cell(r, 'pincode').replaceAll(RegExp(r'\D'), ''));
    if (pin == null || pin < 100000 || pin > 999999) continue;
    final state = titleCase(cell(r, 'state'));
    if (filter != null && filter.isNotEmpty && state.toLowerCase() != filter) continue;
    final (name, suffixType) = splitOfficeType(cell(r, 'office'));
    if (name.isEmpty) continue;
    final colType = _normType(cell(r, 'officetype'));
    final rec = OfficeRecord(
      pincode: pin,
      officeName: titleCase(name),
      officeType: colType.isNotEmpty ? colType : _normType(suffixType),
      delivery: _delivery(cell(r, 'delivery')),
      division: titleCase(cell(r, 'division')),
      region: titleCase(cell(r, 'region')),
      circle: titleCase(cell(r, 'circle')),
      district: titleCase(cell(r, 'district')),
      state: state,
      taluk: titleCase(cell(r, 'taluk')),
      latitude: _coord(cols.containsKey('latitude') ? r[cols['latitude']!] : null),
      longitude: _coord(cols.containsKey('longitude') ? r[cols['longitude']!] : null),
    );
    if (seen.add(rec.dedupeKey)) out.add(rec);
  }
  onProgress?.call(1);
  return out;
}

const String _createOffices = '''
CREATE TABLE offices(
  id INTEGER PRIMARY KEY,
  pincode INTEGER NOT NULL,
  office_name TEXT NOT NULL,
  office_name_norm TEXT NOT NULL,
  office_words TEXT NOT NULL,
  name_key TEXT NOT NULL,
  office_type TEXT,
  delivery TEXT,
  unit_id INTEGER,
  district TEXT,
  district_norm TEXT,
  taluk TEXT,
  taluk_norm TEXT,
  state TEXT,
  lat_e5 INTEGER,
  lng_e5 INTEGER
)''';

/// Division → region → circle, stored once per division to keep the DB small.
const String _createUnits = '''
CREATE TABLE units(
  id INTEGER PRIMARY KEY,
  circle TEXT,
  region TEXT,
  division TEXT
)''';

/// Columns of an office row as the app reads them (joins the units table).
const String kOfficeSelect =
    'o.id AS id, o.pincode AS pincode, o.office_name AS office_name, o.office_type AS office_type, '
    'o.delivery AS delivery, u.division AS division, u.region AS region, u.circle AS circle, '
    'o.district AS district, o.state AS state, o.taluk AS taluk, o.lat_e5 AS lat_e5, o.lng_e5 AS lng_e5';
const String kOfficeFrom = 'offices o LEFT JOIN units u ON u.id = o.unit_id';

int? _e5(double? v) => v == null ? null : (v * 100000).round();

/// Creates the schema (dropping any previous tables) and inserts [records].
/// Tries to build an FTS5 index; when the SQLite build has no FTS5, search
/// falls back to LIKE queries. Returns true when FTS5 was built.
Future<bool> writeDirectoryDb(
  Database db,
  List<OfficeRecord> records, {
  Map<String, String> meta = const {},
  bool tryFts = true,
  void Function(double progress)? onProgress,
}) async {
  await db.execute('DROP TABLE IF EXISTS offices_fts');
  await db.execute('DROP TABLE IF EXISTS offices');
  await db.execute('DROP TABLE IF EXISTS units');
  await db.execute('DROP TABLE IF EXISTS meta');
  await db.execute(_createOffices);
  await db.execute(_createUnits);
  await db.execute('CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT)');

  final units = <String, int>{};
  final unitBatch = db.batch();
  for (final r in records) {
    final k = '${r.circle}|${r.region}|${r.division}';
    if (units.containsKey(k)) continue;
    units[k] = units.length + 1;
    unitBatch.insert('units', {'id': units[k], 'circle': r.circle, 'region': r.region, 'division': r.division});
  }
  await unitBatch.commit(noResult: true);

  var anyTaluk = false;
  const chunk = 2000;
  for (var start = 0; start < records.length; start += chunk) {
    final batch = db.batch();
    final end = start + chunk > records.length ? records.length : start + chunk;
    for (var i = start; i < end; i++) {
      final r = records[i];
      // "Puttur(D.K.)" → index as "puttur" (the qualifier stays searchable
      // through office_words).
      final bare = r.officeName.replaceAll(RegExp(r'\(.*?\)'), ' ').trim();
      final norm = normalizePlace(bare.isEmpty ? r.officeName : bare);
      if (r.taluk.isNotEmpty) anyTaluk = true;
      batch.rawInsert(
        'INSERT INTO offices(pincode, office_name, office_name_norm, office_words, name_key, office_type, delivery, '
        'unit_id, district, district_norm, taluk, taluk_norm, state, lat_e5, lng_e5) '
        'VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          r.pincode, r.officeName, norm, placeWords(r.officeName).join(' '), phoneticKey(norm), //
          r.officeType, r.delivery, units['${r.circle}|${r.region}|${r.division}'], r.district, //
          normalizePlace(r.district), r.taluk.isEmpty ? null : r.taluk, r.taluk.isEmpty ? null : normalizePlace(r.taluk), //
          r.state, _e5(r.latitude), _e5(r.longitude),
        ],
      );
    }
    await batch.commit(noResult: true);
    onProgress?.call(end / records.length * 0.9);
  }
  await db.execute('CREATE INDEX idx_offices_pincode ON offices(pincode)');
  await db.execute('CREATE INDEX idx_offices_name_norm ON offices(office_name_norm)');
  await db.execute('CREATE INDEX idx_offices_name_key ON offices(name_key)');
  await db.execute('CREATE INDEX idx_offices_district_norm ON offices(district_norm)');
  if (anyTaluk) await db.execute('CREATE INDEX idx_offices_taluk_norm ON offices(taluk_norm)');

  var fts = false;
  if (tryFts) {
    try {
      await db.execute(
        "CREATE VIRTUAL TABLE offices_fts USING fts5(office_words, district_norm, content='offices', "
        "content_rowid='id', columnsize=0, detail=none)",
      );
      await db.execute("INSERT INTO offices_fts(offices_fts) VALUES('rebuild')");
      fts = true;
    } on Object {
      fts = false;
    }
  }
  final allMeta = {
    'schema_version': '$kDirectorySchemaVersion',
    'row_count': '${records.length}',
    'fts': fts ? '1' : '0',
    ...meta,
  };
  final b = db.batch();
  allMeta.forEach((k, v) => b.insert('meta', {'key': k, 'value': v}));
  await b.commit(noResult: true);
  onProgress?.call(1);
  return fts;
}


/// A local fix to an office name in the data.gov.in directory.
class NameCorrection {
  const NameCorrection({required this.pincode, required this.officeType, required this.oldName, required this.newName});

  final int pincode;
  final String officeType;
  final String oldName;
  final String newName;
}

/// Reads `pincode,office_type,old_name,new_name[,note]` lines (header first).
List<NameCorrection> parseNameCorrections(String csv) => [
  for (final line in csv.split(RegExp(r'\r?\n')).skip(1))
    if (line.trim().isNotEmpty)
      () {
        final f = line.split(',');
        return NameCorrection(pincode: int.parse(f[0].trim()), officeType: f[1].trim(), oldName: f[2].trim(), newName: f[3].trim());
      }(),
];

/// Renames offices in a built directory DB. The old spelling stays
/// searchable. Returns the number of offices renamed.
Future<int> applyNameCorrections(Database db, List<NameCorrection> fixes) async {
  var n = 0;
  for (final c in fixes) {
    final bare = c.newName.replaceAll(RegExp(r'\(.*?\)'), ' ').trim();
    final norm = normalizePlace(bare.isEmpty ? c.newName : bare);
    final words = {...placeWords(c.newName), ...placeWords(c.oldName)}.join(' ');
    n += await db.rawUpdate(
      'UPDATE offices SET office_name = ?, office_name_norm = ?, office_words = ?, name_key = ? '
      'WHERE pincode = ? AND office_type = ? AND office_name = ?',
      [c.newName, norm, words, phoneticKey(norm), c.pincode, c.officeType, c.oldName],
    );
  }
  if (n > 0) {
    try {
      await db.execute("INSERT INTO offices_fts(offices_fts) VALUES('rebuild')");
    } catch (_) {
      // No FTS5 index in this DB.
    }
  }
  return n;
}

/// One office as the user sees and edits it.
class OfficeData {
  const OfficeData({required this.pincode, required this.name, this.type = '', this.delivery = true, this.district = '', this.state = ''});

  final int pincode;
  final String name;
  final String type;
  final bool delivery;
  final String district;
  final String state;

  factory OfficeData.fromJson(Map<String, Object?> m) => OfficeData(
    pincode: (m['pin'] as num).toInt(),
    name: m['name'] as String? ?? '',
    type: m['type'] as String? ?? '',
    delivery: m['delivery'] as bool? ?? true,
    district: m['district'] as String? ?? '',
    state: m['state'] as String? ?? '',
  );

  Map<String, Object?> toJson() => {'pin': pincode, 'name': name, 'type': type, 'delivery': delivery, 'district': district, 'state': state};

  /// Same office (PIN, name and type identify a directory row).
  bool sameOffice(OfficeData o) => o.pincode == pincode && o.name == name && o.type == type;

  bool sameAs(OfficeData o) => sameOffice(o) && o.delivery == delivery && o.district == district && o.state == state;
}

/// A user change to the directory: add ([before] null), delete ([after]
/// null) or edit.
class OfficeEdit {
  const OfficeEdit({this.before, this.after});

  final OfficeData? before;
  final OfficeData? after;

  factory OfficeEdit.fromJson(Map<String, Object?> m) => OfficeEdit(
    before: m['before'] == null ? null : OfficeData.fromJson(Map<String, Object?>.from(m['before'] as Map)),
    after: m['after'] == null ? null : OfficeData.fromJson(Map<String, Object?>.from(m['after'] as Map)),
  );

  Map<String, Object?> toJson() => {'before': before?.toJson(), 'after': after?.toJson()};

  OfficeEdit get inverse => OfficeEdit(before: after, after: before);
}

/// Applies [edits] to the directory. Safe to run again: an edit or delete
/// only touches a row that still has the old values, an add is skipped if
/// the office is already there. Returns the number of rows changed.
Future<int> applyOfficeEdits(Database db, List<OfficeEdit> edits) async {
  var n = 0;
  const where = 'pincode = ? AND office_name = ? AND IFNULL(office_type, \'\') = ?';
  List<Object?> key(OfficeData o) => [o.pincode, o.name, o.type];
  Map<String, Object?> row(OfficeData o) {
    final bare = o.name.replaceAll(RegExp(r'\(.*?\)'), ' ').trim();
    final norm = normalizePlace(bare.isEmpty ? o.name : bare);
    return {
      'pincode': o.pincode,
      'office_name': o.name,
      'office_name_norm': norm,
      'office_words': placeWords(o.name).join(' '),
      'name_key': phoneticKey(norm),
      'office_type': o.type,
      'delivery': o.delivery ? 'Delivery' : 'Non Delivery',
      'district': o.district,
      'district_norm': normalizePlace(o.district),
      'state': o.state,
    };
  }

  for (final e in edits) {
    final before = e.before, after = e.after;
    if (before == null && after != null) {
      final exists = await db.query('offices', columns: ['id'], where: where, whereArgs: key(after), limit: 1);
      if (exists.isNotEmpty) continue;
      // Same division / region / circle as the other offices at that PIN.
      final unit = await db.query('offices', columns: ['unit_id'], where: 'pincode = ? AND unit_id IS NOT NULL', whereArgs: [after.pincode], limit: 1);
      await db.insert('offices', {...row(after), 'unit_id': unit.isEmpty ? null : unit.first['unit_id']});
      n++;
    } else if (before != null && after == null) {
      n += await db.delete('offices', where: where, whereArgs: key(before));
    } else if (before != null && after != null) {
      n += await db.update('offices', row(after), where: where, whereArgs: key(before));
    }
  }
  if (n > 0) {
    try {
      await db.execute("INSERT INTO offices_fts(offices_fts) VALUES('rebuild')");
    } catch (_) {
      // No FTS5 index in this DB.
    }
  }
  return n;
}
