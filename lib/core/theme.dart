import 'package:flutter/material.dart';

/// Brand palette: post-box red with mail-bag yellow, on a warm postcard
/// background; green for "found / correct" and sky blue for air. Generic
/// postal colours only, no organisation's logo or emblem.
const Color kPostRed = Color(0xFFB3261E); // primary, letter-box red
const Color kPostRedDeep = Color(0xFF3B0A08);
const Color kHeaderTop = Color(0xFF9A1B16);
const Color kHeaderBottom = Color(0xFFC62828);
const Color kPostGreen = Color(0xFF15803D);
const Color kMailYellow = Color(0xFFF2B300);
const Color kSky = Color(0xFF0EA5E9);
const Color kSkyDeep = Color(0xFF0369A1);

/// Vertical gradient under the app bar (seamless with its colour).
LinearGradient headerGradient(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: dark ? const [Color(0xFF4A0E0B), Color(0xFF6B1712)] : const [kHeaderTop, kHeaderBottom],
  );
}

// Kept for older call sites.
const Color kSeedRed = kPostRed;
const Color kAccentAmber = kMailYellow;

/// Label badge colours for the parcel bag pattern.
const Color kAirYellow = Color(0xFFFFD600);
const Color kSurfaceBlue = Color(0xFF1565C0);

/// Warning / success colours with good contrast in both themes.
Color warningColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
Color okColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: kPostRed, brightness: brightness).copyWith(
    primary: dark ? const Color(0xFFFFB4AB) : kPostRed,
    onPrimary: dark ? const Color(0xFF690005) : Colors.white,
    primaryContainer: dark ? const Color(0xFF7A1A14) : const Color(0xFFFDE2DF),
    onPrimaryContainer: dark ? const Color(0xFFFFDAD5) : kPostRedDeep,
    secondary: dark ? const Color(0xFFFFD54F) : kMailYellow,
    onSecondary: dark ? const Color(0xFF3A2A00) : const Color(0xFF2B1D00),
    secondaryContainer: dark ? const Color(0xFF5A4300) : const Color(0xFFFFEFC2),
    onSecondaryContainer: dark ? const Color(0xFFFFEFC2) : const Color(0xFF2B1D00),
    tertiary: dark ? const Color(0xFF86EFAC) : kPostGreen,
    surface: dark ? const Color(0xFF15100F) : const Color(0xFFFAF6EF),
    onSurface: dark ? const Color(0xFFEDE0DD) : const Color(0xFF231917),
    onSurfaceVariant: dark ? const Color(0xFFB9A9A5) : const Color(0xFF5B4A46),
    surfaceContainerLowest: dark ? const Color(0xFF1C1513) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF231B19) : Colors.white,
    surfaceContainer: dark ? const Color(0xFF2A211F) : Colors.white,
    surfaceContainerHigh: dark ? const Color(0xFF352B28) : const Color(0xFFF3EBE1),
    surfaceContainerHighest: dark ? const Color(0xFF403432) : const Color(0xFFEAE0D4),
    outline: dark ? const Color(0xFF7A6662) : const Color(0xFFA08C86),
    outlineVariant: dark ? const Color(0xFF4A3B38) : const Color(0xFFE2D6CC),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
  // Slightly larger, heavier text than the M3 defaults: sorting happens fast
  // and often in poor light.
  final t = base.textTheme;
  final text = t.copyWith(
    bodyLarge: t.bodyLarge?.copyWith(fontSize: 18),
    bodyMedium: t.bodyMedium?.copyWith(fontSize: 16),
    bodySmall: t.bodySmall?.copyWith(fontSize: 14),
    labelLarge: t.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
    titleMedium: t.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
    titleLarge: t.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
  );
  final radius = BorderRadius.circular(16);
  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: dark ? const Color(0xFF4A0E0B) : kHeaderTop,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: text.titleLarge?.copyWith(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800),
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: scheme.outlineVariant)),
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      elevation: 3,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant, size: 26),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelMedium?.copyWith(
          fontSize: 13,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
          color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.secondary,
      foregroundColor: scheme.onSecondary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 2)),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    listTileTheme: const ListTileThemeData(minVerticalPadding: 10),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
  );
}

/// Parses "#RRGGBB" / "RRGGBB" / colour names used in scheme files.
Color? parseColour(String? input) {
  if (input == null) return null;
  final s = input.trim().toLowerCase();
  if (s.isEmpty) return null;
  const named = {
    'red': Color(0xFFD32F2F),
    'green': Color(0xFF2E7D32),
    'blue': Color(0xFF1565C0),
    'yellow': Color(0xFFFBC02D),
    'orange': Color(0xFFEF6C00),
    'purple': Color(0xFF6A1B9A),
    'pink': Color(0xFFD81B60),
    'brown': Color(0xFF6D4C41),
    'grey': Color(0xFF616161),
    'gray': Color(0xFF616161),
    'black': Color(0xFF212121),
    'white': Color(0xFFFAFAFA),
    'teal': Color(0xFF00796B),
    'cyan': Color(0xFF0097A7),
    'maroon': Color(0xFF880E4F),
  };
  if (named.containsKey(s)) return named[s];
  final hex = s.replaceFirst('#', '');
  if (RegExp(r'^[0-9a-f]{6}$').hasMatch(hex)) return Color(int.parse('ff$hex', radix: 16));
  return null;
}

String colourToHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Palette offered in the bag editor and used for auto-assigned bag colours.
const List<Color> kBagPalette = [
  Color(0xFFD32F2F), Color(0xFF1565C0), Color(0xFF2E7D32), Color(0xFFEF6C00), //
  Color(0xFF6A1B9A), Color(0xFF00796B), Color(0xFFD81B60), Color(0xFF6D4C41), //
  Color(0xFF455A64), Color(0xFFF9A825), Color(0xFF0097A7), Color(0xFF880E4F),
];

/// Text colour with enough contrast on [bg].
Color onColour(Color bg) => bg.computeLuminance() > 0.45 ? Colors.black : Colors.white;
