import 'dart:ui';
import 'package:flutter/material.dart';
import '../signals/settings_signal.dart';
import '../theme/app_theme_extensions.dart';

class AppDialog extends StatelessWidget {
  final Widget? titleIcon;
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final double maxWidth;
  final double? maxHeight;
  final EdgeInsets padding;
  final Widget? trailing;

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
                  color: Theme.of(context)
                      .extension<AppThemeExtension>()!
                      .sidebarBackground
                      .withValues(
                        alpha:
                            settingsSignal.enableGlobalBlur.value ? 0.85 : 1.0,
                      ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1),
                  ),
                ),
                padding: padding,
                child: Material(
                  color: Colors.transparent,
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
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
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (trailing != null) ...[
                              const SizedBox(width: 8),
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
