import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';
import '../../signals/settings_signal.dart';
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
                  _sectionLabel('Audio', context),
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
                                'Gapless Playback',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'Seamless transitions between tracks without silence gaps',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withValues(alpha: 0.54),
                                  fontSize: 12,
                                ),
                              ),
                              value: settingsSignal.gaplessPlayback.value,
                              onChanged: (value) {
                                settingsSignal.updateGaplessPlayback(value);
                                audioSignal.audioHandler.setGaplessMode(value);
                              },
                              activeThumbColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                            );
                          }),
                          _divider(context),
                          Watch((context) {
                            return SwitchListTile(
                              title: Text(
                                'Volume Normalization',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'Adjust volume levels for consistent loudness across tracks',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withValues(alpha: 0.54),
                                  fontSize: 12,
                                ),
                              ),
                              value: settingsSignal.audioNormalization.value,
                              onChanged: (value) {
                                settingsSignal.updateAudioNormalization(value);
                                audioSignal.audioHandler.setNormalizationEnabled(value);
                              },
                              activeThumbColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                            );
                          }),
                          Watch((context) {
                            if (!settingsSignal.audioNormalization.value) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              children: [
                                _divider(context),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Target Loudness',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurface,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${settingsSignal.normalizationTargetLufs.value.toStringAsFixed(0)} LUFS',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
                                  child: SliderTheme(
                                    data: SliderThemeData(
                                      activeTrackColor: Theme.of(context).colorScheme.secondary,
                                      thumbColor: Theme.of(context).colorScheme.secondary,
                                      inactiveTrackColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
                                      overlayColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                                    ),
                                    child: Slider(
                                      value: settingsSignal.normalizationTargetLufs.value,
                                      min: -23.0,
                                      max: -6.0,
                                      divisions: 17,
                                      onChanged: (value) {
                                        settingsSignal.updateNormalizationTargetLufs(value);
                                        audioSignal.audioHandler.setNormalizationTargetLufs(value);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Controls section
                  _sectionLabel('Controls & Behavior', context),
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
                                'Swipe down to stop',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'Swipe down on the mini player to stop playback',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withValues(alpha: 0.54),
                                  fontSize: 12,
                                ),
                              ),
                              value: settingsSignal.swipeDownToStop.value,
                              onChanged: (value) =>
                                  settingsSignal.updateSwipeDownToStop(value),
                              activeThumbColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                            );
                          }),
                          if (_isDesktop) ...[
                            _divider(context),
                            Watch((context) {
                              return SwitchListTile(
                                title: Text(
                                  'Background Playback',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  'Minimize to tray instead of closing',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withValues(alpha: 0.54),
                                    fontSize: 12,
                                  ),
                                ),
                                value: settingsSignal.backgroundPlayback.value,
                                onChanged: (value) => settingsSignal
                                    .updateBackgroundPlayback(value),
                                activeThumbColor: Theme.of(
                                  context,
                                ).colorScheme.secondary,
                              );
                            }),
                            _divider(context),
                            Watch((context) {
                              return SwitchListTile(
                                title: Text(
                                  'Single Instance',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  'Only allow one instance of the app to run',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withValues(alpha: 0.54),
                                    fontSize: 12,
                                  ),
                                ),
                                value: settingsSignal.useSingleInstance.value,
                                onChanged: (value) =>
                                    settingsSignal.updateSingleInstance(value),
                                activeThumbColor: Theme.of(
                                  context,
                                ).colorScheme.secondary,
                              );
                            }),
                          ],
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
        ],
      ),
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

  Widget _divider(BuildContext context) => Divider(
    height: 1,
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
    indent: 16,
    endIndent: 16,
  );
}
