import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../signals/audio_signal.dart';
import '../widgets/sliver_page_header.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverPageHeader(
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
                    // Settings categories
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
                            _SettingsTile(
                              icon: FontAwesomeIcons.palette,
                              title: 'Appearance',
                              subtitle: 'Themes, fonts, and window controls',
                              onTap: () => context.go('/settings/appearance'),
                            ),
                            _divider(context),
                            _SettingsTile(
                              icon: FontAwesomeIcons.play,
                              title: 'Playback',
                              subtitle:
                                  'Controls, gestures, and background behavior',
                              onTap: () => context.go('/settings/playback'),
                            ),
                            _divider(context),
                            _SettingsTile(
                              icon: FontAwesomeIcons.music,
                              title: 'Library',
                              subtitle: 'Manage music folders and indexing',
                              onTap: () => context.go('/settings/library'),
                            ),
                            _divider(context),
                            _SettingsTile(
                              icon: FontAwesomeIcons.circleInfo,
                              title: 'About',
                              subtitle:
                                  'Version information and developer links',
                              onTap: () => context.go('/settings/about'),
                            ),
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
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) => Divider(
    height: 1,
    thickness: 1,
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
    indent: 72,
  );
}

class _SettingsTile extends StatelessWidget {
  final FaIconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(36),
        ),
        child: Center(
          child: FaIcon(
            icon,
            color: Theme.of(context).colorScheme.secondary,
            size: 18,
          ),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
    );
  }
}
