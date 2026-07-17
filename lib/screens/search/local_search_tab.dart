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
import 'package:signals/signals_flutter.dart';
import '../../../models/song.dart';
import '../../../router/routes.dart';
import '../../../signals/search_signal.dart';
import '../../../utils/navigation.dart';
import '../../../widgets/components/standard_sliver_list.dart';
import '../../../widgets/components/song_tile.dart';

class LocalResultsTab extends StatelessWidget {
  final LocalSearchFilter filter;
  final List<Song> songs;
  final bool isSearching;
  final String query;
  final String? artDirPath;

  const LocalResultsTab({
    super.key,
    required this.filter,
    required this.songs,
    required this.isSearching,
    required this.query,
    required this.artDirPath,
  });

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      switch (filter) {
        case LocalSearchFilter.songs:
          return CustomScrollView(
            slivers: [
              ..._buildSongsSlivers(context),
            ],
          );
        case LocalSearchFilter.playlists:
          return _LocalPlaylistsList(
            isSearching: isSearching,
            query: query,
          );
        case LocalSearchFilter.albums:
          return _LocalAlbumsList(
            isSearching: isSearching,
            query: query,
          );
        case LocalSearchFilter.artists:
          return _LocalArtistsList(
            isSearching: isSearching,
            query: query,
          );
        case LocalSearchFilter.folders:
          return _LocalFoldersList(
            isSearching: isSearching,
            query: query,
          );
      }
    });
  }

  List<Widget> _buildSongsSlivers(BuildContext context) {
    final resultsWidget = Watch((context) {
      return StandardSliverList<Song>(
        items: songs,
        isLoading: false,
        emptyMessage: isSearching ? 'No local songs found' : 'Start typing to search',
        itemBuilder: (context, song, index) => SongTile(
          song: song,
          artDirPath: artDirPath,
          trailing: Text(
            song.duration == null || song.duration == Duration.zero
                ? '--:--'
                : '${song.duration!.inMinutes}:${song.duration!.inSeconds.remainder(60).toString().padLeft(2, '0')}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
              fontSize: 12,
            ),
          ),
        ),
      );
    });

    return [resultsWidget];
  }
}

class _LocalPlaylistsList extends StatelessWidget {
  final bool isSearching;
  final String query;

  const _LocalPlaylistsList({required this.isSearching, required this.query});

  @override
  Widget build(BuildContext context) {
    final playlists = searchSignal.localSearchPlaylists.value;
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final playlist = playlists[index];
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
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.list,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                    ),
                  ),
                ),
                title: Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${playlist.songPaths.length} songs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                onTap: () => navigateGo(context, '${AppRoutes.playlists}/${playlist.id}'),
              );
            },
            childCount: playlists.length,
          ),
        ),
        if (playlists.isEmpty && isSearching)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'No playlists found',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        if (!isSearching)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'Start typing to search',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LocalAlbumsList extends StatelessWidget {
  final bool isSearching;
  final String query;

  const _LocalAlbumsList({required this.isSearching, required this.query});

  @override
  Widget build(BuildContext context) {
    final albums = searchSignal.localSearchAlbums.value;
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final album = albums[index];
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
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.recordVinyl,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                    ),
                  ),
                ),
                title: Text(
                  album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${album.artist} · ${album.songCount} songs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                onTap: () => navigateGo(
                  context,
                  '/albums/${Uri.encodeComponent(album.artist)}/${Uri.encodeComponent(album.name)}',
                ),
              );
            },
            childCount: albums.length,
          ),
        ),
        if (albums.isEmpty && isSearching)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'No albums found',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        if (!isSearching)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'Start typing to search',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LocalArtistsList extends StatelessWidget {
  final bool isSearching;
  final String query;

  const _LocalArtistsList({required this.isSearching, required this.query});

  @override
  Widget build(BuildContext context) {
    final artists = searchSignal.localSearchArtists.value;
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final artist = artists[index];
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
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.userGroup,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                    ),
                  ),
                ),
                title: Text(
                  artist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${artist.songCount} songs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                onTap: () => navigateGo(
                  context,
                  '/artists/${Uri.encodeComponent(artist.name)}',
                ),
              );
            },
            childCount: artists.length,
          ),
        ),
        if (artists.isEmpty && isSearching)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'No artists found',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        if (!isSearching)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'Start typing to search',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LocalFoldersList extends StatelessWidget {
  final bool isSearching;
  final String query;

  const _LocalFoldersList({required this.isSearching, required this.query});

  @override
  Widget build(BuildContext context) {
    final folders = searchSignal.localSearchFolders.value;
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final folder = folders[index];
              final name = folder.split('/').last;
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
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.folder,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                    ),
                  ),
                ),
                title: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  folder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                onTap: () => navigateGo(context, AppRoutes.explorer),
              );
            },
            childCount: folders.length,
          ),
        ),
        if (folders.isEmpty && isSearching)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'No folders found',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        if (!isSearching)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'Start typing to search',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
