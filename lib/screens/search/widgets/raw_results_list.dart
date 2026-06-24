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
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../../../signals/audio_signal.dart';
import '../../../signals/search_signal.dart';
import '../../../services/YoutubeDatasource.dart';
import '../../../widgets/components/standard_sliver_list.dart';

class RawResultsList {
  static List<Widget> buildSlivers(
    BuildContext context, {
    required List<Map<String, dynamic>> results,
    required bool isSearching,
    required SearchFilter filterType,
  }) {
    final resultsWidget = Watch((context) {
      final isSearchingYoutube = searchSignal.isSearchingYoutube.value;
      return StandardSliverList<Map<String, dynamic>>(
        items: results,
        isLoading: isSearchingYoutube && results.isEmpty,
        emptyMessage: isSearching
            ? 'No results found'
            : 'Start typing to search',
        itemBuilder: (context, item, index) {
          final title =
              item['title'] ??
              item['name'] ??
              item['artist'] ??
              item['author'] ??
              'Unknown';
          final artists = item['artists'];
          final subtitle = (artists is List && artists.isNotEmpty)
              ? artists.map((a) => (a as Map)['name'] ?? '').join(', ')
              : (item['author']?.toString() ??
                    item['subtitle']?.toString() ??
                    item['type']?.toString() ??
                    '');
          final thumbnails = item['thumbnails'];
          final thumbnailUrl = (thumbnails is List && thumbnails.isNotEmpty)
              ? youtubeDatasource.transformThumbnail(
                  thumbnails.last['url'] ?? '',
                )
              : '';
          final isCircular = filterType == SearchFilter.artists;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 4,
              horizontal: 24,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: isCircular
                    ? BorderRadius.circular(24)
                    : BorderRadius.circular(4),
                image: thumbnailUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(thumbnailUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: thumbnailUrl.isEmpty
                  ? Center(
                      child: FaIcon(
                        _getPlaceholderIcon(filterType),
                        size: 18,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.24),
                      ),
                    )
                  : null,
            ),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: subtitle.isNotEmpty
                ? Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  )
                : null,
            onTap: () {
              if (filterType == SearchFilter.videos &&
                  item['videoId'] != null) {
                audioSignal.playSong(youtubeDatasource.mapToSong(item));
              } else if (filterType == SearchFilter.albums &&
                  item['browseId'] != null) {
                context.go(
                  '/youtube/album/${Uri.encodeComponent(item['browseId'])}',
                  extra: {'title': title, 'thumbnailUrl': thumbnailUrl},
                );
              } else if (filterType == SearchFilter.artists &&
                  (item['browseId'] != null)) {
                context.go(
                  '/youtube/artist/${Uri.encodeComponent(item['browseId'])}',
                  extra: {'name': title, 'thumbnailUrl': thumbnailUrl},
                );
              } else if ((filterType == SearchFilter.community_playlists ||
                      filterType == SearchFilter.featured_playlists ||
                      filterType == SearchFilter.playlists) &&
                  item['browseId'] != null) {
                String playlistId = item['browseId'];
                if (playlistId.startsWith('VL')) {
                  playlistId = playlistId.substring(2);
                }
                context.go(
                  '/youtube/playlist/${Uri.encodeComponent(playlistId)}',
                  extra: {'title': title, 'thumbnailUrl': thumbnailUrl},
                );
              } else if (item['videoId'] != null) {
                audioSignal.playSong(youtubeDatasource.mapToSong(item));
              }
            },
          );
        },
      );
    });

    return [resultsWidget];
  }

  static FaIconData _getPlaceholderIcon(SearchFilter filterType) {
    switch (filterType) {
      case SearchFilter.videos:
        return FontAwesomeIcons.video;
      case SearchFilter.albums:
        return FontAwesomeIcons.recordVinyl;
      case SearchFilter.artists:
        return FontAwesomeIcons.userGroup;
      case SearchFilter.community_playlists:
      case SearchFilter.featured_playlists:
      case SearchFilter.playlists:
        return FontAwesomeIcons.list;
      case SearchFilter.podcasts:
        return FontAwesomeIcons.podcast;
      case SearchFilter.episodes:
        return FontAwesomeIcons.circlePlay;
      default:
        return FontAwesomeIcons.music;
    }
  }
}
