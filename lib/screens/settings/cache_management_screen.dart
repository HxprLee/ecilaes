import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/cache_service.dart';
import '../../services/lyrics_service.dart';
import '../../signals/audio_signal.dart';
import '../../widgets/app_dialog.dart';
import 'package:signals/signals_flutter.dart';
import '../../widgets/sliver_page_header.dart';

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

    if (mounted) {
      setState(() {
        _metadataStats = meta;
        _albumArtStats = album;
        _artistArtStats = artist;
        _lyricsStats = lyrics;
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
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(36),
        ),
        child: Center(
          child: icon is FaIconData
              ? FaIcon(
                  icon,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20,
                )
              : Icon(
                  icon as IconData,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20,
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
        stats != null
            ? '${stats.fileCount} files • ${_formatSize(stats.sizeBytes)}'
            : 'Calculating...',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
          fontSize: 12,
        ),
      ),
      trailing: IconButton(
        icon: Icon(
          Icons.delete_outline,
          size: 20,
          color: stats != null && stats.fileCount > 0
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        ),
        onPressed: stats != null && stats.fileCount > 0
            ? () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AppDialog(
                    titleIcon: Icon(Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.error),
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
                            color: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withValues(alpha: 0.2),
                          ),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(context).colorScheme.onError,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }  @override
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
                      _sectionLabel('Cache Categories', context),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Card(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.8),
                          surfaceTintColor:
                              Theme.of(context).colorScheme.secondary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withValues(alpha: 0.1),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
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
                              const Divider(height: 1, indent: 64),
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
                              const Divider(height: 1, indent: 64),
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
                              const Divider(height: 1, indent: 64),
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
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _sectionLabel('Maintenance', context),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Card(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.8),
                          surfaceTintColor:
                              Theme.of(context).colorScheme.secondary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withValues(alpha: 0.1),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              ListTile(
                                leading: Icon(Icons.delete_forever,
                                    size: 20,
                                    color: Theme.of(context).colorScheme.error),
                                title: const Text('Clear All Cache',
                                    style: TextStyle(fontSize: 14)),
                                subtitle: const Text(
                                    'Delete all metadata, art, and lyrics',
                                    style: TextStyle(fontSize: 12)),
                                onTap: () => _confirmClearAll(),
                              ),
                            ],
                          ),
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

  Future<void> _confirmClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AppDialog(
        titleIcon: Icon(Icons.delete_forever,
            color: Theme.of(context).colorScheme.error),
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
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withValues(alpha: 0.2),
              ),
              shape: const StadiumBorder(),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
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
