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

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../signals/settings_signal.dart';
import '../../theme/app_theme_tokens.dart';

/// The unified glassy card used for every settings group.
///
/// Uses the same `sidebarBackground` token, border, and blur behavior as the
/// desktop sidebar, so settings pages read as the same visual surface.
class SettingsSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SettingsSection({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final blur = settingsSignal.enableGlobalBlur.value;
    return Padding(
      padding: padding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: blur
              ? ImageFilter.blur(sigmaX: 20, sigmaY: 20)
              : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Container(
            decoration: BoxDecoration(
              color: context.tokens.sidebarBackground.withValues(
                alpha: blur ? 0.67 : 1.0,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.accentBorder(0.15)),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A single row inside a [SettingsSection].
///
/// Renders a plain leading icon (no chip background), a 14 pt title, an
/// optional 12 pt subtitle at 54% on-surface alpha, and a default chevron
/// trailing widget. When [selected] is true, the row uses the sidebar's
/// selected-row treatment (accent background pill).
class SettingsTile extends StatelessWidget {
  /// Plain leading icon. Use either an [IconData] or a [FaIconData].
  final Object? icon;
  /// Override the icon color. Defaults to secondary/accent color.
  final Color? iconColor;
  /// Custom leading widget. Takes priority over [icon].
  final Widget? leading;
  final String title;
  /// Static subtitle text. Use [subtitleWidget] for dynamic content.
  final String? subtitle;
  /// Widget-based subtitle (e.g. [FutureBuilder]). Takes priority over [subtitle].
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  /// Whether to reserve space for a leading icon. Defaults to true.
  final bool showLeading;
  /// Override subtitle text color.
  final Color? subtitleColor;
  /// Widget rendered below the text row (e.g. a slider).
  final Widget? bottom;

  const SettingsTile({
    super.key,
    this.icon,
    this.iconColor,
    this.leading,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.showLeading = true,
    this.subtitleColor,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final effectiveIconColor =
        iconColor ?? (selected ? scheme.onSecondary : scheme.secondary);
    final leadingWidget = leading ??
        (icon == null
            ? const SizedBox(width: 24)
            : (icon is FaIconData
                  ? FaIcon(
                      icon! as FaIconData,
                      size: 20,
                      color: effectiveIconColor,
                    )
                  : Icon(
                      icon! as IconData,
                      size: 20,
                      color: effectiveIconColor,
                    )));

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? scheme.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showLeading) SizedBox(width: 24, child: Center(child: leadingWidget)),
              if (showLeading) const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected ? scheme.onSecondary : scheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitleWidget != null) ...[
                      const SizedBox(height: 2),
                      subtitleWidget!,
                    ] else if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: subtitleColor ??
                              (selected ? scheme.onSecondary : scheme.onSurface)
                                  .withValues(alpha: 0.54),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: (selected ? scheme.onSecondary : scheme.onSurface)
                      .withValues(alpha: 0.3),
                ),
              ],
            ],
          ),
          if (bottom != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4),
              child: bottom,
            ),
          ],
        ],
      ),
      ),
    );
  }
}

/// Small section caption used above a [SettingsSection].
class SettingsSectionLabel extends StatelessWidget {
  final String label;
  const SettingsSectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: context.colorScheme.secondary.withValues(alpha: 0.7),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// 1 px hairline used to separate rows inside a [SettingsSection].
class SettingsDivider extends StatelessWidget {
  /// Left indent in logical pixels.
  final double indent;

  const SettingsDivider({super.key, this.indent = 0});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.subtleDivider(0.08),
      indent: indent,
      endIndent: indent,
    );
  }
}
