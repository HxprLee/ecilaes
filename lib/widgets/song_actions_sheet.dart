import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../signals/settings_signal.dart';
import '../signals/audio_signal.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'playlist_dialogs.dart';
import 'common/flyout_sheet.dart';
import 'song_info_dialog.dart';
import 'edit_metadata_dialog.dart';
import 'player/queue_view.dart';
import 'app_dialog.dart';
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
            final ytThumbnailUrl = isYoutube ? youtubeDatasource.getSongArtworkUrl(song) : null;

            File? effectiveArt = albumArt;
            if (effectiveArt == null && song.hasAlbumArt && artDir != null && !isYoutube) {
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
            Icon(
              info.icon,
              color: Theme.of(context).colorScheme.secondary,
              size: 24,
            ),
            if (showLabel) ...[
              const SizedBox(height: 4),
              Text(
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
    case 'radio':
      return ActionInfo(
        icon: Icons.radio,
        label: 'Start radio',
        onTap: (context, song, _) {
          if (song.path.startsWith('yt:')) {
            audioSignal.startRadio(song);
          }
        },
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
  return ListTile(
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
  );
}

void showSleepTimerDialog(BuildContext context) {
  int selectedMinutes = 30;

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
            maxWidth: 360,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Scroll Wheel
                SizedBox(
                  height: 150,
                  child: CupertinoPicker(
                    itemExtent: 40,
                    onSelectedItemChanged: (index) {
                      setDialogState(() {
                        selectedMinutes = index + 1;
                      });
                    },
                    scrollController: FixedExtentScrollController(
                      initialItem: selectedMinutes - 1,
                    ),
                    children: List.generate(120, (index) {
                      return Center(
                        child: Text(
                          '${index + 1} minutes',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                                fontSize: 16,
                              ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                // Preset Chips
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Presets',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withValues(alpha: 0.6),
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
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withValues(alpha: 0.2),
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
                    Duration(minutes: selectedMinutes),
                  );
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
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
