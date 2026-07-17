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
import '../../signals/settings_signal.dart';
import '../../theme/app_theme_tokens.dart';
import '../../widgets/components/settings_section.dart';
import '../../widgets/components/sliver_page_header.dart';

class DiscordPresenceSection extends StatelessWidget {
  const DiscordPresenceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          const SliverPageHeader(
            title: 'Discord Presence',
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

                    SettingsSection(
                      child: Column(
                        children: [
                          Watch((context) => SettingsTile(
                            title: 'Listen on YouTube Button',
                            subtitle: 'Show "Listen on YouTube" button in Discord status',
                            showLeading: false,
                            trailing: Switch(
                              value: settingsSignal.enableDiscordListenButton.value,
                              onChanged: settingsSignal.enableDiscordRpc.value
                                  ? (value) => settingsSignal.updateDiscordListenButton(value)
                                  : null,
                              activeThumbColor: context.colorScheme.secondary,
                            ),
                          )),
                          const SettingsDivider(indent: 16),
                          Watch((context) => SettingsTile(
                            title: 'Open Project Button',
                            subtitle: 'Show "Open Project" button in Discord status',
                            showLeading: false,
                            trailing: Switch(
                              value: settingsSignal.enableDiscordProjectLink.value,
                              onChanged: settingsSignal.enableDiscordRpc.value
                                  ? (value) => settingsSignal.updateDiscordProjectLink(value)
                                  : null,
                              activeThumbColor: context.colorScheme.secondary,
                            ),
                          )),
                        ],
                      ),
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
