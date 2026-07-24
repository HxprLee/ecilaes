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
import 'package:signals/signals_flutter.dart';
import '../models/song.dart';
import '../signals/settings_signal.dart';
import '../signals/audio_signal.dart';
import '../signals/overlay_signal.dart';
import '../services/YoutubeDatasource.dart';
import '../services/share_intent_service.dart';
import 'dialogs/playlist_dialogs.dart';
import 'components/app_toast.dart';
import 'dialogs/song_info_dialog.dart';
import 'dialogs/edit_metadata_dialog.dart';
import 'dialogs/sleep_timer_dialog.dart';
import 'dialogs/playback_speed_dialog.dart';
import 'player/queue_view.dart';
import 'components/flyout_sheet.dart';

void showSongMoreActionsSheet({
  required BuildContext context,
  required Song song,
  File? albumArt,
  String? playlistId,
}) {
  overlaySignal.push(ActiveOverlay.songActions);

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
          child: SignalBuilder(builder: (context) {
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
        if (info.closeOnTap) {
          overlaySignal.pop(ActiveOverlay.songActions);
          Navigator.pop(context);
        }
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
          EditMetadataDialog.show(context, song: song);
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
        onTap: (context, song, _) async {
          try {
            await shareIntentService.shareSong(song);
            final isLocal = !song.path.startsWith('yt:');
            ToastService.show(
              isLocal
                  ? 'File path copied to clipboard'
                  : 'Link copied to clipboard',
              variant: AppToastVariant.success,
            );
          } catch (_) {
            // Silent: share is best-effort.
          }
        },
        closeOnTap: true,
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
        if (closeOnTap) {
          overlaySignal.pop(ActiveOverlay.songActions);
          Navigator.pop(context);
        }
        onTap();
      },
    ),
  );
}

// Quick action widgets used in the actions sheet

class _SpeedQuickAction extends StatelessWidget {
  final double iconSize;

  const _SpeedQuickAction({required this.iconSize});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(builder: (context) {
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
    return SignalBuilder(builder: (context) {
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
    return SignalBuilder(builder: (context) {
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
        title: SignalBuilder(builder: (context) {
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

String _formatDuration(Duration? d) {
  if (d == null) return '';
  if (d.inHours > 0) {
    return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
  return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
