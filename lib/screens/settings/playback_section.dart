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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';
import '../../signals/settings_signal.dart';
import '../../widgets/components/sliver_page_header.dart';
import '../../widgets/components/settings_section.dart';
import '../../widgets/components/spinner_widget.dart';
import '../../widgets/components/app_dialog.dart';
import '../../services/scrobble_service.dart';


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
                                  trailing: SpinnerWidget(
                                    value: settingsSignal.normalizationTargetLufs.value,
                                    min: -23.0,
                                    max: -6.0,
                                    step: 1.0,
                                    formatValue: (v) => v.toStringAsFixed(0),
                                    parseValue: (s) => double.tryParse(s),
                                    onChanged: (value) {
                                      settingsSignal.updateNormalizationTargetLufs(value);
                                      audioSignal.audioHandler.setNormalizationTargetLufs(value);
                                    },
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
                    const SettingsSectionLabel('Integrations'),
                    SettingsSection(
                      child: Column(
                        children: [
                          Watch((context) {
                            final username = settingsSignal.lastFmUsername.value;
                            final isConnected = username != null && username.isNotEmpty;
                            return SettingsTile(
                              title: 'Last.fm Scrobbling',
                              subtitle: isConnected ? 'Connected as $username' : 'Not connected',
                              showLeading: false,
                              trailing: isConnected ? TextButton(
                                onPressed: () {
                                  settingsSignal.updateLastFmSession(null, null);
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(context).colorScheme.error,
                                ),
                                child: const Text('Disconnect'),
                              ) : const Icon(Icons.chevron_right, size: 20),
                              onTap: isConnected ? null : () {
                                showDialog(
                                  context: context,
                                  builder: (context) => const _LastFmAuthDialog(),
                                );
                              },
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

class _LastFmAuthDialog extends StatefulWidget {
  const _LastFmAuthDialog();

  @override
  State<_LastFmAuthDialog> createState() => _LastFmAuthDialogState();
}

class _LastFmAuthDialogState extends State<_LastFmAuthDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter username and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await scrobbleService.authenticate(username, password);

    if (!mounted) return;

    if (result != null) {
      settingsSignal.updateLastFmSession(result['username'], result['key']);
      Navigator.of(context).pop();
    } else {
      setState(() {
        _isLoading = false;
        _error = 'Authentication failed. Please check your credentials.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Last.fm Scrobbling',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Connect your Last.fm account to automatically scrobble the tracks you play.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            obscureText: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Connect'),
        ),
      ],
    );
  }
}
