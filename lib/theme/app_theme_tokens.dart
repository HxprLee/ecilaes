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

/// Ergonomic access to the app's theme tokens from any [BuildContext].
///
/// Widgets should read theme colors through this extension instead of
/// reaching for `Theme.of(context).extension<AppThemeExtension>()!` chains
/// or hand-rolling `colorScheme.secondary.withValues(alpha: ...)` blocks.
extension AppThemeTokens on BuildContext {
  /// The semantic tokens for the current theme.
  AppThemeExtension get tokens =>
      Theme.of(this).extension<AppThemeExtension>()!;

  /// The active [ColorScheme].
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// The accent color with the given [opacity] applied.
  ///
  /// Replaces the very common
  /// `Theme.of(context).colorScheme.secondary.withValues(alpha: x)` pattern.
  Color accentOf([double opacity = 1.0]) =>
      colorScheme.secondary.withValues(alpha: opacity);

  /// The on-surface color with the given [opacity] applied.
  Color onSurfaceOf([double opacity = 1.0]) =>
      colorScheme.onSurface.withValues(alpha: opacity);

  /// Tinted accent border color (e.g. for card outlines).
  Color accentBorder([double opacity = 0.15]) => accentOf(opacity);

  /// Tinted on-surface divider color.
  Color subtleDivider([double opacity = 0.05]) => onSurfaceOf(opacity);

  /// Tinted on-surface icon color for muted/disabled states.
  Color mutedIcon([double opacity = 0.3]) => onSurfaceOf(opacity);

  /// Whether the current theme is a Material 3 / dynamic-color scheme.
  bool get isMaterial3 => tokens.scheme == AppColorScheme.material3;
}
