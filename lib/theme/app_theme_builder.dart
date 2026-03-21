import 'package:flutter/material.dart';
import 'app_theme_extensions.dart';
import 'app_theme_style.dart';

/// Centralized builder that produces [ThemeData] for each [AppThemeStyle].
class AppThemeBuilder {
  AppThemeBuilder._();

  // ── Signature palette constants ──────────────────────────────────────
  static const _sigSeed = Color.fromARGB(255, 17, 23, 28);
  static const _sigSecondary = Color(0xFFFFEFAF);
  static const _sigScaffoldTransparent = Color.fromARGB(178, 17, 23, 28);
  static const _sigScaffoldOpaque = Color.fromARGB(255, 17, 23, 28);

  // ── Material 3 palette constant ──────────────────────────────────────
  static const _m3Seed = Color(0xFF6750A4); // Material default purple

  // ── Font Fallbacks ───────────────────────────────────────────────────
  static const _cjkFallback = <String>[
    'Noto Sans CJK JP',
    'Noto Sans CJK SC',
    'Noto Sans CJK TC',
    'Noto Sans CJK KR',
    'Apple Color Emoji',
  ];

  // ─────────────────────────────────────────────────────────────────────
  // Light theme
  // ─────────────────────────────────────────────────────────────────────
  static ThemeData buildLight(
    AppThemeStyle style, {
    String? fontFamily,
    Color? seedColor,
    bool isDesktop = false,
    bool desktopTransparency = false,
  }) {
    switch (style) {
      case AppThemeStyle.signature:
        return _signatureLight(fontFamily, isDesktop, desktopTransparency);
      case AppThemeStyle.material3:
        return _material3Light(
          fontFamily,
          seedColor,
          isDesktop,
          desktopTransparency,
        );
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Dark theme
  // ─────────────────────────────────────────────────────────────────────
  static ThemeData buildDark(
    AppThemeStyle style, {
    String? fontFamily,
    Color? seedColor,
    bool isDesktop = false,
    bool desktopTransparency = false,
  }) {
    switch (style) {
      case AppThemeStyle.signature:
        return _signatureDark(fontFamily, isDesktop, desktopTransparency);
      case AppThemeStyle.material3:
        return _material3Dark(
          fontFamily,
          seedColor,
          isDesktop,
          desktopTransparency,
        );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Signature
  // ═══════════════════════════════════════════════════════════════════════

  static ThemeData _signatureLight(
    String? fontFamily,
    bool isDesktop,
    bool desktopTransparency,
  ) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFCE7AC),
      brightness: Brightness.light,
      secondary: const Color(0xFFFCE7AC),
    );

    Color? scaffoldBg;
    if (isDesktop) {
      scaffoldBg = desktopTransparency
          ? Colors.white.withValues(alpha: 0.7)
          : Colors.white;
    }

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      fontFamilyFallback: _cjkFallback,
      extensions: const [AppThemeExtension.lightExtension],
    );
  }

  static ThemeData _signatureDark(
    String? fontFamily,
    bool isDesktop,
    bool desktopTransparency,
  ) {
    Color? scaffoldBg;
    if (isDesktop) {
      scaffoldBg = desktopTransparency
          ? _sigScaffoldTransparent
          : _sigScaffoldOpaque;
    }

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _sigSeed,
        brightness: Brightness.dark,
        secondary: _sigSecondary,
      ),
      useMaterial3: true,
      fontFamily: fontFamily,
      fontFamilyFallback: _cjkFallback,
      extensions: const [AppThemeExtension.darkExtension],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Material 3 / Monet
  // ═══════════════════════════════════════════════════════════════════════

  static ThemeData _material3Light(
    String? fontFamily,
    Color? seedColor,
    bool isDesktop,
    bool desktopTransparency,
  ) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor ?? _m3Seed,
      brightness: Brightness.light,
    );

    Color? scaffoldBg;
    if (isDesktop) {
      scaffoldBg = desktopTransparency
          ? scheme.surface.withValues(alpha: 0.7)
          : scheme.surface;
    }

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      fontFamilyFallback: _cjkFallback,
      extensions: [
        AppThemeExtension(
          songCardBackground: scheme.surfaceContainerHighest,
          playerBarBackground: scheme.surfaceContainer,
          sidebarBackground: scheme.surfaceContainerLow,
          headerBarBackground: scheme.surface,
        ),
      ],
    );
  }

  static ThemeData _material3Dark(
    String? fontFamily,
    Color? seedColor,
    bool isDesktop,
    bool desktopTransparency,
  ) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor ?? _m3Seed,
      brightness: Brightness.dark,
    );

    Color? scaffoldBg;
    if (isDesktop) {
      scaffoldBg = desktopTransparency
          ? scheme.surface.withValues(alpha: 0.7)
          : scheme.surface;
    }

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      fontFamilyFallback: _cjkFallback,
      extensions: [
        AppThemeExtension(
          songCardBackground: scheme.surfaceContainerHighest,
          playerBarBackground: scheme.surfaceContainer,
          sidebarBackground: scheme.surfaceContainerLow,
          headerBarBackground: scheme.surface,
        ),
      ],
    );
  }
}
