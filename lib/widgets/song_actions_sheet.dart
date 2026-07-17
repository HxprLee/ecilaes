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
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/song.dart';
import '../signals/settings_signal.dart';
import '../signals/audio_signal.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'playlist_dialogs.dart';
import 'components/flyout_sheet.dart';
import 'song_info_dialog.dart';
import 'edit_metadata_dialog.dart';
import 'player/queue_view.dart';
import 'components/app_dialog.dart';
import '../services/YoutubeDatasource.dart';

void showSongMoreActionsSheet({
  required BuildContext context,
  required Song song,
  File? albumArt,
  String? playlistId,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    isScrollControlled: true,
    useRootNavigator: true,
    sheetAnimationStyle: AnimationStyle(
      curve: const Cubic(0.68, 0.01, 0.55, 0.99),
      duration: const Duration(milliseconds: 500),
    ),
    builder: (context) {
      return FlyoutSheet(
        maxWidth: 600,
        showHandle: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Watch((context) {
            final quickActions = settingsSignal.actionsSheetQuickActions.value;
            final listActions = settingsSignal.actionsSheetListActions.value;
            final showLabels = settingsSignal.actionsSheetShowLabels.value;
            final artDir = audioSignal.albumArtDir.value;

            final isYoutube = song.path.startsWith('yt:');
            final ytThumbnailUrl = isYoutube
                ? youtubeDatasource.getSongArtworkUrl(song)
                : null;

            File? effectiveArt = albumArt;
            if (effectiveArt == null &&
                song.hasAlbumArt &&
                artDir != null &&
                !isYoutube) {
              final artPath = '$artDir/${song.path.hashCode.abs()}.jpg';
              final file = File(artPath);
              if (file.existsSync()) {
                effectiveArt = file;
              }
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Song Header & Quick Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              image: isYoutube && song.hasAlbumArt
                                  ? DecorationImage(
                                      image: NetworkImage(ytThumbnailUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : effectiveArt != null
                                  ? DecorationImage(
                                      image: FileImage(effectiveArt),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            child: effectiveArt == null && !isYoutube
                                ? Icon(
                                    Icons.music_note,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.54),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  song.title,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  song.artist,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .withValues(alpha: 0.7),
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (quickActions.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: quickActions.map((id) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: _buildQuickAction(
                                  context: context,
                                  song: song,
                                  actionId: id,
                                  showLabel: showLabels,
                                  playlistId: playlistId,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                Divider(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.2),
                  height: 36,
                ),

                // List Actions - Wrapped in flexible or scrollable if needed
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...listActions.map(
                          (id) => _buildSheetAction(
                            context: context,
                            song: song,
                            actionId: id,
                            playlistId: playlistId,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          }),
        ),
      );
    },
  );
}

Widget _buildQuickAction({
  required BuildContext context,
  required Song song,
  required String actionId,
  required bool showLabel,
  String? playlistId,
}) {
  final info = _getActionInfo(actionId);
  if (info == null) return const SizedBox();

  final isSleepTimer = actionId == 'sleep_timer';
  final isSpeed = actionId == 'speed';
  final isYoutube = song.path.startsWith('yt:');
  if (actionId == 'start_radio' && !isYoutube) return const SizedBox();

  return Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: InkWell(
      onTap: () {
        if (info.closeOnTap) Navigator.pop(context);
        info.onTap(context, song, playlistId);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isSleepTimer
                ? _SleepTimerQuickAction(iconSize: 24)
                : isSpeed
                ? const _SpeedQuickAction(iconSize: 24)
                : Icon(
                    info.icon,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 24,
                  ),
            if (showLabel) ...[
              const SizedBox(height: 4),
              isSleepTimer
                  ? _SleepTimerLabel()
                  : Text(
                      info.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ],
          ],
        ),
      ),
    ),
  );
}

Widget _buildSheetAction({
  required BuildContext context,
  required Song song,
  required String actionId,
  String? playlistId,
}) {
  final info = _getActionInfo(actionId);
  if (info == null) return const SizedBox();

  // Special case for remove from playlist item which only shows if playlistId is provided
  if (actionId == 'remove_from_playlist' &&
      (playlistId == null || playlistId == 'favorites')) {
    return const SizedBox();
  }

  final isYoutube = song.path.startsWith('yt:');
  if (actionId == 'start_radio' && !isYoutube) return const SizedBox();

  if (actionId == 'sleep_timer') {
    return _SleepTimerSheetItem();
  }

  return _buildSheetItem(
    context: context,
    icon: info.icon,
    label: info.label,
    onTap: () => info.onTap(context, song, playlistId),
    closeOnTap: info.closeOnTap,
  );
}

class ActionInfo {
  final IconData icon;
  final String label;
  final Function(BuildContext, Song, String?) onTap;
  final bool closeOnTap;

  ActionInfo({
    required this.icon,
    required this.label,
    required this.onTap,
    this.closeOnTap = true,
  });
}

ActionInfo? _getActionInfo(String id) {
  switch (id) {
    case 'add_to_playlist':
      return ActionInfo(
        icon: Icons.playlist_add,
        label: 'Add to playlist',
        onTap: (context, song, _) =>
            PlaylistPickerDialog.show(context, song: song),
        closeOnTap: false,
      );
    case 'play_next':
      return ActionInfo(
        icon: Icons.playlist_play,
        label: 'Play next',
        onTap: (context, song, _) => audioSignal.playNext(song),
      );
    case 'add_to_queue':
      return ActionInfo(
        icon: Icons.queue_music,
        label: 'Add to queue',
        onTap: (context, song, _) => audioSignal.addToQueue(song),
      );
    case 'remove_from_playlist':
      return ActionInfo(
        icon: Icons.playlist_remove,
        label: 'Remove from playlist',
        onTap: (context, song, playlistId) {
          if (playlistId != null) {
            audioSignal.removeSongFromPlaylist(playlistId, song.path);
          }
        },
      );
    case 'go_to_album':
      return ActionInfo(
        icon: Icons.album_outlined,
        label: 'Go to album',
        onTap: (context, song, _) {},
      );
    case 'go_to_artist':
      return ActionInfo(
        icon: Icons.person_outline,
        label: 'Go to artist',
        onTap: (context, song, _) {},
      );
    case 'sleep_timer':
      return ActionInfo(
        icon: Icons.timer_outlined,
        label: 'Sleep timer',
        onTap: (context, song, _) => showSleepTimerDialog(context),
        closeOnTap: false,
      );
    case 'speed':
      return ActionInfo(
        icon: Icons.speed,
        label: 'Playback speed',
        onTap: (context, song, _) => showPlaybackSpeedDialog(context),
        closeOnTap: false,
      );
    case 'info':
      return ActionInfo(
        icon: Icons.info_outline,
        label: 'Song info',
        onTap: (context, song, _) => showSongInfoDialog(context, song),
      );
    case 'edit_metadata':
      return ActionInfo(
        icon: Icons.edit_outlined,
        label: 'Edit info',
        onTap: (context, song, _) {
          showDialog(
            context: context,
            builder: (context) => EditMetadataDialog(song: song),
          );
        },
      );
    case 'shuffle':
      return ActionInfo(
        icon: Icons.shuffle,
        label: 'Shuffle mode',
        onTap: (context, song, _) => audioSignal.toggleShuffle(),
      );
    case 'repeat':
      return ActionInfo(
        icon: Icons.repeat,
        label: 'Repeat mode',
        onTap: (context, song, _) => audioSignal.toggleRepeat(),
      );
    case 'lyrics':
      return ActionInfo(
        icon: Icons.music_note,
        label: 'Lyrics',
        onTap: (context, song, _) {
          audioSignal.showLyrics.value = !audioSignal.showLyrics.value;
        },
      );
    case 'queue':
      return ActionInfo(
        icon: Icons.format_list_bulleted,
        label: 'Queue',
        onTap: (context, song, _) => showQueueSheet(context),
      );
    case 'share':
      return ActionInfo(
        icon: Icons.share_outlined,
        label: 'Share',
        onTap: (context, song, _) {},
      );
    case 'start_radio':
      return ActionInfo(
        icon: Icons.podcasts,
        label: 'Start radio',
        onTap: (context, song, _) => audioSignal.startRadio(song),
      );
    default:
      return null;
  }
}

Widget _buildSheetItem({
  required BuildContext context,
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  bool closeOnTap = true,
}) {
  return Material(
    color: Colors.transparent,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 28),
      leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
      title: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.9),
          fontSize: 14,
        ),
      ),
      onTap: () {
        if (closeOnTap) Navigator.pop(context);
        onTap();
      },
    ),
  );
}

void showSleepTimerDialog(BuildContext context) {
  int selectedHours = 0;
  int selectedMinutes = 30;
  int selectedSeconds = 0;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AppDialog(
            titleIcon: Icon(
              Icons.timer_outlined,
              color: Theme.of(context).colorScheme.secondary,
              size: 24,
            ),
            title: 'Sleep timer',
            trailing: Watch((context) {
              final remaining = audioSignal.sleepTimerRemaining.value;
              if (remaining == null) return const SizedBox.shrink();
              return Text(
                _formatDuration(remaining),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w400,
                ),
              );
            }),
            maxWidth: 360,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Scroll Wheels
                SizedBox(
                  height: 150,
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 32),
                          Expanded(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 120,
                                  child: Row(
                                    children: [
                                      _TimeCrownPicker(
                                        maxValue: 23,
                                        initialValue: selectedHours,
                                        label: 'H',
                                        onChanged: (v) => setDialogState(
                                          () => selectedHours = v,
                                        ),
                                      ),
                                      _TimeCrownPicker(
                                        maxValue: 59,
                                        initialValue: selectedMinutes,
                                        label: 'M',
                                        onChanged: (v) => setDialogState(
                                          () => selectedMinutes = v,
                                        ),
                                      ),
                                      _TimeCrownPicker(
                                        maxValue: 59,
                                        initialValue: selectedSeconds,
                                        label: 'S',
                                        onChanged: (v) => setDialogState(
                                          () => selectedSeconds = v,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _CrownLabel(label: 'H'),
                                    _CrownLabel(label: 'M'),
                                    _CrownLabel(label: 'S'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),
                        ],
                      ),
                      // Left arrow: points inward toward the wheel center
                      Align(
                        alignment: const Alignment(-1, -0.3),
                        child: Icon(
                          Icons.chevron_right,
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.35),
                          size: 26,
                        ),
                      ),
                      // Right arrow: points inward toward the wheel center
                      Align(
                        alignment: const Alignment(1, -0.3),
                        child: Transform.rotate(
                          angle: 3.14159,
                          child: Icon(
                            Icons.chevron_right,
                            color: Theme.of(
                              context,
                            ).colorScheme.secondary.withValues(alpha: 0.35),
                            size: 26,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Preset Chips
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Presets',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.start,
                    children: [
                      _buildPresetChip(context, 'End of song', () {
                        final total = audioSignal.duration.value;
                        final pos = audioSignal.position.value;
                        return total - pos;
                      }()),
                      _buildPresetChip(
                        context,
                        '15m',
                        const Duration(minutes: 15),
                      ),
                      _buildPresetChip(
                        context,
                        '30m',
                        const Duration(minutes: 30),
                      ),
                      _buildPresetChip(
                        context,
                        '45m',
                        const Duration(minutes: 45),
                      ),
                      _buildPresetChip(
                        context,
                        '60m',
                        const Duration(minutes: 60),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed: () {
                  audioSignal.setSleepTimer(null);
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.2),
                  ),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'Off',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () {
                  audioSignal.setSleepTimer(
                    Duration(
                      hours: selectedHours,
                      minutes: selectedMinutes,
                      seconds: selectedSeconds,
                    ),
                  );
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.8),
                  foregroundColor: Theme.of(context).colorScheme.surface,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Start timer'),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildPresetChip(
  BuildContext context,
  String label,
  Duration? duration,
) {
  return ActionChip(
    label: Text(label),
    onPressed: () {
      audioSignal.setSleepTimer(duration);
      Navigator.pop(context);
    },
    labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.secondary,
      fontSize: 12,
    ),
    backgroundColor: Theme.of(
      context,
    ).colorScheme.secondary.withValues(alpha: 0.08),
    side: BorderSide.none,
    shape: const StadiumBorder(),
    visualDensity: VisualDensity.compact,
  );
}

String _formatDuration(Duration? d) {
  if (d == null) return '';
  if (d.inHours > 0) {
    return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
  return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

void showPlaybackSpeedDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return AppDialog(
        titleIcon: FaIcon(
          FontAwesomeIcons.gaugeHigh,
          color: Theme.of(context).colorScheme.secondary,
          size: 20,
        ),
        title: 'Playback',
        maxWidth: 360,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Speed slider
            _SliderRow(
              label: 'Speed',
              signal: settingsSignal.playbackSpeed,
              min: 0.25,
              max: 2.0,
              divisions: 7,
              onChanged: settingsSignal.updatePlaybackSpeed,
            ),
            const SizedBox(height: 4),
            // Pitch slider
            _SliderRow(
              label: 'Pitch',
              signal: settingsSignal.playbackPitch,
              min: 0.25,
              max: 2.0,
              divisions: 7,
              onChanged: settingsSignal.updatePlaybackPitch,
              lockedSignal: settingsSignal.syncPitchWithSpeed,
            ),
            const SizedBox(height: 8),
            // Sync pitch with speed
            _SyncCheckboxRow(
              value: settingsSignal.syncPitchWithSpeed,
              onChanged: (v) => settingsSignal.updateSyncPitchWithSpeed(v),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              settingsSignal.updatePlaybackSpeed(1.0);
              settingsSignal.updatePlaybackPitch(1.0);
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.2),
              ),
              shape: const StadiumBorder(),
            ),
            child: Text(
              'Reset',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.8),
              foregroundColor: Theme.of(context).colorScheme.surface,
              shape: const StadiumBorder(),
            ),
            child: const Text('Done'),
          ),
        ],
      );
    },
  );
}

class _SliderRow extends StatelessWidget {
  final String label;
  final Signal<double> signal;
  final double min;
  final double max;
  final int divisions;
  final Future<void> Function(double) onChanged;
  final bool isLocked;
  final Signal<bool>? lockedSignal;

  const _SliderRow({
    required this.label,
    required this.signal,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.isLocked = false,
    this.lockedSignal,
  });

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final value = signal.value;
      final locked = lockedSignal?.value ?? isLocked;
      final color = Theme.of(context).colorScheme.secondary;
      final sliderColor = locked
          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
          : color;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: locked
                          ? Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.4)
                          : color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                      activeTrackColor: sliderColor,
                      inactiveTrackColor: sliderColor.withValues(alpha: 0.2),
                      thumbColor: sliderColor,
                      overlayColor: sliderColor.withValues(alpha: 0.12),
                      disabledActiveTrackColor: sliderColor,
                      disabledInactiveTrackColor: sliderColor.withValues(
                        alpha: 0.2,
                      ),
                      disabledThumbColor: sliderColor,
                    ),
                    child: Slider(
                      value: value.clamp(min, max),
                      min: min,
                      max: max,
                      divisions: divisions,
                      onChanged: locked ? null : onChanged,
                    ),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${value.toStringAsFixed(2).replaceAll(RegExp(r'0+\$'), '').replaceAll(RegExp(r'\.\$'), '')}x',
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w600,
                      color: locked
                          ? Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _SyncCheckboxRow extends StatelessWidget {
  final Signal<bool> value;
  final Future<void> Function(bool) onChanged;

  const _SyncCheckboxRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final isChecked = value.value;
      return InkWell(
        onTap: () => onChanged(!isChecked),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text('', style: Theme.of(context).textTheme.labelMedium),
              ),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: isChecked,
                        onChanged: (v) => onChanged(v ?? false),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Sync pitch with speed',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 52),
            ],
          ),
        ),
      );
    });
  }
}

class _TimeCrownPicker extends StatefulWidget {
  final int maxValue;
  final int initialValue;
  final String label;
  final ValueChanged<int> onChanged;

  const _TimeCrownPicker({
    required this.maxValue,
    required this.initialValue,
    required this.label,
    required this.onChanged,
  });

  @override
  State<_TimeCrownPicker> createState() => _TimeCrownPickerState();
}

class _TimeCrownPickerState extends State<_TimeCrownPicker> {
  static const _itemExtent = 40.0;
  static const _itemCount = 6000; // 100 loops — ample range, near-infinite feel

  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(
      initialItem: widget.initialValue + _itemCount ~/ 2,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _wrap(int index) => index % (widget.maxValue + 1);

  void _onSelectedItemChanged(int index) {
    widget.onChanged(_wrap(index));
  }

  void _maybeWrap() {
    const snapBoundary = 10; // items from edge before snapping
    const mid = _itemCount ~/ 2;
    final range = widget.maxValue + 1;

    final raw = _controller.selectedItem;
    final value = _wrap(raw);

    // Scrolling down: approaching the very end of the list
    if (raw >= _itemCount - snapBoundary) {
      final offset = value; // position within a segment
      _controller.jumpToItem(mid - range + offset);
    }
    // Scrolling up: approaching the very beginning of the list
    else if (raw <= snapBoundary) {
      final offset = value;
      _controller.jumpToItem(mid + range + offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification) {
                  _maybeWrap();
                }
                return false;
              },
              child: ListWheelScrollView.useDelegate(
                controller: _controller,
                itemExtent: _itemExtent,
                diameterRatio: 1.1,
                perspective: 0.003,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: _onSelectedItemChanged,
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: _itemCount,
                  builder: (context, index) {
                    return Center(
                      child: Text(
                        _wrap(index).toString().padLeft(2, '0'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 18,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrownLabel extends StatelessWidget {
  final String label;

  const _CrownLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SpeedQuickAction extends StatelessWidget {
  final double iconSize;

  const _SpeedQuickAction({required this.iconSize});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final speed = settingsSignal.playbackSpeed.value;
      final pitch = settingsSignal.playbackPitch.value;
      final isModified = speed != 1.0 || pitch != 1.0;
      if (isModified) {
        final numberText = speed
            .toStringAsFixed(2)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: numberText,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const TextSpan(
                text: 'x',
                style: TextStyle(fontWeight: FontWeight.w300),
              ),
            ],
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontSize: 17,
              letterSpacing: -0.5,
            ),
          ),
        );
      }
      return Icon(
        Icons.speed,
        color: Theme.of(context).colorScheme.secondary,
        size: iconSize,
      );
    });
  }
}

class _SleepTimerQuickAction extends StatelessWidget {
  final double iconSize;

  const _SleepTimerQuickAction({required this.iconSize});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final remaining = audioSignal.sleepTimerRemaining.value;
      if (remaining != null) {
        return Text(
          _formatDuration(remaining),
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        );
      }
      return Icon(
        Icons.timer_outlined,
        color: Theme.of(context).colorScheme.secondary,
        size: iconSize,
      );
    });
  }
}

class _SleepTimerLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final remaining = audioSignal.sleepTimerRemaining.value;
      if (remaining != null) {
        return Text(
          _formatDuration(remaining),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }
      return Text(
        'Sleep timer',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
          fontSize: 10,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    });
  }
}

class _SleepTimerSheetItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 28),
        leading: Icon(
          Icons.timer_outlined,
          color: Theme.of(context).colorScheme.secondary,
        ),
        title: Watch((context) {
          final remaining = audioSignal.sleepTimerRemaining.value;
          return Text(
            remaining != null ? _formatDuration(remaining) : 'Sleep timer',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          );
        }),
        onTap: () => showSleepTimerDialog(context),
      ),
    );
  }
}
