import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/cache_service.dart';
import '../../services/lyrics_service.dart';
import '../../widgets/page_header.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';

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
    required IconData icon,
    required CacheStats? stats,
    required VoidCallback onClear,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('$description\n${stats != null ? '${stats.fileCount} files • ${_formatSize(stats.sizeBytes)}' : 'Calculating...'}'),
      isThreeLine: true,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        color: Theme.of(context).colorScheme.error,
        onPressed: stats != null && stats.fileCount > 0 ? () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text('Clear $title?'),
              content: const Text('This action cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  child: const Text('Clear'),
                ),
              ],
            ),
          );

          if (confirm == true) {
            onClear();
          }
        } : null,
        tooltip: 'Clear $title',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: PageHeader(
              title: 'Cache Management',
              subtitle: 'Manage storage used by the app',
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            SliverList(
              delegate: SliverChildListDelegate([
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
                         const SnackBar(content: Text('Cleared Metadata cache. Full scan needed.'))
                      );
                    }
                  },
                ),
                _buildCacheItem(
                  title: 'Album Art',
                  description: 'Downloaded and extracted album covers',
                  icon: Icons.album,
                  stats: _albumArtStats,
                  onClear: () async {
                    await cacheService.clearAlbumArt();
                    await _loadStats();
                  },
                ),
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
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Clear All Cache?'),
                          content: const Text('This will delete all cached data. You may need to perform a full re-scan of your library afterward.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                              child: const Text('Clear All'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        setState(() => _isLoading = true);
                        await cacheService.clearAll();
                        LyricsService().clearCache();
                        audioSignal.artistPictures.value.clear();
                        await _loadStats();
                         if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text('All caches cleared.'))
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Clear All Cache'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                      backgroundColor: Theme.of(context).colorScheme.errorContainer,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
            SliverToBoxAdapter(
              child: Watch((context) => SizedBox(height: audioSignal.reservedHeight.value)),
            ),
          ],
        ],
      ),
    );
  }
}
