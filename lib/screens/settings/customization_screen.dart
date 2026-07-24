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

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';
import '../../signals/settings_signal.dart';
import '../../theme/app_theme_tokens.dart';
import '../../theme/app_theme_style.dart';
import '../../utils/navigation.dart';
import '../../router/routes.dart';
import '../../widgets/components/settings_section.dart';
import '../../widgets/components/spinner_widget.dart';
import '../../widgets/components/sliver_page_header.dart';

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
                              trailing: SignalBuilder(builder: (context) => _buildThemeStyleButton(context),
                              ),
                            ),
                            const SettingsDivider(indent: 16),
                            SettingsTile(
                              title: 'Theme',
                              subtitle: 'Choose app appearance',
                              showLeading: false,
                              trailing: SignalBuilder(builder: (context) => _buildThemeModeButton(context),
                              ),
                            ),
                            const SettingsDivider(indent: 16),
                          ],
                          SignalBuilder(builder: (context) {
                            final scale = settingsSignal.textScaleFactor.value;
                            return SettingsTile(
                              title: 'Text Scale',
                              subtitle: '${(scale * 100).round()}%',
                              subtitleColor: context.colorScheme.secondary
                                  .withValues(alpha: 0.8),
                              showLeading: false,
                              trailing: SpinnerWidget(
                                value: scale,
                                min: 0.5,
                                max: 2.0,
                                step: 0.05,
                                formatValue: (v) => '${(v * 100).round()}',
                                parseValue: (s) {
                                  final p = int.tryParse(s);
                                  return p != null ? p / 100.0 : null;
                                },
                                onChanged: (v) =>
                                    settingsSignal.updateTextScale(v),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Visual Effects section
                    const SettingsSectionLabel('Visuals'),
                    SettingsSection(
                      child: Column(
                        children: [
                          SettingsTile(
                            title: 'Custom Font (Iosevka)',
                            subtitle: 'Use bundled Iosevka Nerd Font',
                            showLeading: false,
                            trailing: SignalBuilder(builder: (context) => Switch(
                                value: settingsSignal.useCustomFont.value,
                                onChanged: (value) =>
                                    settingsSignal.updateCustomFont(value),
                                activeThumbColor: context.colorScheme.secondary,
                              ),
                            ),
                          ),
                          const SettingsDivider(indent: 16),
                          SettingsTile(
                            title: 'Blur Effect',
                            subtitle: 'Enable backdrop blur globally',
                            showLeading: false,
                            trailing: SignalBuilder(builder: (context) => Switch(
                                value: settingsSignal.enableGlobalBlur.value,
                                onChanged: (value) =>
                                    settingsSignal.updateGlobalBlur(value),
                                activeThumbColor: context.colorScheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isDesktop) ...[
                      const SizedBox(height: 32),
                      const SettingsSectionLabel('Window'),
                      SettingsSection(
                        child: Column(
                          children: [
                            SettingsTile(
                              title: 'Custom Window Controls',
                              subtitle: 'Use custom buttons',
                              showLeading: false,
                              trailing: SignalBuilder(builder: (context) => Switch(
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
                            const SettingsDivider(indent: 16),
                            SettingsTile(
                              title: 'Window Transparency',
                              subtitle:
                                  'Translucent background (requires restart)',
                              showLeading: false,
                              trailing: SignalBuilder(builder: (context) => Switch(
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
                        ),
                      ),
                    ],
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
                            onTap: () => navigatePush(
                              context,
                              AppRoutes.settingsCustomizationPlayerLayout,
                            ),
                          ),
                          const SettingsDivider(indent: 16),
                          SettingsTile(
                            title: 'Context Menu Actions',
                            subtitle: 'Customize the long-press menu actions',
                            showLeading: false,
                            onTap: () => navigatePush(
                              context,
                              AppRoutes.settingsCustomizationActionsLayout,
                            ),
                          ),
                          const SettingsDivider(indent: 16),
                          SettingsTile(
                            title: 'Lyrics View Layout',
                            subtitle: 'Customize lyrics alignment and fonts',
                            showLeading: false,
                            onTap: () => navigatePush(
                              context,
                              AppRoutes.settingsCustomizationLyricsLayout,
                            ),
                          ),
                          const SettingsDivider(indent: 16),
                          SettingsTile(
                            title: 'Sidebar Items',
                            subtitle:
                                'Choose which library items appear in sidebar',
                            showLeading: false,
                            onTap: () => navigatePush(
                              context,
                              AppRoutes.settingsCustomizationSidebarLayout,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    SignalBuilder(builder: (context) =>
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
            child: SignalBuilder(builder: (context) => _buildThemeStyleButton(context)),
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
            child: SignalBuilder(builder: (context) => _buildThemeModeButton(context)),
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
