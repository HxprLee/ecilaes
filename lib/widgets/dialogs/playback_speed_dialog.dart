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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/settings_signal.dart';
import '../../signals/overlay_signal.dart';
import '../components/app_dialog.dart';

void showPlaybackSpeedDialog(BuildContext context) {
  overlaySignal.push(ActiveOverlay.playbackSpeed);

  showDialog(
    context: context,
    useRootNavigator: true,
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
            _SliderRow(
              label: 'Speed',
              signal: settingsSignal.playbackSpeed,
              min: 0.25,
              max: 2.0,
              divisions: 7,
              onChanged: settingsSignal.updatePlaybackSpeed,
            ),
            const SizedBox(height: 4),
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
              overlaySignal.pop(ActiveOverlay.playbackSpeed);
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
  final Signal<bool>? lockedSignal;

  const _SliderRow({
    required this.label,
    required this.signal,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.lockedSignal,
  });

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(builder: (context) {
      final value = signal.value;
      final locked = lockedSignal?.value ?? false;
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
                    '${value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}x',
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
    return SignalBuilder(builder: (context) {
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
