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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../models/song.dart';
import '../models/library_models.dart';
import '../widgets/components/sliver_page_header.dart';
import '../widgets/components/song_list_view.dart';
import '../widgets/song_actions_sheet.dart';
import '../widgets/components/song_tile.dart';
import '../widgets/components/standard_sliver_grid.dart';
import '../widgets/components/song_grid_card.dart';

class ArtistDetailScreen extends StatefulWidget {
  final String artistName;

  const ArtistDetailScreen({super.key, required this.artistName});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  @override
  void initState() {
    super.initState();
    _updateHeaderArt();
  }

  @override
  void dispose() {
    audioSignal.headerArtCover.value = null;
    super.dispose();
  }

  void _updateHeaderArt() {
    final artists = audioSignal.artists.value;
    final artist = artists.firstWhere(
      (a) => a.name == widget.artistName,
      orElse: () => Artist(name: widget.artistName, songs: []),
    );

    if (artist.songs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        audioSignal.headerArtCover.value = artist.songs.first.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final artists = audioSignal.artists.value;
        final artist = artists.firstWhere(
          (a) => a.name == widget.artistName,
          orElse: () => Artist(name: widget.artistName, songs: []),
        );

        final artDir = audioSignal.albumArtDir.value;
        final firstSongWithArt = artist.songs.firstWhere(
          (s) => s.path.isNotEmpty,
          orElse: () =>
              artist.songs.isNotEmpty ? artist.songs.first : Song.fromPath(''),
        );
        final artPath = firstSongWithArt.path.isNotEmpty
            ? SongTile.getArtPath(firstSongWithArt.path, artDir)
            : '';

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: CustomScrollView(
            slivers: [
              SliverPageHeader(
                title: artist.name,
                subtitle:
                    '${artist.songCount} songs • ${artist.albums.length} albums',
                actions: [
                  IconButton(
                    onPressed: () => audioSignal.isArtistDetailGridView.value =
                        !audioSignal.isArtistDetailGridView.value,
                    icon: FaIcon(
                      audioSignal.isArtistDetailGridView.value
                          ? FontAwesomeIcons.list
                          : FontAwesomeIcons.borderAll,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 18,
                    ),
                  ),
                ],
                leading: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    image: artist.picturePath != null
                        ? DecorationImage(
                            image: ResizeImage(
                              FileImage(File(artist.picturePath!)),
                              width: 240,
                            ),
                            fit: BoxFit.cover,
                          )
                        : (artPath.isNotEmpty && File(artPath).existsSync()
                              ? DecorationImage(
                                  image: ResizeImage(
                                    FileImage(File(artPath)),
                                    width: 240,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child:
                      (artist.picturePath == null &&
                          (artPath.isEmpty || !File(artPath).existsSync()))
                      ? Center(
                          child: FaIcon(
                            FontAwesomeIcons.user,
                            size: 48,
                            color: Theme.of(
                              context,
                            ).colorScheme.secondary.withValues(alpha: 0.5),
                          ),
                        )
                      : null,
                ),
                underTextActions: [
                  ElevatedButton.icon(
                    onPressed: () => audioSignal.playSong(
                      artist.songs.first,
                      fromList: artist.songs,
                    ),
                    icon: const FaIcon(FontAwesomeIcons.play, size: 14),
                    label: const Text('Play'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      shape: const StadiumBorder(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () =>
                        audioSignal.playShuffledFromList(artist.songs),
                    style: OutlinedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                      side: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: FaIcon(
                      FontAwesomeIcons.shuffle,
                      size: 14,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
                backgroundImage:
                    (artist.picturePath != null &&
                        File(artist.picturePath!).existsSync())
                    ? FileImage(File(artist.picturePath!))
                    : (artPath.isNotEmpty && File(artPath).existsSync()
                          ? FileImage(File(artPath))
                          : null),
              ),

              // Songs Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 12.0,
                  ),
                  child: Text(
                    audioSignal.isArtistDetailGridView.value
                        ? 'Songs'
                        : 'Popular Songs',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),

              // Songs List/Grid
              if (audioSignal.isArtistDetailGridView.value)
                StandardSliverGrid<Song>(
                  items: artist.songs,
                  childAspectRatio: 0.8,
                  itemBuilder: (context, song, index) {
                    return SongGridCard(
                      song: song,
                      artPath: SongTile.getArtPath(song.path, artDir),
                      onTap: () =>
                          audioSignal.playSong(song, fromList: artist.songs),
                    );
                  },
                )
              else
                SongListView(
                  songs: artist.songs,
                  showIndex: false,
                  addBottomPadding: false,
                  trailingBuilder: (context, song, index) => IconButton(
                    onPressed: () =>
                        showSongMoreActionsSheet(context: context, song: song),
                    icon: FaIcon(
                      FontAwesomeIcons.ellipsisVertical,
                      size: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: SizedBox(height: audioSignal.reservedHeight.value),
              ),
            ],
          ),
        );
      },
    );
  }
}
