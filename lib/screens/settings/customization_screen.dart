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

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';
import '../../signals/settings_signal.dart';
import '../../theme/app_theme_style.dart';
import '../../theme/app_theme_tokens.dart';
import '../../widgets/settings/settings_section.dart';
import '../../widgets/sliver_page_header.dart';

class CustomizationScreen extends StatelessWidget {
  const CustomizationScreen({super.key});

  bool get _isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          const SliverPageHeader(title: 'Customization', maxWidth: 600),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Display section
                    const SettingsSectionLabel('Display'),
                    SettingsSection(
                      child: Column(
                        children: [
                          if (_isMobile) ...[
                            _buildMobileThemeStyle(context),
                            const SettingsDivider(indent: 16),
                            _buildMobileThemeMode(context),
                          ] else ...[
                            SettingsTile(
                              title: 'Theme Style',
                              subtitle: 'Choose color palette',
                              showLeading: false,
                              trailing: Watch(
                                (context) => _buildThemeStyleButton(context),
                              ),
                            ),
                            const SettingsDivider(indent: 16),
                            SettingsTile(
                              title: 'Theme',
                              subtitle: 'Choose app appearance',
                              showLeading: false,
                              trailing: Watch(
                                (context) => _buildThemeModeButton(context),
                              ),
                            ),
                            const SettingsDivider(indent: 16),
                          ],
                          Watch((context) {
                            final scale = settingsSignal.textScaleFactor.value;
                            return SettingsTile(
                              title: 'Text Scale',
                              subtitle: '${(scale * 100).round()}%',
                              subtitleColor: context.colorScheme.secondary
                                  .withValues(alpha: 0.8),
                              showLeading: false,
                              trailing: _buildTextScaleSpinner(context, scale),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Visual Effects section
                    const SettingsSectionLabel('Visual Effects'),
                    SettingsSection(
                      child: Column(
                        children: [
                          SettingsTile(
                            title: 'Custom Font (Iosevka)',
                            subtitle: 'Use bundled Iosevka Nerd Font',
                            showLeading: false,
                            trailing: Watch(
                              (context) => Switch(
                                value: settingsSignal.useCustomFont.value,
                                onChanged: (value) =>
                                    settingsSignal.updateCustomFont(value),
                                activeThumbColor: context.colorScheme.secondary,
                              ),
                            ),
                          ),
                          if (_isDesktop) ...[
                            const SettingsDivider(indent: 16),
                            SettingsTile(
                              title: 'Custom Window Controls',
                              subtitle: 'Use custom buttons',
                              showLeading: false,
                              trailing: Watch(
                                (context) => Switch(
                                  value: settingsSignal
                                      .useCustomWindowControls
                                      .value,
                                  onChanged: (value) => settingsSignal
                                      .updateCustomWindowControls(value),
                                  activeThumbColor:
                                      context.colorScheme.secondary,
                                ),
                              ),
                            ),
                          ],
                          const SettingsDivider(indent: 16),
                          SettingsTile(
                            title: 'Blur Effect',
                            subtitle: 'Enable backdrop blur globally',
                            showLeading: false,
                            trailing: Watch(
                              (context) => Switch(
                                value: settingsSignal.enableGlobalBlur.value,
                                onChanged: (value) =>
                                    settingsSignal.updateGlobalBlur(value),
                                activeThumbColor: context.colorScheme.secondary,
                              ),
                            ),
                          ),
                          if (_isDesktop) ...[
                            const SettingsDivider(indent: 16),
                            SettingsTile(
                              title: 'Window Transparency',
                              subtitle:
                                  'Translucent background (requires restart)',
                              showLeading: false,
                              trailing: Watch(
                                (context) => Switch(
                                  value: settingsSignal
                                      .enableWindowTransparency
                                      .value,
                                  onChanged: (value) => settingsSignal
                                      .updateWindowTransparency(value),
                                  activeThumbColor:
                                      context.colorScheme.secondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Layout section
                    const SettingsSectionLabel('Layout'),
                    SettingsSection(
                      child: Column(
                        children: [
                          SettingsTile(
                            title: 'Player Layout',
                            subtitle: 'Customize the action buttons row',
                            showLeading: false,
                            onTap: () => context.go(
                              '/settings/customization/player-layout',
                            ),
                          ),
                          const SettingsDivider(indent: 16),
                          SettingsTile(
                            title: 'Context Menu Actions',
                            subtitle: 'Customize the long-press menu actions',
                            showLeading: false,
                            onTap: () => context.go(
                              '/settings/customization/actions-layout',
                            ),
                          ),
                          const SettingsDivider(indent: 16),
                          SettingsTile(
                            title: 'Lyrics View Layout',
                            subtitle: 'Customize lyrics alignment and fonts',
                            showLeading: false,
                            onTap: () => context.go(
                              '/settings/customization/lyrics-layout',
                            ),
                          ),
                          const SettingsDivider(indent: 16),
                          SettingsTile(
                            title: 'Sidebar Items',
                            subtitle:
                                'Choose which library items appear in sidebar',
                            showLeading: false,
                            onTap: () => context.go(
                              '/settings/customization/sidebar-layout',
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_isDesktop) ...[
                      const SizedBox(height: 32),
                      const SettingsSectionLabel('Discord Rich Presence'),
                      SettingsSection(
                        child: SettingsTile(
                          title: 'Discord Rich Presence',
                          subtitle: 'Configure Discord status buttons',
                          showLeading: false,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Watch(
                                (context) => Switch(
                                  value: settingsSignal.enableDiscordRpc.value,
                                  onChanged: (value) =>
                                      settingsSignal.updateDiscordRpc(value),
                                  activeThumbColor:
                                      context.colorScheme.secondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, size: 20),
                            ],
                          ),
                          onTap: () => context.go(
                            '/settings/customization/discord-presence',
                          ),
                        ),
                      ),
                    ],

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
        ],
      ),
    );
  }

  Widget _buildMobileThemeStyle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Theme Style',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose color palette',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _buildThemeStyleButton(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileThemeMode(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Theme',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose app appearance',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _buildThemeModeButton(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTextScaleSpinner(BuildContext context, double scale) {
    final accentColor = context.colorScheme.secondary;
    final onSurface = context.colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: context.tokens.sidebarBackground,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: onSurface.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AdwSpinnerButton(
            icon: Icons.remove,
            onTap: scale > 0.5
                ? () => settingsSignal.updateTextScale(
                    (scale - 0.05).clamp(0.5, 2.0),
                  )
                : null,
            accentColor: accentColor,
            isLeft: true,
          ),
          Container(
            width: 1,
            height: 32,
            color: onSurface.withValues(alpha: 0.12),
          ),
          _TextScaleTextField(
            scale: scale,
            accentColor: accentColor,
            onChanged: (value) {
              final parsed = double.tryParse(value);
              if (parsed != null) {
                settingsSignal.updateTextScale((parsed / 100).clamp(0.5, 2.0));
              }
            },
          ),
          Container(
            width: 1,
            height: 32,
            color: onSurface.withValues(alpha: 0.12),
          ),
          _AdwSpinnerButton(
            icon: Icons.add,
            onTap: scale < 2.0
                ? () => settingsSignal.updateTextScale(
                    (scale + 0.05).clamp(0.5, 2.0),
                  )
                : null,
            accentColor: accentColor,
          ),
        ],
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
      selected: {settingsSignal.themeStyle.value},
      onSelectionChanged: (set) => settingsSignal.updateThemeStyle(set.first),
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
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
      selected: {settingsSignal.themeMode.value},
      onSelectionChanged: (set) => settingsSignal.updateThemeMode(set.first),
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      showSelectedIcon: false,
    );
  }
}

class _AdwSpinnerButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color accentColor;
  final bool isLeft;

  const _AdwSpinnerButton({
    required this.icon,
    required this.onTap,
    required this.accentColor,
    this.isLeft = false,
  });

  @override
  State<_AdwSpinnerButton> createState() => _AdwSpinnerButtonState();
}

class _AdwSpinnerButtonState extends State<_AdwSpinnerButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    Color bgColor = Colors.transparent;
    if (enabled) {
      if (_isPressed) {
        bgColor = widget.accentColor.withValues(alpha: 0.18);
      } else if (_isHovered) {
        bgColor = widget.accentColor.withValues(alpha: 0.10);
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 38,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(widget.isLeft ? 32 : 0),
              bottomLeft: Radius.circular(widget.isLeft ? 32 : 0),
              topRight: Radius.circular(widget.isLeft ? 0 : 32),
              bottomRight: Radius.circular(widget.isLeft ? 0 : 32),
            ),
          ),
          child: Center(
            child: Icon(
              widget.icon,
              size: 16,
              color: enabled
                  ? widget.accentColor
                  : widget.accentColor.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextScaleTextField extends StatefulWidget {
  final double scale;
  final Color accentColor;
  final ValueChanged<String> onChanged;

  const _TextScaleTextField({
    required this.scale,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  State<_TextScaleTextField> createState() => _TextScaleTextFieldState();
}

class _TextScaleTextFieldState extends State<_TextScaleTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: '${(widget.scale * 100).round()}',
    );
  }

  @override
  void didUpdateWidget(_TextScaleTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newValue = '${(widget.scale * 100).round()}';
    if (_controller.text != newValue &&
        int.tryParse(_controller.text) != (widget.scale * 100).round()) {
      _controller.text = newValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 32,
      child: Center(
        child: TextField(
          controller: _controller,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.colorScheme.onSurface,
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
          ),
          keyboardType: TextInputType.number,
          onSubmitted: widget.onChanged,
          onChanged: (value) {
            final parsed = int.tryParse(value);
            if (parsed != null) {
              widget.onChanged(value);
            }
          },
        ),
      ),
    );
  }
}
