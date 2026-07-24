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
import '../../signals/audio_signal.dart';
import '../../services/YoutubeDatasource.dart';
import '../../utils/navigation.dart';
import '../../widgets/components/sliver_page_header.dart';
import '../../models/song.dart';

class SeeMoreScreen extends StatefulWidget {
  final String sectionKey;
  final String title;

  const SeeMoreScreen({
    super.key,
    required this.sectionKey,
    required this.title,
  });

  @override
  State<SeeMoreScreen> createState() => _SeeMoreScreenState();
}

class _SeeMoreScreenState extends State<SeeMoreScreen> {
  List<Map<String, dynamic>>? _items;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    // The YouTube Music home screen uses getHomeSections(), not getExplore().
    // Use the same source to avoid key mismatches.
    List<Map<String, dynamic>>? sections;
    try {
      sections = await youtubeDatasource.getHomeSections();
    } catch (_) {}

    if (!mounted) return;

    List<Map<String, dynamic>>? items;
    if (sections != null) {
      for (final section in sections) {
        if (section['title'] == widget.title) {
          items = (section['items'] as List?)?.cast<Map<String, dynamic>>();
          break;
        }
      }
    }

    if (mounted) {
      setState(() {
        _items = items ?? [];
        _isLoading = false;
        if (items == null) {
          _error = 'Section not found.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverPageHeader(
            title: widget.title,
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(child: Text(_error!)),
            )
          else if (_items != null && _items!.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('No items found.')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.78,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _items![index];
                    return _buildCard(context, item);
                  },
                  childCount: _items!.length,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SignalBuilder(builder: (context) => SizedBox(height: audioSignal.reservedHeight.value)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> item) {
    final titleText = item['title'] ?? item['name'] ?? 'Unknown';
    final thumbnails = item['thumbnails'];
    String thumbnailUrl = '';
    if (thumbnails is List && thumbnails.isNotEmpty) {
      thumbnailUrl = thumbnails.last['url']?.toString() ?? '';
      if (thumbnailUrl.startsWith('//')) thumbnailUrl = 'https:$thumbnailUrl';
    } else if (item['thumbnailUrl'] != null && item['thumbnailUrl'].toString().isNotEmpty) {
      thumbnailUrl = item['thumbnailUrl'].toString();
    }

    final artists = item['artists'];
    String subtitle = '';
    if (artists is List && artists.isNotEmpty) {
      subtitle = artists.map((a) => (a is Map) ? (a['name'] ?? '') : '').join(', ');
    } else if (item['description'] != null) {
      subtitle = item['description'].toString();
    } else if (item['views'] != null) {
      subtitle = item['views'].toString();
    }

    return InkWell(
      onTap: () => _onTap(context, item, titleText, thumbnailUrl),
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  image: thumbnailUrl.isNotEmpty
                      ? DecorationImage(image: NetworkImage(thumbnailUrl), fit: BoxFit.cover)
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            titleText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }

  void _onTap(BuildContext context, Map<String, dynamic> item, String titleText, String thumbnailUrl) {
    if (item['videoId'] != null) {
      final song = Song(
        path: 'yt:${item['videoId']}',
        title: titleText,
        artist: item['artists'] is List
            ? (item['artists'] as List).map((a) => (a is Map) ? a['name'] ?? '' : '').join(', ')
            : '',
        hasAlbumArt: true,
      );
      audioSignal.playSong(song);
    } else if (item['browseId'] != null) {
      if (item['type'] == 'Album') {
        navigatePush(
          context,
          '/youtube/album/${Uri.encodeComponent(item['browseId'])}',
          extra: {'title': titleText, 'thumbnailUrl': thumbnailUrl},
        );
      } else {
        navigatePush(
          context,
          '/youtube/playlist/${Uri.encodeComponent(item['browseId'])}',
          extra: {'title': titleText, 'thumbnailUrl': thumbnailUrl},
        );
      }
    }
  }
}
