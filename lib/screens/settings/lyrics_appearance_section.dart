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
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';
import '../../signals/settings_signal.dart';
import '../../theme/app_theme_tokens.dart';
import '../../widgets/components/settings_section.dart';
import '../../widgets/components/spinner_widget.dart';
import '../../widgets/components/sliver_page_header.dart';

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
                      child: SignalBuilder(builder: (context) {
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
                          SignalBuilder(builder: (context) {
                            return SettingsTile(
                              title: 'Active Text Size',
                              subtitle: '${settingsSignal.lyricsActiveFontSize.value.round()}px',
                              showLeading: false,
                              trailing: SpinnerWidget(
                                value: settingsSignal.lyricsActiveFontSize.value,
                                min: 16.0,
                                max: 48.0,
                                step: 2.0,
                                formatValue: (v) => v.toStringAsFixed(0),
                                parseValue: (s) => double.tryParse(s),
                                onChanged: (v) => settingsSignal.updateLyricsActiveFontSize(v),
                              ),
                            );
                          }),
                          const SettingsDivider(indent: 16),
                          SignalBuilder(builder: (context) {
                            return SettingsTile(
                              title: 'Inactive Text Size',
                              subtitle: '${settingsSignal.lyricsInactiveFontSize.value.round()}px',
                              showLeading: false,
                              trailing: SpinnerWidget(
                                value: settingsSignal.lyricsInactiveFontSize.value,
                                min: 16.0,
                                max: 48.0,
                                step: 2.0,
                                formatValue: (v) => v.toStringAsFixed(0),
                                parseValue: (s) => double.tryParse(s),
                                onChanged: (v) => settingsSignal.updateLyricsInactiveFontSize(v),
                              ),
                            );
                          }),
                          const SettingsDivider(indent: 16),
                          SignalBuilder(builder: (context) {
                            return SettingsTile(
                              title: 'Plain Text Size',
                              subtitle: '${settingsSignal.plainLyricsFontSize.value.round()}px',
                              showLeading: false,
                              trailing: SpinnerWidget(
                                value: settingsSignal.plainLyricsFontSize.value,
                                min: 16.0,
                                max: 48.0,
                                step: 2.0,
                                formatValue: (v) => v.toStringAsFixed(0),
                                parseValue: (s) => double.tryParse(s),
                                onChanged: (v) => settingsSignal.updatePlainLyricsFontSize(v),
                              ),
                            );
                          }),
                          const SettingsDivider(indent: 16),
                          SignalBuilder(builder: (context) {
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
                      child: SignalBuilder(builder: (context) {
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
      case 'better_lyrics':
        return 'BetterLyrics';
      case 'kugou':
        return 'KuGou';
      default:
        return id;
    }
  }
}
