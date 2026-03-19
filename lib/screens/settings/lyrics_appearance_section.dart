import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';
import '../../signals/settings_signal.dart';
import '../../widgets/subpage_header.dart';

class LyricsAppearanceSection extends StatelessWidget {
  const LyricsAppearanceSection({super.key});

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
                  const SubpageHeader(title: 'Lyrics Layout'),
                  const SizedBox(height: 24),

                  _sectionLabel('Text Alignment', context),
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
                      child: Watch((context) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alignment',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Choose how lyrics text aligns horizontally',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.54),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: _buildAlignmentButton(context),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 24),

                  _sectionLabel('Typography', context),
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
                          _buildSliderSetting(
                            context: context,
                            title: 'Active Text Size',
                            valueType: 'active',
                          ),
                          Divider(
                            height: 1,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.05),
                            indent: 16,
                            endIndent: 16,
                          ),
                          _buildSliderSetting(
                            context: context,
                            title: 'Inactive Text Size',
                            valueType: 'inactive',
                          ),
                          Divider(
                            height: 1,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.05),
                            indent: 16,
                            endIndent: 16,
                          ),
                          _buildSliderSetting(
                            context: context,
                            title: 'Plain Text Size',
                            valueType: 'plain',
                          ),
                          Divider(
                            height: 1,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.05),
                            indent: 16,
                            endIndent: 16,
                          ),
                          Watch((context) {
                            return SwitchListTile(
                              title: Text(
                                'Romanized Lyrics',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'Show transliterated text beneath original lyrics',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.54),
                                  fontSize: 12,
                                ),
                              ),
                              value: settingsSignal.showRomanizedLyrics.value,
                              onChanged: (value) =>
                                  settingsSignal.updateShowRomanizedLyrics(value),
                              activeThumbColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                            );
                          }),
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

  Widget _buildSliderSetting({
    required BuildContext context,
    required String title,
    required String valueType,
  }) {
    return Watch((context) {
      final value = valueType == 'active' 
          ? settingsSignal.lyricsActiveFontSize.value 
          : valueType == 'inactive'
              ? settingsSignal.lyricsInactiveFontSize.value
              : settingsSignal.plainLyricsFontSize.value;
          
      return Column(
        children: [
          ListTile(
            title: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              '${value.round()}px',
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: 16,
            ),
            child: Row(
              children: [
                Text(
                  'A',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                    fontSize: 12,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: const Color(0xFFFCE7AC),
                      inactiveTrackColor: const Color(0xFFFCE7AC).withValues(alpha: 0.2),
                      thumbColor: const Color(0xFFFCE7AC),
                      overlayColor: const Color(0xFFFCE7AC).withValues(alpha: 0.1),
                    ),
                    child: Slider(
                      value: value,
                      min: 16.0,
                      max: 48.0,
                      divisions: 32,
                      onChanged: (newValue) {
                         if (valueType == 'active') {
                           settingsSignal.updateLyricsActiveFontSize(newValue);
                         } else if (valueType == 'inactive') {
                           settingsSignal.updateLyricsInactiveFontSize(newValue);
                         } else {
                           settingsSignal.updatePlainLyricsFontSize(newValue);
                         }
                      },
                    ),
                  ),
                ),
                Text(
                  'A',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildAlignmentButton(BuildContext context) {
    return SegmentedButton<TextAlign>(
      segments: const [
        ButtonSegment(
          value: TextAlign.left,
          icon: Icon(Icons.format_align_left, size: 16),
          label: Text('Left', style: TextStyle(fontSize: 12)),
        ),
        ButtonSegment(
          value: TextAlign.center,
          icon: Icon(Icons.format_align_center, size: 16),
          label: Text('Center', style: TextStyle(fontSize: 12)),
        ),
        ButtonSegment(
          value: TextAlign.right,
          icon: Icon(Icons.format_align_right, size: 16),
          label: Text('Right', style: TextStyle(fontSize: 12)),
        ),
      ],
      selected: <TextAlign>{settingsSignal.lyricsAlignment.value},
      onSelectionChanged: (Set<TextAlign> newSelection) {
        settingsSignal.updateLyricsAlignment(newSelection.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
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
}
