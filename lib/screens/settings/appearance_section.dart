import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';
import '../../signals/settings_signal.dart';
import '../../theme/app_theme_style.dart';
import '../../widgets/subpage_header.dart';

class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  bool get _isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Widget build(BuildContext context) {
    final topPadding = _isDesktop
        ? 50.0
        : 64.0 + MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: EdgeInsets.only(top: 24.0 + topPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const SubpageHeader(title: 'Appearance'),
                  const SizedBox(height: 24),

                  // Text Scale section
                  _sectionLabel('Display', context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.8),
                      surfaceTintColor: Theme.of(context).colorScheme.secondary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.1),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Watch((context) {
                        final scale = settingsSignal.textScaleFactor.value;
                        return Column(
                          children: [
                            // Theme Style selector
                            if (_isMobile)
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Theme Style',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Choose color palette',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.54),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: _buildThemeStyleButton(context),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListTile(
                                title: Text(
                                  'Theme Style',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  'Choose color palette',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.54),
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: _buildThemeStyleButton(context),
                              ),
                            Divider(
                              height: 1,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.05),
                              indent: 16,
                              endIndent: 16,
                            ),
                            // Theme mode selector
                            if (_isMobile)
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Theme',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Choose app appearance',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.54),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: _buildThemeModeButton(context),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListTile(
                                title: Text(
                                  'Theme',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  'Choose app appearance',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.54),
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: _buildThemeModeButton(context),
                              ),
                            Divider(
                              height: 1,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.05),
                              indent: 16,
                              endIndent: 16,
                            ),
                            ListTile(
                              title: Text(
                                'Text Scale',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                '${(scale * 100).round()}%',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.secondary
                                      .withValues(alpha: 0.8),
                                  fontSize: 12,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 20,
                                right: 20,
                                bottom: 16,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'A',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.54),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        activeTrackColor: const Color(
                                          0xFFFCE7AC,
                                        ),
                                        inactiveTrackColor: const Color(
                                          0xFFFCE7AC,
                                        ).withValues(alpha: 0.2),
                                        thumbColor: const Color(0xFFFCE7AC),
                                        overlayColor: const Color(
                                          0xFFFCE7AC,
                                        ).withValues(alpha: 0.1),
                                      ),
                                      child: Slider(
                                        value: scale,
                                        min: 0.5,
                                        max: 2.0,
                                        divisions: 15,
                                        onChanged: (value) => settingsSignal
                                            .updateTextScale(value),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'A',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.54),
                                      fontSize: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Preview
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: 16,
                              ),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Preview',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.4),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'The quick brown fox jumps over the lazy dog',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Interface section
                  _sectionLabel('Interface', context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.8),
                      surfaceTintColor: Theme.of(context).colorScheme.secondary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.1),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Watch((context) {
                            return SwitchListTile(
                              title: Text(
                                'Custom Font (Iosevka)',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'Use bundled Iosevka Nerd Font',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.54),
                                  fontSize: 12,
                                ),
                              ),
                              value: settingsSignal.useCustomFont.value,
                              onChanged: (value) =>
                                  settingsSignal.updateCustomFont(value),
                              activeThumbColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                            );
                          }),
                          if (_isDesktop) ...[
                            Divider(
                              height: 1,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.05),
                              indent: 16,
                              endIndent: 16,
                            ),
                            Watch((context) {
                              return SwitchListTile(
                                title: Text(
                                  'Custom Window Controls',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  'Use custom close, minimize, maximize buttons',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.54),
                                    fontSize: 12,
                                  ),
                                ),
                                value: settingsSignal
                                    .useCustomWindowControls
                                    .value,
                                onChanged: (value) => settingsSignal
                                    .updateCustomWindowControls(value),
                                activeThumbColor: Theme.of(
                                  context,
                                ).colorScheme.secondary,
                              );
                            }),
                          ],
                          // Global Blur toggle (always visible)
                          Divider(
                            height: 1,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.05),
                            indent: 16,
                            endIndent: 16,
                          ),
                          Watch((context) {
                            return SwitchListTile(
                              title: Text(
                                'Blur Effect',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'Enable backdrop blur on sidebars, navbars, and player',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.54),
                                  fontSize: 12,
                                ),
                              ),
                              value: settingsSignal.enableGlobalBlur.value,
                              onChanged: (value) =>
                                  settingsSignal.updateGlobalBlur(value),
                              activeThumbColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                            );
                          }),
                          // Window Transparency toggle (desktop only)
                          if (_isDesktop) ...[
                            Divider(
                              height: 1,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.05),
                              indent: 16,
                              endIndent: 16,
                            ),
                            Watch((context) {
                              return SwitchListTile(
                                title: Text(
                                  'Window Transparency',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  'Translucent window background (requires restart)',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.54),
                                    fontSize: 12,
                                  ),
                                ),
                                value: settingsSignal
                                    .enableWindowTransparency
                                    .value,
                                onChanged: (value) => settingsSignal
                                    .updateWindowTransparency(value),
                                activeThumbColor: Theme.of(
                                  context,
                                ).colorScheme.secondary,
                              );
                            }),
                          ],
                          Divider(
                            height: 1,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.05),
                            indent: 16,
                            endIndent: 16,
                          ),
                          ListTile(
                            title: Text(
                              'Player Bar Layout',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Customize buttons in the player bar',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.54),
                                fontSize: 12,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.3),
                            ),
                            onTap: () {
                              context.go('/settings/appearance/player-bar-layout');
                            },
                          ),
                          Divider(
                            height: 1,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.05),
                            indent: 16,
                            endIndent: 16,
                          ),
                          ListTile(
                            title: Text(
                              'Actions Sheet Layout',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Customize the more options menu',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.54),
                                fontSize: 12,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.3),
                            ),
                            onTap: () {
                              context.go('/settings/appearance/actions-layout');
                            },
                          ),
                          Divider(
                            height: 1,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.05),
                            indent: 16,
                            endIndent: 16,
                          ),
                          ListTile(
                            title: Text(
                              'Lyrics View Layout',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Customize lyrics alignment and font sizes',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.54),
                                fontSize: 12,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.3),
                            ),
                            onTap: () {
                              context.go('/settings/appearance/lyrics-layout');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Watch(
                    (context) =>
                        SizedBox(height: audioSignal.reservedHeight.value),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeStyleButton(BuildContext context) {
    return SegmentedButton<AppThemeStyle>(
      segments: const [
        ButtonSegment(
          value: AppThemeStyle.signature,
          icon: Icon(Icons.palette, size: 16),
          label: Text('eclipx', style: TextStyle(fontSize: 12)),
        ),
        ButtonSegment(
          value: AppThemeStyle.material3,
          icon: Icon(Icons.auto_awesome, size: 16),
          label: Text('Material', style: TextStyle(fontSize: 12)),
        ),
      ],
      selected: <AppThemeStyle>{settingsSignal.themeStyle.value},
      onSelectionChanged: (Set<AppThemeStyle> newSelection) {
        settingsSignal.updateThemeStyle(newSelection.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
      showSelectedIcon: false,
    );
  }

  Widget _buildThemeModeButton(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto, size: 16),
          label: Text('System', style: TextStyle(fontSize: 12)),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode, size: 16),
          label: Text('Light', style: TextStyle(fontSize: 12)),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode, size: 16),
          label: Text('Dark', style: TextStyle(fontSize: 12)),
        ),
      ],
      selected: <ThemeMode>{settingsSignal.themeMode.value},
      onSelectionChanged: (Set<ThemeMode> newSelection) {
        settingsSignal.updateThemeMode(newSelection.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
      showSelectedIcon: false,
    );
  }

  Widget _sectionLabel(String label, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
