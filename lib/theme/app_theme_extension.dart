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

/// Identifies which theme style produced this extension's tokens.
enum AppColorScheme { signature, material3 }

/// Semantic color tokens for the app, layered on top of [ColorScheme].
///
/// Widgets should read these via the `tokens` getter on [BuildContext]
/// (see [app_theme_tokens.dart]) instead of branching on [scheme] at the
/// call site. All values are pre-resolved at build time so widgets do
/// not need to know whether the active style is Signature or M3.
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  /// Which style produced this token set.
  final AppColorScheme scheme;

  /// Background for "card" surfaces (song cards, settings cards, etc.).
  final Color cardBackground;

  /// Background for player bars, expanded player chrome, and other
  /// surfaces that sit between cards and the page surface.
  final Color playerBarBackground;

  /// Background for sidebars, sheets, drawers, flyouts, and other
  /// "sunken" surfaces.
  final Color sidebarBackground;

  /// Background for top-of-page header bars.
  final Color headerBarBackground;

  /// Color used by the missing-artwork placeholder icon.
  final Color placeholderIcon;

  /// Background for circular icon buttons (window controls, transport
  /// buttons in headers).
  final Color circleIconBackground;

  const AppThemeExtension({
    required this.scheme,
    required this.cardBackground,
    required this.playerBarBackground,
    required this.sidebarBackground,
    required this.headerBarBackground,
    required this.placeholderIcon,
    required this.circleIconBackground,
  });

  @override
  AppThemeExtension copyWith({
    AppColorScheme? scheme,
    Color? cardBackground,
    Color? playerBarBackground,
    Color? sidebarBackground,
    Color? headerBarBackground,
    Color? placeholderIcon,
    Color? circleIconBackground,
  }) {
    return AppThemeExtension(
      scheme: scheme ?? this.scheme,
      cardBackground: cardBackground ?? this.cardBackground,
      playerBarBackground: playerBarBackground ?? this.playerBarBackground,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      headerBarBackground: headerBarBackground ?? this.headerBarBackground,
      placeholderIcon: placeholderIcon ?? this.placeholderIcon,
      circleIconBackground: circleIconBackground ?? this.circleIconBackground,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      scheme: t < 0.5 ? scheme : other.scheme,
      cardBackground:
          Color.lerp(cardBackground, other.cardBackground, t)!,
      playerBarBackground:
          Color.lerp(playerBarBackground, other.playerBarBackground, t)!,
      sidebarBackground:
          Color.lerp(sidebarBackground, other.sidebarBackground, t)!,
      headerBarBackground:
          Color.lerp(headerBarBackground, other.headerBarBackground, t)!,
      placeholderIcon:
          Color.lerp(placeholderIcon, other.placeholderIcon, t)!,
      circleIconBackground:
          Color.lerp(circleIconBackground, other.circleIconBackground, t)!,
    );
  }
}
