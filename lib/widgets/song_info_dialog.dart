import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import '../models/song.dart';
import '../signals/settings_signal.dart';
import '../theme/app_theme_extensions.dart';

void showSongInfoDialog(BuildContext context, Song song) {
  showDialog(
    context: context,
    builder: (context) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: settingsSignal.enableGlobalBlur.value
                  ? ImageFilter.blur(sigmaX: 20, sigmaY: 20)
                  : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .extension<AppThemeExtension>()!
                      .sidebarBackground
                      .withValues(
                        alpha: settingsSignal.enableGlobalBlur.value ? 0.85 : 1.0,
                      ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 24,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Theme.of(context).colorScheme.secondary,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Song info',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Theme.of(context).colorScheme.secondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                              color: Theme.of(context).colorScheme.secondary,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: _SongInfoContent(song: song),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _SongInfoContent extends StatelessWidget {
  final Song song;

  const _SongInfoContent({required this.song});

  Future<Map<String, String>> _fetchInfo() async {
    final info = <String, String>{};

    info['Title'] = song.title;
    info['Artist'] = song.artist;
    if (song.album != null) info['Album'] = song.album!;

    if (song.path.startsWith('yt:')) {
      info['Source'] = 'YouTube';
      info['Video ID'] = song.path.substring(3);
    } else {
      info['Source'] = 'Local File';
      final file = File(song.path);
      info['File Path'] = song.path;
      if (file.existsSync()) {
        final sizeBytes = file.lengthSync();
        final sizeMb = sizeBytes / (1024 * 1024);
        info['File Size'] = '${sizeMb.toStringAsFixed(2)} MB';

        try {
          final metadata = readMetadata(file, getImage: false);
          
          if (metadata.title != null) info['Title'] = metadata.title!;
          if (metadata.artist != null) info['Artist'] = metadata.artist!;
          if (metadata.album != null) info['Album'] = metadata.album!;
          
          if (metadata.year != null) info['Year'] = metadata.year.toString();
          
          if (metadata.genres.isNotEmpty) {
            info['Genre'] = metadata.genres.join(', ');
          }
          if (metadata.trackNumber != null) {
            info['Track Number'] = metadata.trackNumber.toString();
          }
          if (metadata.discNumber != null) {
            info['Disc Number'] = metadata.discNumber.toString();
          }
          if (metadata.duration != null) {
            final d = metadata.duration!;
            final mins = d.inMinutes;
            final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
            info['Duration'] = '$mins:$secs';
          }
          if (metadata.bitrate != null) info['Bitrate'] = '${(metadata.bitrate! / 1000).round()} kbps';
        } catch (e) {
          info['Error'] = 'Could not read detailed metadata';
        }
      }
    }

    return info;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _fetchInfo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(48.0),
            child: CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('Error loading info', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          );
        }

        final info = snapshot.data!;
        return ListView.separated(
          shrinkWrap: true,
          itemCount: info.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          separatorBuilder: (_, __) => Divider(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
            height: 1,
          ),
          itemBuilder: (context, index) {
            final key = info.keys.elementAt(index);
            final val = info.values.elementAt(index);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    key,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                        ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    val,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
