import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';
import '../../signals/settings_signal.dart';
import '../../widgets/subpage_header.dart';

class PlaybackSection extends StatelessWidget {
  const PlaybackSection({super.key});

  bool get _isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  @override
  Widget build(BuildContext context) {
    final topPadding = _isDesktop
        ? 50.0
        : 64.0 + MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: EdgeInsets.only(top: 24.0 + topPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const SubpageHeader(title: 'Playback'),
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
                                  ).colorScheme.onSurface.withOpacity(0.54),
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
                                    ).colorScheme.onSurface.withOpacity(0.54),
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
                                    ).colorScheme.onSurface.withOpacity(0.54),
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
