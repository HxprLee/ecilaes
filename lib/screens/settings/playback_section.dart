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
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';
import '../../signals/settings_signal.dart';
import '../../widgets/settings/settings_section.dart';
import '../../widgets/sliver_page_header.dart';


class PlaybackSection extends StatelessWidget {
  const PlaybackSection({super.key});

  bool get _isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          const SliverPageHeader(
            title: 'Playback',
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

                    // Audio section
                    const SettingsSectionLabel('Audio'),
                    SettingsSection(
                      child: Column(
                        children: [
                          Watch((context) {
                            return SettingsTile(
                              title: 'Volume Normalization',
                              subtitle:
                                  'Adjust volume levels for consistent loudness across tracks',
                              showLeading: false,
                              trailing: Switch(
                                value: settingsSignal.audioNormalization.value,
                                onChanged: (value) {
                                  settingsSignal.updateAudioNormalization(value);
                                  audioSignal.audioHandler
                                      .setNormalizationEnabled(value);
                                },
                                activeThumbColor: Theme.of(context).colorScheme.secondary,
                              ),
                            );
                          }),
                          Watch((context) {
                            if (!settingsSignal.audioNormalization.value) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              children: [
                                const SettingsDivider(indent: 16),
                                SettingsTile(
                                  title: 'Target Loudness',
                                  subtitle:
                                      '${settingsSignal.normalizationTargetLufs.value.toStringAsFixed(0)} LUFS',
                                  showLeading: false,
                                  bottom: Padding(
                                    padding: const EdgeInsets.only(
                                        left: 0, right: 20, bottom: 16),
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        activeTrackColor:
                                            Theme.of(context).colorScheme.secondary,
                                        thumbColor:
                                            Theme.of(context).colorScheme.secondary,
                                        inactiveTrackColor: Theme.of(context)
                                            .colorScheme.secondary
                                            .withValues(alpha: 0.2),
                                        overlayColor: Theme.of(context)
                                            .colorScheme.secondary
                                            .withValues(alpha: 0.1),
                                      ),
                                      child: Slider(
                                        value: settingsSignal
                                            .normalizationTargetLufs.value,
                                        min: -23.0,
                                        max: -6.0,
                                        divisions: 17,
                                        onChanged: (value) {
                                          settingsSignal
                                              .updateNormalizationTargetLufs(
                                                  value);
                                          audioSignal.audioHandler
                                              .setNormalizationTargetLufs(
                                                  value);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Controls section
                    const SettingsSectionLabel('Controls & Behavior'),
                    SettingsSection(
                      child: Column(
                        children: [
                          Watch((context) {
                            return SettingsTile(
                              title: 'Swipe down to stop',
                              subtitle:
                                  'Swipe down on the mini player to stop playback',
                              showLeading: false,
                              trailing: Switch(
                                value: settingsSignal.swipeDownToStop.value,
                                onChanged: (value) => settingsSignal
                                    .updateSwipeDownToStop(value),
                                activeThumbColor: Theme.of(context).colorScheme.secondary,
                              ),
                            );
                          }),
                          if (_isDesktop) ...[
                            const SettingsDivider(indent: 16),
                            Watch((context) {
                              return SettingsTile(
                                title: 'Background Playback',
                                subtitle:
                                    'Minimize to tray instead of closing',
                                showLeading: false,
                                trailing: Switch(
                                  value: settingsSignal.backgroundPlayback.value,
                                  onChanged: (value) => settingsSignal
                                      .updateBackgroundPlayback(value),
                                  activeThumbColor:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                              );
                            }),
                            const SettingsDivider(indent: 16),
                            Watch((context) {
                              return SettingsTile(
                                title: 'Single Instance',
                                subtitle:
                                    'Only allow one instance of the app to run',
                                showLeading: false,
                                trailing: Switch(
                                  value: settingsSignal.useSingleInstance.value,
                                  onChanged: (value) => settingsSignal
                                      .updateSingleInstance(value),
                                  activeThumbColor:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Caching section
                    const SettingsSectionLabel('Caching'),
                    SettingsSection(
                      child: Column(
                        children: [
                          Watch((context) {
                            return SettingsTile(
                              title: 'Cache While Playing',
                              subtitle:
                                  'Save YouTube songs to disk for instant replay and offline playback',
                              showLeading: false,
                              trailing: Switch(
                                value: settingsSignal.enableStreamCaching.value,
                                onChanged: (value) {
                                  settingsSignal.updateStreamCaching(value);
                                },
                                activeThumbColor: Theme.of(context).colorScheme.secondary,
                              ),
                            );
                          }),
                          const SettingsDivider(indent: 16),
                          Watch((context) {
                            return SettingsTile(
                              title: 'Pre-cache Next Song',
                              subtitle:
                                  'Download the next song in queue while the current one plays',
                              showLeading: false,
                              trailing: Switch(
                                value: settingsSignal.enablePreCaching.value,
                                onChanged: (value) {
                                  settingsSignal.updatePreCaching(value);
                                },
                                activeThumbColor: Theme.of(context).colorScheme.secondary,
                              ),
                            );
                          }),
                        ],
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
        ],
      ),
    );
  }
}
