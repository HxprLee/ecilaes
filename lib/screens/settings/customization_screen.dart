import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';
import '../../signals/settings_signal.dart';
import '../../theme/app_theme_style.dart';
import '../../widgets/sliver_page_header.dart';

class CustomizationScreen extends StatelessWidget {
  const CustomizationScreen({super.key});

  bool get _isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          const SliverPageHeader(
            title: 'Customization',
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
                    
                    // Display section
                    _sectionLabel('Display', context),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                        surfaceTintColor: Theme.of(context).colorScheme.secondary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Watch((context) {
                          final scale = settingsSignal.textScaleFactor.value;
                          return Column(
                            children: [
                              // Theme Style selector
                              if (_isMobile)
                                _buildMobileThemeStyle(context)
                              else
                                ListTile(
                                  title: const Text('Theme Style', style: TextStyle(fontSize: 14)),
                                  subtitle: const Text('Choose color palette', style: TextStyle(fontSize: 12)),
                                  trailing: _buildThemeStyleButton(context),
                                ),
                              _divider(context),
                              // Theme mode selector
                              if (_isMobile)
                                _buildMobileThemeMode(context)
                              else
                                ListTile(
                                  title: const Text('Theme', style: TextStyle(fontSize: 14)),
                                  subtitle: const Text('Choose app appearance', style: TextStyle(fontSize: 12)),
                                  trailing: _buildThemeModeButton(context),
                                ),
                              _divider(context),
                              ListTile(
                                title: const Text('Text Scale', style: TextStyle(fontSize: 14)),
                                subtitle: Text('${(scale * 100).round()}%', 
                                  style: TextStyle(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8), fontSize: 12)),
                              ),
                              _buildTextScaleSlider(context, scale),
                            ],
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Visual Effects section
                    _sectionLabel('Visual Effects', context),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                        surfaceTintColor: Theme.of(context).colorScheme.secondary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            Watch((context) => SwitchListTile(
                              title: const Text('Custom Font (Iosevka)', style: TextStyle(fontSize: 14)),
                              subtitle: const Text('Use bundled Iosevka Nerd Font', style: TextStyle(fontSize: 12)),
                              value: settingsSignal.useCustomFont.value,
                              onChanged: (value) => settingsSignal.updateCustomFont(value),
                              activeThumbColor: Theme.of(context).colorScheme.secondary,
                            )),
                            if (_isDesktop) ...[
                              _divider(context),
                              Watch((context) => SwitchListTile(
                                title: const Text('Custom Window Controls', style: TextStyle(fontSize: 14)),
                                subtitle: const Text('Use custom buttons', style: TextStyle(fontSize: 12)),
                                value: settingsSignal.useCustomWindowControls.value,
                                onChanged: (value) => settingsSignal.updateCustomWindowControls(value),
                                activeThumbColor: Theme.of(context).colorScheme.secondary,
                              )),
                            ],
                            _divider(context),
                            Watch((context) => SwitchListTile(
                              title: const Text('Blur Effect', style: TextStyle(fontSize: 14)),
                              subtitle: const Text('Enable backdrop blur globally', style: TextStyle(fontSize: 12)),
                              value: settingsSignal.enableGlobalBlur.value,
                              onChanged: (value) => settingsSignal.updateGlobalBlur(value),
                              activeThumbColor: Theme.of(context).colorScheme.secondary,
                            )),
                            if (_isDesktop) ...[
                              _divider(context),
                              Watch((context) => SwitchListTile(
                                title: const Text('Window Transparency', style: TextStyle(fontSize: 14)),
                                subtitle: const Text('Translucent background (requires restart)', style: TextStyle(fontSize: 12)),
                                value: settingsSignal.enableWindowTransparency.value,
                                onChanged: (value) => settingsSignal.updateWindowTransparency(value),
                                activeThumbColor: Theme.of(context).colorScheme.secondary,
                              )),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Layout section
                    _sectionLabel('Layout', context),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                        surfaceTintColor: Theme.of(context).colorScheme.secondary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            _LayoutTile(
                              title: 'Player Layout',
                              subtitle: 'Customize the action buttons row',
                              onTap: () => context.go('/settings/customization/player-layout'),
                            ),
                            _divider(context),
                            _LayoutTile(
                              title: 'Context Menu Actions',
                              subtitle: 'Customize the long-press menu actions',
                              onTap: () => context.go('/settings/customization/actions-layout'),
                            ),
                            _divider(context),
                            _LayoutTile(
                              title: 'Lyrics View Layout',
                              subtitle: 'Customize lyrics alignment and fonts',
                              onTap: () => context.go('/settings/customization/lyrics-layout'),
                            ),
                            _divider(context),
                            _LayoutTile(
                              title: 'Sidebar Items',
                              subtitle: 'Choose which library items appear in sidebar',
                              onTap: () => context.go('/settings/customization/sidebar-layout'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Watch((context) => SizedBox(height: audioSignal.reservedHeight.value)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileThemeStyle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Theme Style', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text('Choose color palette', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: _buildThemeStyleButton(context)),
        ],
      ),
    );
  }

  Widget _buildMobileThemeMode(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Theme', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text('Choose app appearance', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: _buildThemeModeButton(context)),
        ],
      ),
    );
  }

  Widget _buildTextScaleSlider(BuildContext context, double scale) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
      child: Row(
        children: [
          const Text('A', style: TextStyle(fontSize: 12, color: Colors.grey)),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFFFCE7AC),
                inactiveTrackColor: const Color(0xFFFCE7AC).withValues(alpha: 0.2),
                thumbColor: const Color(0xFFFCE7AC),
              ),
              child: Slider(
                value: scale,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                onChanged: (value) => settingsSignal.updateTextScale(value),
              ),
            ),
          ),
          const Text('A', style: TextStyle(fontSize: 20, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildThemeStyleButton(BuildContext context) {
    return SegmentedButton<AppThemeStyle>(
      segments: const [
        ButtonSegment(value: AppThemeStyle.signature, icon: Icon(Icons.palette, size: 16), label: Text('eclipx', style: TextStyle(fontSize: 12))),
        ButtonSegment(value: AppThemeStyle.material3, icon: Icon(Icons.auto_awesome, size: 16), label: Text('Material', style: TextStyle(fontSize: 12))),
      ],
      selected: {settingsSignal.themeStyle.value},
      onSelectionChanged: (set) => settingsSignal.updateThemeStyle(set.first),
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      showSelectedIcon: false,
    );
  }

  Widget _buildThemeModeButton(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto, size: 16), label: Text('System', style: TextStyle(fontSize: 12))),
        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 16), label: Text('Light', style: TextStyle(fontSize: 12))),
        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 16), label: Text('Dark', style: TextStyle(fontSize: 12))),
      ],
      selected: {settingsSignal.themeMode.value},
      onSelectionChanged: (set) => settingsSignal.updateThemeMode(set.first),
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      showSelectedIcon: false,
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

class _LayoutTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LayoutTile({required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
