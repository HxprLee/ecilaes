import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../widgets/sliver_page_header.dart';
import '../widgets/standard_sliver_list.dart';
import '../widgets/standard_sliver_grid.dart';
import '../models/library_models.dart';

class ArtistsScreen extends StatelessWidget {
  const ArtistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final artists = audioSignal.artists.value;
      final isGrid = audioSignal.isArtistsGridView.value;

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            SliverPageHeader(
              title: 'Artists',
              subtitle: '${artists.length} artists',
              actions: [
                IconButton(
                  onPressed: () => audioSignal.isArtistsGridView.value = !isGrid,
                  icon: FaIcon(
                    isGrid ? FontAwesomeIcons.list : FontAwesomeIcons.borderAll,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 18,
                  ),
                ),
              ],
            ),
            if (isGrid)
              StandardSliverGrid<Artist>(
                items: artists,
                childAspectRatio: 0.8,
                itemBuilder: (context, artist, index) {
                  return GestureDetector(
                    onTap: () => context.go(
                      '/artists/${Uri.encodeComponent(artist.name)}',
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              image: artist.picturePath != null
                                  ? DecorationImage(
                                      image: FileImage(File(artist.picturePath!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: artist.picturePath == null
                                ? Center(
                                    child: FaIcon(
                                      FontAwesomeIcons.user,
                                      size: 32,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            artist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            '${artist.songCount} songs',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
            else
              StandardSliverList<Artist>(
                items: artists,
                emptyMessage: 'No artists found',
                itemBuilder: (context, artist, index) {
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 24,
                  ),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      image: artist.picturePath != null
                          ? DecorationImage(
                              image: FileImage(File(artist.picturePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: artist.picturePath == null
                        ? Center(
                            child: FaIcon(
                              FontAwesomeIcons.user,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                            ),
                          )
                        : null,
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
                    '${artist.songCount} songs • ${artist.albums.length} albums',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                  onTap: () => context.go('/artists/${Uri.encodeComponent(artist.name)}'),
                );
              },
            ),
          ],
        ),
      );
    });
  }
}
