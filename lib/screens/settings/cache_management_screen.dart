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
import '../../services/cache_service.dart';
import '../../services/lyrics_service.dart';
import '../../signals/audio_signal.dart';
import '../../theme/app_theme_tokens.dart';
import '../../widgets/components/app_dialog.dart';
import '../../widgets/components/settings_section.dart';
import 'package:signals/signals_flutter.dart';
import '../../widgets/components/sliver_page_header.dart';

class CacheManagementScreen extends StatefulWidget {
  const CacheManagementScreen({super.key});

  @override
  State<CacheManagementScreen> createState() => _CacheManagementScreenState();
}

class _CacheManagementScreenState extends State<CacheManagementScreen> {
  bool _isLoading = true;
  CacheStats? _metadataStats;
  CacheStats? _albumArtStats;
  CacheStats? _artistArtStats;
  CacheStats? _lyricsStats;
  CacheStats? _audioStats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    final meta = await cacheService.getMetadataStats();
    final album = await cacheService.getAlbumArtStats();
    final artist = await cacheService.getArtistArtStats();
    final lyrics = await cacheService.getLyricsStats();
    final audio = await cacheService.getAudioStats();

    if (mounted) {
      setState(() {
        _metadataStats = meta;
        _albumArtStats = album;
        _artistArtStats = artist;
        _lyricsStats = lyrics;
        _audioStats = audio;
        _isLoading = false;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes == 0) return '0 B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  Widget _buildCacheItem({
    required String title,
    required String description,
    required dynamic icon,
    required CacheStats? stats,
    required VoidCallback onClear,
  }) {
    final hasFiles = stats != null && stats.fileCount > 0;
    return SettingsTile(
      icon: icon,
      title: title,
      subtitle: stats != null
          ? '${stats.fileCount} files • ${_formatSize(stats.sizeBytes)}'
          : 'Calculating...',
      trailing: IconButton(
        icon: Icon(
          Icons.delete_outline,
          size: 20,
          color: hasFiles
              ? context.colorScheme.error
              : context.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
        onPressed: hasFiles
            ? () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AppDialog(
                    titleIcon: Icon(Icons.warning_amber_rounded,
                        color: context.colorScheme.error),
                    title: 'Clear $title?',
                    content: const Text(
                      'This action cannot be undone.',
                      style: TextStyle(fontSize: 14),
                    ),
                    actions: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(c, false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: context.colorScheme.secondary
                                .withValues(alpha: 0.2),
                          ),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                              color: context.colorScheme.secondary),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: context.colorScheme.error,
                          foregroundColor: context.colorScheme.onError,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  onClear();
                }
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          const SliverPageHeader(
            title: 'Cache Management',
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
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      const SettingsSectionLabel('Cache Categories'),
                      SettingsSection(
                        child: Column(
                          children: [
                            _buildCacheItem(
                              title: 'Metadata Cache',
                              description: 'Cached song tags and library data',
                              icon: Icons.data_usage,
                              stats: _metadataStats,
                              onClear: () async {
                                await cacheService.clearMetadata();
                                await _loadStats();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Cleared Metadata cache. Full scan needed.')));
                                }
                              },
                            ),
                            const SettingsDivider(indent: 16),
                            _buildCacheItem(
                              title: 'Album Art',
                              description:
                                  'Downloaded and extracted album covers',
                              icon: Icons.album,
                              stats: _albumArtStats,
                              onClear: () async {
                                await cacheService.clearAlbumArt();
                                await _loadStats();
                              },
                            ),
                            const SettingsDivider(indent: 16),
                            _buildCacheItem(
                              title: 'Artist Pictures',
                              description: 'Artist profiles fetched from Deezer',
                              icon: FontAwesomeIcons.users,
                              stats: _artistArtStats,
                              onClear: () async {
                                await cacheService.clearArtistArt();
                                audioSignal.artistPictures.value.clear();
                                await _loadStats();
                              },
                            ),
                            const SettingsDivider(indent: 16),
                            _buildCacheItem(
                              title: 'Lyrics',
                              description: 'Locally cached lyrics files',
                              icon: Icons.lyrics,
                              stats: _lyricsStats,
                              onClear: () async {
                                await cacheService.clearLyrics();
                                LyricsService().clearCache();
                                await _loadStats();
                              },
                            ),
                            const SettingsDivider(indent: 16),
                            _buildCacheItem(
                              title: 'Song Cache',
                              description: 'Cached YouTube audio streams',
                              icon: Icons.cloud_download,
                              stats: _audioStats,
                              onClear: () async {
                                await cacheService.clearAudioCache();
                                await _loadStats();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const SettingsSectionLabel('Maintenance'),
                      SettingsSection(
                        child: Column(
                          children: [
                            SettingsTile(
                              icon: Icons.delete_forever,
                              iconColor: context.colorScheme.error,
                              title: 'Clear All Cache',
                              subtitle:
                                  'Delete all metadata, art, and lyrics',
                              onTap: () => _confirmClearAll(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Watch((context) =>
                        SizedBox(height: audioSignal.reservedHeight.value)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AppDialog(
        titleIcon: Icon(Icons.delete_forever,
            color: context.colorScheme.error),
        title: 'Clear All Cache?',
        content: const Text(
          'This will delete all cached data. You may need to perform a full re-scan of your library afterward.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(c, false),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: context.colorScheme.secondary.withValues(alpha: 0.2),
              ),
              shape: const StadiumBorder(),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.colorScheme.secondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(
              backgroundColor: context.colorScheme.error,
              foregroundColor: context.colorScheme.onError,
              shape: const StadiumBorder(),
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) setState(() => _isLoading = true);
      await cacheService.clearAll();
      LyricsService().clearCache();
      audioSignal.artistPictures.value.clear();
      await _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('All caches cleared.')));
      }
    }
  }
}
