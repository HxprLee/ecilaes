import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import '../../services/YoutubeDatasource.dart';
import '../../models/song.dart';
import '../../signals/audio_signal.dart';
import '../song_actions_sheet.dart';
import '../common/flyout_sheet.dart';

void showQueueSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    isScrollControlled: true,
    useRootNavigator: true,
    sheetAnimationStyle: AnimationStyle(
      curve: const Cubic(0.68, 0.01, 0.55, 0.99),
      duration: const Duration(milliseconds: 500),
    ),
    useSafeArea: true,
    builder: (context) {
      return const QueueView();
    },
  );
}

class QueueView extends StatefulWidget {
  const QueueView({super.key});

  @override
  State<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<QueueView> {
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;
  String? _lastSongId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    
    // Initial scroll to playing song
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToPlaying(animated: false);
      _lastSongId = audioSignal.currentSong.value?.path;
    });

    // Auto-scroll on song change
    effect(() {
      final currentSongId = audioSignal.currentSong.value?.path;
      if (_lastSongId != null && currentSongId != _lastSongId) {
        // Delay slightly to ensure list is rebuilt if queue changed
        WidgetsBinding.instance.addPostFrameCallback((_) {
           if (mounted) _scrollToPlaying(animated: true);
        });
      }
      _lastSongId = currentSongId;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    
    final currentIndex = audioSignal.currentQueueIndex.value;
    if (currentIndex == -1) return;

    final playingOffset = currentIndex * 72.0;
    final currentOffset = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;

    // Show button if playing song is not at the top or near it
    final atTop = (currentOffset - playingOffset).abs() < 10;
    final isVisible = atTop || (currentOffset <= playingOffset && 
                      currentOffset + viewportHeight >= playingOffset + 72);

    if (_showBackToTop == isVisible) {
      setState(() {
        _showBackToTop = !isVisible;
      });
    }
  }

  void _scrollToPlaying({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final currentIndex = audioSignal.currentQueueIndex.value;
    if (currentIndex == -1) return;

    // Scroll such that the playing song is at the top (offset 0 relative to viewport)
    final offset = currentIndex * 72.0;
    
    if (animated) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      _scrollController.jumpTo(offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlyoutSheet(
      mainAxisSize: MainAxisSize.max,
      safeAreaTop: true,
      child: Stack(
        children: [
          Column(
            children: [
              // Header - Wrapped in SingleChildScrollView
              SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Queue',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary,
                            ),
                      ),
                      const Spacer(),
                      Watch((context) {
                        final queueCount =
                            audioSignal.effectiveQueue.value.length;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$queueCount tracks',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withValues(alpha: 0.6),
                                  ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, size: 20),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withValues(alpha: 0.8),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              Expanded(
                child: Watch((context) {
                  final queue = audioSignal.effectiveQueue.value;
                  final currentId = audioSignal.currentSong.value?.path;
                  final currentIndex = audioSignal.currentQueueIndex.value;
                  
                  if (queue.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(
                            FontAwesomeIcons.music,
                            size: 48,
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No songs in queue',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                                ),
                          ),
                        ],
                      ),
                    );
                  }
    
                  return SuperListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: queue.length,
                    itemBuilder: (context, index) {
                      final item = queue[index];
                      final isCurrent = item.id == currentId;
                      final isPlayed = index < currentIndex;
                      
                      return _buildQueueTile(
                        context, 
                        item, 
                        index, 
                        isCurrent, 
                        isDimmed: isPlayed,
                      );
                    },
                  );
                }),
              ),
            ],
          ),
          
          if (_showBackToTop)
            Positioned(
              bottom: 24,
              left: 24,
              child: GestureDetector(
                onTap: () => _scrollToPlaying(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_upward,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQueueTile(
    BuildContext context, 
    MediaItem item, 
    int index,
    bool isCurrentlyPlaying, {
    bool isDimmed = false,
  }) {
    final song = audioSignal.songMap.value[item.id] ?? Song.fromPath(item.id);

    return SizedBox(
      height: 72,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[800],
          ),
          child: Stack(
            children: [
              // Artwork
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildArtwork(song),
              ),
              // Playing Indicator Overlay
              if (isCurrentlyPlaying)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.equalizer,
                      size: 24,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isCurrentlyPlaying 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).colorScheme.secondary.withValues(alpha: isDimmed ? 0.4 : 1.0),
            fontWeight: isCurrentlyPlaying ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          item.artist ?? 'Unknown Artist',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: isDimmed ? 0.3 : 0.7),
            fontSize: 12,
          ),
        ),
        trailing: IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () {
            showSongMoreActionsSheet(
              context: context,
              song: song,
            );
          },
          icon: Icon(
            Icons.more_horiz,
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: isDimmed ? 0.3 : 0.5),
            size: 20,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        onTap: () {
          audioSignal.playSong(song);
        },
      ),
    );
  }

  Widget _buildArtwork(Song song) {
    if (!song.hasAlbumArt) {
      return const Icon(Icons.music_note, color: Colors.white54);
    }
    
    return Watch((context) {
      final artDir = audioSignal.albumArtDir.value;
      if (artDir == null) return const Icon(Icons.music_note, color: Colors.white54);

      final artPath = '$artDir/${song.path.hashCode.abs()}.jpg';
      final file = File(artPath);

      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: 96,
          cacheHeight: 96,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.music_note, color: Colors.white54),
        );
      }

      if (song.path.startsWith('yt:')) {
        final videoId = song.path.substring(3);
        final url = youtubeDatasource.getArtworkUrl(videoId);
        return Image.network(
          url,
          fit: BoxFit.cover,
          cacheWidth: 96,
          cacheHeight: 96,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.music_note, color: Colors.white54),
        );
      }

      return const Icon(Icons.music_note, color: Colors.white54);
    });
  }
}
