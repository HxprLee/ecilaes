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
import '../signals/settings_signal.dart';
import '../theme/app_theme_tokens.dart';

class AppDialog extends StatelessWidget {
  final Widget? titleIcon;
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final double maxWidth;
  final double? maxHeight;
  final EdgeInsets padding;
  final Widget? trailing;
  final double trailingWidth;

  const AppDialog({
    super.key,
    this.titleIcon,
    required this.title,
    required this.content,
    this.actions,
    this.maxWidth = 320,
    this.maxHeight,
    this.padding = const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
    this.trailing,
    this.trailingWidth = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight ?? double.infinity,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: BackdropFilter(
              filter: settingsSignal.enableGlobalBlur.value
                  ? ImageFilter.blur(sigmaX: 20, sigmaY: 20)
                  : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Container(
                decoration: BoxDecoration(
                  color: context.tokens.sidebarBackground.withValues(
                    alpha:
                        settingsSignal.enableGlobalBlur.value ? 0.85 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.accentBorder(0.1),
                  ),
                ),
                padding: padding,
                child: Material(
                  color: Colors.transparent,
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: context.colorScheme.secondary,
                          fontSize: 14,
                        ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              if (titleIcon != null) ...[
                                titleIcon!,
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Text(
                                  title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color:
                                            context.colorScheme.secondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (trailing != null) ...[
                              SizedBox(width: trailingWidth),
                              trailing!,
                            ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (maxHeight != null)
                          Flexible(child: content)
                        else
                          content,
                        if (actions != null && actions!.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: actions!
                                .asMap()
                                .entries
                                .map(
                                  (entry) => Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: entry.key == 0 ? 0 : 12,
                                      ),
                                      child: entry.value,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
