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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';
import '../../signals/overlay_signal.dart';
import '../../router/routes.dart';
import '../../signals/settings_signal.dart';
import '../../theme/app_theme_tokens.dart';
import '../../utils/navigation.dart';
import '../../widgets/components/last_fm_auth_dialog.dart';
import '../../widgets/components/settings_section.dart';
import '../../widgets/components/sliver_page_header.dart';

class IntegrationsSection extends StatelessWidget {
  const IntegrationsSection({super.key});

  bool get _isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          const SliverPageHeader(
            title: 'Integrations',
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

                    // Discord Rich Presence (desktop only)
                    if (_isDesktop) ...[
                      const SettingsSectionLabel('Discord Rich Presence'),
                      SettingsSection(
                        child: Column(
                          children: [
                            SignalBuilder(builder: (context) => SettingsTile(
                              title: 'Enable Discord Presence',
                              subtitle: 'Show current song in your Discord status',
                              showLeading: false,
                              trailing: Switch(
                                value: settingsSignal.enableDiscordRpc.value,
                                onChanged: (value) =>
                                    settingsSignal.updateDiscordRpc(value),
                                activeThumbColor: context.colorScheme.secondary,
                              ),
                            )),
                            if (_isDesktop) ...[
                              const SettingsDivider(indent: 16),
                              SignalBuilder(builder: (context) => SettingsTile(
                                title: 'Buttons',
                                subtitle: 'Configure Discord status buttons',
                                showLeading: false,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (settingsSignal.enableDiscordRpc.value)
                                      Icon(
                                        Icons.chevron_right,
                                        size: 20,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.38),
                                      ),
                                  ],
                                ),
                                onTap: settingsSignal.enableDiscordRpc.value
                                    ? () => navigatePush(context, AppRoutes.settingsIntegrationsDiscordPresence)
                                    : null,
                              )),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // YouTube Music
                    const SettingsSectionLabel('YouTube Music'),
                    SettingsSection(
                      child: SignalBuilder(builder: (context) {
                        final hasCookie =
                            settingsSignal.ytAuthCookie.value != null &&
                                settingsSignal.ytAuthCookie.value!.isNotEmpty;
                        return SettingsTile(
                          icon: FontAwesomeIcons.youtube,
                          title: 'YouTube Music Account',
                          subtitle: hasCookie
                              ? (settingsSignal.ytUsername.value != null
                                      ? 'Connected \u{2022} ${settingsSignal.ytUsername.value}'
                                      : 'Connected')
                              : 'Not connected',
                          trailing: hasCookie
                              ? TextButton(
                                  onPressed: () async {
                                    await settingsSignal.updateYtAuthCookie(null);
                                    await audioSignal.reindexLibrary();
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        Theme.of(context).colorScheme.error,
                                  ),
                                  child: const Text('Disconnect'),
                                )
                              : const Icon(Icons.chevron_right, size: 20),
                          onTap: hasCookie
                              ? null
                              : () {
                                  if (kIsWeb) return;
                                  navigatePush(
                                      context, AppRoutes.settingsIntegrationsYoutubeLogin);
                                },
                        );
                      }),
                    ),

                    const SizedBox(height: 24),

                    // Last.fm
                    const SettingsSectionLabel('Last.fm'),
                    SettingsSection(
                      child: SignalBuilder(builder: (context) {
                        final username = settingsSignal.lastFmUsername.value;
                        final isConnected =
                            username != null && username.isNotEmpty;
                        return SettingsTile(
                          icon: FontAwesomeIcons.lastfm,
                          title: 'Last.fm Scrobbling',
                          subtitle: isConnected
                              ? 'Connected as $username'
                              : 'Not connected',
                          showLeading: false,
                          trailing: isConnected
                              ? TextButton(
                                  onPressed: () {
                                    settingsSignal.updateLastFmSession(
                                        null, null);
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        Theme.of(context).colorScheme.error,
                                  ),
                                  child: const Text('Disconnect'),
                                )
                              : const Icon(Icons.chevron_right, size: 20),
                          onTap: isConnected
                              ? null
                              : () {
                                  overlaySignal.push(ActiveOverlay.integrationsConnect);
                                  showDialog(
                                    context: context,
                                    useRootNavigator: true,
                                    builder: (context) =>
                                        const LastFmAuthDialog(),
                                  ).then((_) {
                                    overlaySignal.pop(ActiveOverlay.integrationsConnect);
                                  });
                                },
                        );
                      }),
                    ),

                    const SizedBox(height: 24),
                    SignalBuilder(builder: (context) =>
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
