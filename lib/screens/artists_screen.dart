import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../widgets/page_header.dart';

class ArtistsScreen extends StatelessWidget {
  const ArtistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final artists = audioSignal.artists.value;

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Artists',
                subtitle: '${artists.length} artists',
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final artist = artists[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: Container(
                        width: 50,
                        height: 50,
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
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        artist.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${artist.songCount} songs • ${artist.albums.length} albums',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => context.go('/artists/${Uri.encodeComponent(artist.name)}'),
                    );
                  },
                  childCount: artists.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: audioSignal.reservedHeight.value),
            ),
          ],
        ),
      );
    });
  }
}
