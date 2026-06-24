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
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../widgets/components/settings_section.dart';
import '../widgets/components/sliver_page_header.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          const SliverPageHeader(
            title: 'Settings',
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
                          SettingsTile(
                            icon: FontAwesomeIcons.sliders,
                            title: 'Customization',
                            subtitle: 'Themes, layouts, and visual effects',
                            onTap: () =>
                                context.go('/settings/customization'),
                          ),
                          const SettingsDivider(),
                          SettingsTile(
                            icon: FontAwesomeIcons.play,
                            title: 'Playback',
                            subtitle:
                                'Controls, gestures, and background behavior',
                            onTap: () => context.go('/settings/playback'),
                          ),
                          const SettingsDivider(),
                          SettingsTile(
                            icon: FontAwesomeIcons.music,
                            title: 'Library',
                            subtitle: 'Manage music folders and indexing',
                            onTap: () => context.go('/settings/library'),
                          ),
                          const SettingsDivider(),
                          SettingsTile(
                            icon: FontAwesomeIcons.circleInfo,
                            title: 'About',
                            subtitle:
                                'Version information and developer links',
                            onTap: () => context.go('/settings/about'),
                          ),
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
