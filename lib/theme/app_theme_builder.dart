// Ecilaes - Cross-platform music player
// Copyright (C) 2024  Anton Borri
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
import 'app_theme_extension.dart';
import 'app_theme_palette.dart';
import 'app_theme_style.dart';

/// Centralized builder that produces [ThemeData] for each [AppThemeStyle].
class AppThemeBuilder {
  AppThemeBuilder._();

  // ── Font fallbacks ───────────────────────────────────────────────────
  static const _cjkFallback = <String>[
    'Noto Sans CJK JP',
    'Noto Sans CJK SC',
    'Noto Sans CJK TC',
    'Noto Sans CJK KR',
    'Apple Color Emoji',
  ];

  // ─────────────────────────────────────────────────────────────────────
  // Public entry points
  // ─────────────────────────────────────────────────────────────────────

  static ThemeData buildLight(
    AppThemeStyle style, {
    String? fontFamily,
    Color? seedColor,
    bool isDesktop = false,
    bool desktopTransparency = false,
  }) =>
      _build(
        style,
        Brightness.light,
        fontFamily: fontFamily,
        seedColor: seedColor,
        isDesktop: isDesktop,
        desktopTransparency: desktopTransparency,
      );

  static ThemeData buildDark(
    AppThemeStyle style, {
    String? fontFamily,
    Color? seedColor,
    bool isDesktop = false,
    bool desktopTransparency = false,
  }) =>
      _build(
        style,
        Brightness.dark,
        fontFamily: fontFamily,
        seedColor: seedColor,
        isDesktop: isDesktop,
        desktopTransparency: desktopTransparency,
      );

  // ─────────────────────────────────────────────────────────────────────
  // Internal
  // ─────────────────────────────────────────────────────────────────────

  static ThemeData _build(
    AppThemeStyle style,
    Brightness brightness, {
    String? fontFamily,
    Color? seedColor,
    required bool isDesktop,
    required bool desktopTransparency,
  }) {
    switch (style) {
      case AppThemeStyle.signature:
        return _buildSignature(
          brightness,
          fontFamily: fontFamily,
          isDesktop: isDesktop,
          desktopTransparency: desktopTransparency,
        );
      case AppThemeStyle.material3:
        return _buildMaterial3(
          brightness,
          fontFamily: fontFamily,
          seedColor: seedColor,
          isDesktop: isDesktop,
          desktopTransparency: desktopTransparency,
        );
    }
  }

  static ThemeData _buildSignature(
    Brightness brightness, {
    String? fontFamily,
    required bool isDesktop,
    required bool desktopTransparency,
  }) {
    final palette = brightness == Brightness.dark
        ? AppPalettes.signature.dark
        : AppPalettes.signature.light;

    final ColorScheme scheme = brightness == Brightness.dark
        ? _signatureDarkScheme(palette)
        : _signatureLightScheme(palette);

    final scaffoldBg = _signatureScaffoldBackground(
      palette: palette,
      scheme: scheme,
      isDesktop: isDesktop,
      desktopTransparency: desktopTransparency,
    );

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      fontFamilyFallback: _cjkFallback,
      extensions: [_signatureExtension(palette, scheme)],
    );
  }

  static ThemeData _buildMaterial3(
    Brightness brightness, {
    String? fontFamily,
    Color? seedColor,
    required bool isDesktop,
    required bool desktopTransparency,
  }) {
    final seed = seedColor ?? AppPalettes.defaultSeed;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    final scaffoldBg = _material3ScaffoldBackground(
      scheme: scheme,
      isDesktop: isDesktop,
      desktopTransparency: desktopTransparency,
    );

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      fontFamilyFallback: _cjkFallback,
      extensions: [_material3Extension(scheme)],
    );
  }

  // ── Shared helpers ───────────────────────────────────────────────────

  static Color? _signatureScaffoldBackground({
    required AppPalette palette,
    required ColorScheme scheme,
    required bool isDesktop,
    required bool desktopTransparency,
  }) {
    if (!isDesktop) return null;
    if (scheme.brightness == Brightness.dark) {
      return desktopTransparency
          ? palette.surface.withValues(alpha: 0.7)
          : palette.surface;
    }
    return desktopTransparency
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.white;
  }

  static Color? _material3ScaffoldBackground({
    required ColorScheme scheme,
    required bool isDesktop,
    required bool desktopTransparency,
  }) {
    if (!isDesktop) return null;
    return desktopTransparency
        ? scheme.surface.withValues(alpha: 0.7)
        : scheme.surface;
  }

  // ── Signature ColorSchemes ───────────────────────────────────────────

  static ColorScheme _signatureLightScheme(AppPalette p) {
    return ColorScheme.fromSeed(
      seedColor: const Color(0xFFFCE7AC),
      brightness: Brightness.light,
      secondary: p.foreground,
    );
  }

  static ColorScheme _signatureDarkScheme(AppPalette p) {
    return ColorScheme(
      brightness: Brightness.dark,
      primary: p.foreground,
      onPrimary: p.surface,
      secondary: p.foreground,
      onSecondary: p.surface,
      tertiary: p.foreground,
      onTertiary: p.surface,
      error: const Color(0xFFFF6B6B),
      onError: p.surface,
      surface: p.surface,
      onSurface: p.foreground,
      surfaceContainerHighest: p.surface,
      surfaceContainerHigh: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerLow: p.surface,
      surfaceContainerLowest: p.surface,
      outline: p.foreground.withValues(alpha: 0.3),
      outlineVariant: p.foreground.withValues(alpha: 0.1),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: p.foreground,
      onInverseSurface: p.surface,
      inversePrimary: p.surface,
      surfaceTint: p.foreground,
    );
  }

  // ── AppThemeExtension builders ───────────────────────────────────────

  static AppThemeExtension _signatureExtension(
    AppPalette p,
    ColorScheme scheme,
  ) {
    return AppThemeExtension(
      scheme: AppColorScheme.signature,
      cardBackground: p.surfaceElevated,
      playerBarBackground: p.surface,
      sidebarBackground: p.surfaceSunken,
      headerBarBackground: p.surfaceOverlay,
      placeholderIcon: Colors.white54,
      circleIconBackground: Colors.black.withValues(alpha: 0.3),
    );
  }

  static AppThemeExtension _material3Extension(ColorScheme scheme) {
    return AppThemeExtension(
      scheme: AppColorScheme.material3,
      cardBackground: scheme.surfaceContainerHighest,
      playerBarBackground: scheme.surfaceContainer,
      sidebarBackground: scheme.surfaceContainerLow,
      headerBarBackground: scheme.surface,
      placeholderIcon: scheme.onSurface.withValues(alpha: 0.3),
      circleIconBackground: scheme.surfaceContainerHighest,
    );
  }
}
