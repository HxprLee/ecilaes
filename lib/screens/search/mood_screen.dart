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
import '../../../signals/audio_signal.dart';
import '../../../services/YoutubeDatasource.dart';
import '../../../utils/navigation.dart';
import '../../../widgets/components/sliver_page_header.dart';

class MoodScreen extends StatefulWidget {
  final String title;
  final String params;

  const MoodScreen({
    super.key,
    required this.title,
    required this.params,
  });

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  List<Map<String, dynamic>>? _sections;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    // 1. Try cache first
    try {
      final cached = await youtubeDatasource.getCachedMoodPlaylists(widget.params);
      if (cached != null && cached.isNotEmpty && mounted) {
        setState(() {
          _sections = cached;
          _isLoading = false;
        });
      }
    } catch (_) {}

    // 2. Fetch fresh data
    try {
      final sections = await youtubeDatasource.getMoodPlaylists(widget.params);
      if (mounted) {
        setState(() {
          _sections = sections;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          if (_sections == null || _sections!.isEmpty) {
            _isLoading = false;
          }
        });
      }
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
            subtitle: 'YouTube Music Mixes',
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Text('Failed to load: $_error'),
              ),
            )
          else if (_sections == null || _sections!.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('No playlists found.'),
              ),
            )
          else
            ..._sections!.map((section) => _buildSection(context, section['title'], section['items'])),
          SliverToBoxAdapter(
            child: SignalBuilder(builder: (context) => SizedBox(height: audioSignal.reservedHeight.value)),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<dynamic> items) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index] as Map<String, dynamic>;
                final itemTitle = item['title'] ?? 'Unknown';
                final browseId = item['browseId'];
                final description = item['description'] ?? '';
                final thumbnailUrl = item['thumbnailUrl'] ?? '';

                return SizedBox(
                  width: 160,
                  child: InkWell(
                    onTap: () {
                      if (browseId != null) {
                        navigatePush(
                          context,
                          '/youtube/playlist/${Uri.encodeComponent(browseId)}',
                          extra: {
                            'title': itemTitle,
                            'thumbnailUrl': thumbnailUrl,
                          },
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
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
                                  image: thumbnailUrl.isNotEmpty ? DecorationImage(
                                    image: NetworkImage(thumbnailUrl),
                                    fit: BoxFit.cover,
                                  ) : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            itemTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          if (description.isNotEmpty)
                            Text(
                              description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
