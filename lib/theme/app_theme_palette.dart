// Ecilaes - Cross-platform music player
// Copyright (C) 2024  hxprlee
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';

/// Raw color values for a single theme style + brightness.
///
/// This is the only place where hex literals and named colors live. The
/// [AppThemeBuilder] and [AppThemeExtension] consume an [AppPalette] to
/// produce the runtime `ColorScheme` and the semantic tokens that widgets
/// read.
@immutable
class AppPalette {
  /// The seed color used by Material 3's `ColorScheme.fromSeed`.
  /// Ignored for the Signature style.
  final Color seed;

  /// Primary foreground color (text, icons, accents).
  final Color foreground;

  /// Primary surface color (scaffold background, page chrome).
  final Color surface;

  /// Surface that sits one step above [surface] — cards, lists.
  final Color surfaceElevated;

  /// Surface that sits one step below [surface] — sidebars, sheets, drawers.
  final Color surfaceSunken;

  /// Surface for top-of-page headers.
  final Color surfaceOverlay;

  /// Optional override for the accent. Defaults to [foreground].
  final Color accent;

  const AppPalette({
    required this.seed,
    required this.foreground,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceSunken,
    required this.surfaceOverlay,
    this.accent = const Color(0x00000000), // sentinel: use foreground
  });

  Color get effectiveAccent =>
      accent == const Color(0x00000000) ? foreground : accent;
}

/// Bundles the light and dark variants of a style.
@immutable
class AppPaletteSet {
  final AppPalette light;
  final AppPalette dark;
  const AppPaletteSet({required this.light, required this.dark});
}

/// All built-in palettes. Add a new entry here to add a new style.
class AppPalettes {
  AppPalettes._();

  // ── Signature ────────────────────────────────────────────────────────
  // Warm gold foreground on dark slate. The original Ecilaes look.
  static const _sigSeed = Color(0xFF6750A4); // unused, kept for completeness
  static const _sigGold = Color(0xFFFFEFAF);

  static const _sigDarkSurface = Color(0xFF11171C);
  static const _sigDarkCard = Color(0xFF1E222B);
  static const _sigDarkSidebar = Color(0xFF1A1F24);
  static const _sigDarkHeader = Color(0xFF1A1F24);

  static const _sigLightSeed = Color(0xFFFCE7AC);
  static const _sigLightSurface = Color(0xFFFFFFFF);
  static const _sigLightCard = Color(0xFFF0F0F0);
  static const _sigLightSidebar = Color(0xFFF5F5F5);
  static const _sigLightHeader = Color(0xFFFAFAFA);

  static const signature = AppPaletteSet(
    light: AppPalette(
      seed: _sigLightSeed,
      foreground: _sigGold,
      surface: _sigLightSurface,
      surfaceElevated: _sigLightCard,
      surfaceSunken: _sigLightSidebar,
      surfaceOverlay: _sigLightHeader,
    ),
    dark: AppPalette(
      seed: _sigSeed,
      foreground: _sigGold,
      surface: _sigDarkSurface,
      surfaceElevated: _sigDarkCard,
      surfaceSunken: _sigDarkSidebar,
      surfaceOverlay: _sigDarkHeader,
    ),
  );

  // ── Material 3 / Monet ───────────────────────────────────────────────
  // The raw palette is irrelevant for M3 — the seed produces everything
  // at build time. We still ship a sentinel so the builder can resolve
  // a default when no dynamic seed is supplied.
  static const _m3Seed = Color(0xFF6750A4);

  static const material3 = AppPaletteSet(
    light: AppPalette(
      seed: _m3Seed,
      foreground: _m3Seed,
      surface: _m3Seed,
      surfaceElevated: _m3Seed,
      surfaceSunken: _m3Seed,
      surfaceOverlay: _m3Seed,
    ),
    dark: AppPalette(
      seed: _m3Seed,
      foreground: _m3Seed,
      surface: _m3Seed,
      surfaceElevated: _m3Seed,
      surfaceSunken: _m3Seed,
      surfaceOverlay: _m3Seed,
    ),
  );

  /// Default Material 3 seed used when no dynamic seed is supplied.
  static const Color defaultSeed = _m3Seed;
}
