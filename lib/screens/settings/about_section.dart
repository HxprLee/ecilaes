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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../signals/audio_signal.dart';
import '../../widgets/components/settings_section.dart';
import '../../widgets/components/sliver_page_header.dart';

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          const SliverPageHeader(title: 'About', maxWidth: 600),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Center(
                      child: Column(
                        children: [
                          SignalBuilder(builder: (context) {
                            return SvgPicture.asset(
                              'assets/app_icon.svg',
                              width: 100,
                              height: 100,
                              colorFilter: ColorFilter.mode(
                                Theme.of(context).colorScheme.secondary,
                                BlendMode.srcIn,
                              ),
                            );
                          }),
                          const SizedBox(height: 20),
                          Text(
                            'ecilaes',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Version 0.5.5',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Built with Flutter',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.35),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    const SettingsSectionLabel('Links'),
                    SettingsSection(
                      child: Column(
                        children: [
                          SettingsTile(
                            icon: FontAwesomeIcons.github,
                            title: 'GitHub Repository',
                            subtitle: 'View source code and contribute',
                            showLeading: false,
                            trailing: const Icon(Icons.open_in_new, size: 18),
                            onTap: () => launchUrl(
                              Uri.parse('https://github.com/hxprlee/ecilaes'),
                            ),
                          ),
                          const SettingsDivider(indent: 16),
                          SettingsTile(
                            icon: FontAwesomeIcons.scaleBalanced,
                            title: 'Open Source Licenses',
                            subtitle: 'Third-party library attributions',
                            showLeading: false,
                          ),
                        ],
                      ),
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
