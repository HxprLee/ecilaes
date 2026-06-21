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
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';
import '../../signals/settings_signal.dart';
import '../../theme/app_theme_tokens.dart';
import '../../widgets/settings/settings_section.dart';
import '../../widgets/sliver_page_header.dart';

class LyricsAppearanceSection extends StatelessWidget {
  const LyricsAppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          const SliverPageHeader(
            title: 'Lyrics Layout',
            maxWidth: 600,
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    const SettingsSectionLabel('Text Alignment'),
                    SettingsSection(
                      child: Watch((context) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alignment',
                                style: TextStyle(
                                  color: context.colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Choose how lyrics text aligns horizontally',
                                style: TextStyle(
                                  color: context.colorScheme.onSurface
                                      .withValues(alpha: 0.54),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: _buildAlignmentButton(context),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 24),

                    const SettingsSectionLabel('Typography'),
                    SettingsSection(
                      child: Column(
                        children: [
                          _buildSliderSetting(
                            context: context,
                            title: 'Active Text Size',
                            valueType: 'active',
                          ),
                          const SettingsDivider(indent: 16),
                          _buildSliderSetting(
                            context: context,
                            title: 'Inactive Text Size',
                            valueType: 'inactive',
                          ),
                          const SettingsDivider(indent: 16),
                          _buildSliderSetting(
                            context: context,
                            title: 'Plain Text Size',
                            valueType: 'plain',
                          ),
                          const SettingsDivider(indent: 16),
                          Watch((context) {
                            return SwitchListTile(
                              title: Text(
                                'Romanized Lyrics',
                                style: TextStyle(
                                  color: context.colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'Show transliterated text beneath original lyrics',
                                style: TextStyle(
                                  color: context.colorScheme.onSurface
                                      .withValues(alpha: 0.54),
                                  fontSize: 12,
                                ),
                              ),
                              value: settingsSignal.showRomanizedLyrics.value,
                              onChanged: (value) =>
                                  settingsSignal.updateShowRomanizedLyrics(value),
                              activeThumbColor:
                                  context.colorScheme.secondary,
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    const SettingsSectionLabel('Lyrics Providers'),
                    SettingsSection(
                      child: Watch((context) {
                        final providers = settingsSignal.lyricsProviders.value;
                        final enabled = settingsSignal.enabledLyricsProviders.value;

                        return ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: providers.length,
                          onReorder: (oldIndex, newIndex) {
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }
                            final items = List<String>.from(providers);
                            final item = items.removeAt(oldIndex);
                            items.insert(newIndex, item);
                            settingsSignal.updateLyricsProviders(items);
                          },
                          itemBuilder: (context, index) {
                            final id = providers[index];
                            final name = _getProviderName(id);
                            final isEnabled = enabled.contains(id);

                            return ListTile(
                              key: ValueKey(id),
                              title: Text(
                                name,
                                style: TextStyle(
                                  color: context.colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                              leading: ReorderableDragStartListener(
                                index: index,
                                child: Icon(
                                  Icons.drag_indicator,
                                  size: 20,
                                  color: context.colorScheme.onSurface
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              trailing: Switch(
                                value: isEnabled,
                                activeThumbColor:
                                    context.colorScheme.secondary,
                                onChanged: (value) => settingsSignal
                                    .toggleLyricsProvider(id),
                              ),
                              contentPadding: const EdgeInsets.only(
                                  left: 8, right: 16),
                            );
                          },
                        );
                      }),
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
        ],
      ),
    );
  }

  Widget _buildSliderSetting({
    required BuildContext context,
    required String title,
    required String valueType,
  }) {
    return Watch((context) {
      final value = valueType == 'active' 
          ? settingsSignal.lyricsActiveFontSize.value 
          : valueType == 'inactive'
              ? settingsSignal.lyricsInactiveFontSize.value
              : settingsSignal.plainLyricsFontSize.value;
          
      return Column(
        children: [
          ListTile(
            title: Text(
              title,
              style: TextStyle(
                color: context.colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              '${value.round()}px',
              style: TextStyle(
                color: context.colorScheme.secondary.withValues(alpha: 0.8),
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
                    color: context.colorScheme.onSurface
                        .withValues(alpha: 0.54),
                    fontSize: 12,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: context.colorScheme.secondary,
                      inactiveTrackColor: context.colorScheme.secondary
                          .withValues(alpha: 0.2),
                      thumbColor: context.colorScheme.secondary,
                      overlayColor: context.colorScheme.secondary
                          .withValues(alpha: 0.1),
                    ),
                    child: Slider(
                      value: value,
                      min: 16.0,
                      max: 48.0,
                      divisions: 32,
                      onChanged: (newValue) {
                         if (valueType == 'active') {
                           settingsSignal.updateLyricsActiveFontSize(newValue);
                         } else if (valueType == 'inactive') {
                           settingsSignal.updateLyricsInactiveFontSize(newValue);
                         } else {
                           settingsSignal.updatePlainLyricsFontSize(newValue);
                         }
                      },
                    ),
                  ),
                ),
                Text(
                  'A',
                  style: TextStyle(
                    color: context.colorScheme.onSurface
                        .withValues(alpha: 0.54),
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildAlignmentButton(BuildContext context) {
    return SegmentedButton<TextAlign>(
      segments: const [
        ButtonSegment(
          value: TextAlign.left,
          icon: Icon(Icons.format_align_left, size: 16),
          label: Text('Left', style: TextStyle(fontSize: 12)),
        ),
        ButtonSegment(
          value: TextAlign.center,
          icon: Icon(Icons.format_align_center, size: 16),
          label: Text('Center', style: TextStyle(fontSize: 12)),
        ),
        ButtonSegment(
          value: TextAlign.right,
          icon: Icon(Icons.format_align_right, size: 16),
          label: Text('Right', style: TextStyle(fontSize: 12)),
        ),
      ],
      selected: <TextAlign>{settingsSignal.lyricsAlignment.value},
      onSelectionChanged: (Set<TextAlign> newSelection) {
        settingsSignal.updateLyricsAlignment(newSelection.first);
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

  String _getProviderName(String id) {
    switch (id) {
      case 'lrclib':
        return 'LrcLib';
      case 'simpmusic':
        return 'SimpMusic';
      case 'better_lyrics':
        return 'BetterLyrics';
      case 'kugou':
        return 'KuGou';
      default:
        return id;
    }
  }
}
