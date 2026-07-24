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
import '../../signals/overlay_signal.dart';
import '../components/app_dialog.dart';

void showSleepTimerDialog(BuildContext context) {
  int selectedHours = 0;
  int selectedMinutes = 30;
  int selectedSeconds = 0;

  overlaySignal.push(ActiveOverlay.sleepTimer);

  showDialog(
    context: context,
    useRootNavigator: true,
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
            trailing: SignalBuilder(builder: (context) {
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
                  overlaySignal.pop(ActiveOverlay.sleepTimer);
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
                  overlaySignal.pop(ActiveOverlay.sleepTimer);
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
      overlaySignal.pop(ActiveOverlay.sleepTimer);
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
  static const _itemCount = 6000;

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
    const snapBoundary = 10;
    const mid = _itemCount ~/ 2;
    final range = widget.maxValue + 1;

    final raw = _controller.selectedItem;
    final value = _wrap(raw);

    if (raw >= _itemCount - snapBoundary) {
      final offset = value;
      _controller.jumpToItem(mid - range + offset);
    } else if (raw <= snapBoundary) {
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
