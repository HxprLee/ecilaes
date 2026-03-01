import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../signals/settings_signal.dart';
import '../signals/audio_signal.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_theme_extensions.dart';
import 'playlist_dialogs.dart';

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
      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: BackdropFilter(
              filter: settingsSignal.enableGlobalBlur.value
                  ? ImageFilter.blur(sigmaX: 20, sigmaY: 20)
                  : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .extension<AppThemeExtension>()!
                      .sidebarBackground
                      .withValues(
                        alpha: settingsSignal.enableGlobalBlur.value
                            ? 0.67
                            : 1.0,
                      ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.15),
                    ),
                    left: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.15),
                    ),
                    right: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Song Header in Sheet
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              image: albumArt != null
                                  ? DecorationImage(
                                      image: FileImage(albumArt),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            child: albumArt == null
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
                    ),
                    Divider(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.2),
                      height: 36,
                    ),
                    _buildSheetItem(
                      context: context,
                      icon: Icons.playlist_add,
                      label: 'Add to playlist',
                      onTap: () {
                        PlaylistPickerDialog.show(context, song: song);
                      },
                      closeOnTap: false,
                    ),
                    if (playlistId != null && playlistId != 'favorites')
                      _buildSheetItem(
                        context: context,
                        icon: Icons.playlist_remove,
                        label: 'Remove from playlist',
                        onTap: () {
                          audioSignal.removeSongFromPlaylist(
                            playlistId,
                            song.path,
                          );
                        },
                      ),
                    _buildSheetItem(
                      context: context,
                      icon: Icons.album_outlined,
                      label: 'Go to album',
                      onTap: () {},
                    ),
                    _buildSheetItem(
                      context: context,
                      icon: Icons.person_outline,
                      label: 'Go to artist',
                      onTap: () {},
                    ),
                    Watch((context) {
                      final remaining = audioSignal.sleepTimerRemaining.value;
                      final timerText = remaining != null
                          ? '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}'
                          : 'Sleep timer';

                      return _buildSheetItem(
                        context: context,
                        icon: Icons.timer_outlined,
                        label: timerText,
                        onTap: () {
                          _showSleepTimerDialog(context);
                        },
                        closeOnTap: false,
                      );
                    }),
                    _buildSheetItem(
                      context: context,
                      icon: Icons.info_outline,
                      label: 'Song info',
                      onTap: () {},
                    ),
                    _buildSheetItem(
                      context: context,
                      icon: Icons.share_outlined,
                      label: 'Share',
                      onTap: () {},
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
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

void _showSleepTimerDialog(BuildContext context) {
  int selectedMinutes = 30;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BackdropFilter(
                  filter: settingsSignal.enableGlobalBlur.value
                      ? ImageFilter.blur(sigmaX: 20, sigmaY: 20)
                      : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .extension<AppThemeExtension>()!
                          .sidebarBackground
                          .withValues(
                            alpha: settingsSignal.enableGlobalBlur.value
                                ? 0.85
                                : 1.0,
                          ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 20,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Sleep timer',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
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
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondary,
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
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
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
                          const SizedBox(height: 24),
                          // Bottom Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Text(
                                    'Off',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    audioSignal.setSleepTimer(
                                      Duration(minutes: selectedMinutes),
                                    );
                                    Navigator.pop(context);
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withValues(alpha: 0.8),
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text('Start timer'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
