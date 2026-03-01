import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../signals/settings_signal.dart';
import '../../signals/audio_signal.dart';
import '../../widgets/subpage_header.dart';

class LibrarySection extends StatelessWidget {
  const LibrarySection({super.key});

  bool get _isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  @override
  Widget build(BuildContext context) {
    final topPadding = _isDesktop
        ? 50.0
        : 64.0 + MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: EdgeInsets.only(top: 24.0 + topPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const SubpageHeader(title: 'Library'),
                  const SizedBox(height: 24),

                  // Music Sources
                  _sectionLabel('Music Sources', context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.8),
                      surfaceTintColor: Theme.of(context).colorScheme.secondary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.1),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // Current directory
                          Watch((context) {
                            final currentDir =
                                settingsSignal.musicDirectory.value;
                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.secondary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(36),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.folder,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                    size: 20,
                                  ),
                                ),
                              ),
                              title: Text(
                                'Music Directory',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: FutureBuilder<String>(
                                future: audioSignal.getMusicPath(),
                                builder: (context, snapshot) {
                                  return Text(
                                    snapshot.data ?? 'Loading...',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.54),
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                              trailing: currentDir != null
                                  ? IconButton(
                                      onPressed: () async {
                                        await settingsSignal
                                            .updateMusicDirectory(null);
                                        audioSignal.reindexLibrary();
                                      },
                                      icon: Icon(
                                        Icons.restore,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.54),
                                      ),
                                      tooltip: 'Reset to default',
                                    )
                                  : null,
                              onTap: () => _pickDirectory(context),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                            );
                          }),

                          // Change folder button
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 16,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => _pickDirectory(context),
                                icon: Icon(Icons.folder_open, size: 18),
                                label: Text('Change Folder'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(36),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Indexing section
                  _sectionLabel('Indexing', context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.8),
                      surfaceTintColor: Theme.of(context).colorScheme.secondary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.1),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Watch((context) {
                        final isScanning = audioSignal.isScanning.value;
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.secondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(36),
                            ),
                            child: Center(
                              child: isScanning
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Watch((context) {
                                        final progress =
                                            audioSignal.scanProgress.value;
                                        return Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              value: progress,
                                              strokeWidth: 2,
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .secondary
                                                  .withValues(alpha: 0.2),
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.secondary,
                                            ),
                                            Text(
                                              '${(progress * 100).round()}',
                                              style: TextStyle(
                                                fontSize: 7,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.secondary,
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    )
                                  : Icon(
                                      Icons.refresh,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                      size: 20,
                                    ),
                            ),
                          ),
                          title: Text(
                            isScanning ? 'Indexing...' : 'Re-index Songs',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            isScanning
                                ? 'Scanning your music directory'
                                : 'Scan for new or changed music files',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.54),
                              fontSize: 12,
                            ),
                          ),
                          onTap: isScanning
                              ? null
                              : () => audioSignal.reindexLibrary(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sidebar customization
                  _sectionLabel('Sidebar', context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.8),
                      surfaceTintColor: Theme.of(context).colorScheme.secondary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.1),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Watch((context) {
                        final pinnedItems =
                            settingsSignal.pinnedSidebarItems.value;
                        final allItems = [
                          {
                            'id': 'albums',
                            'label': 'Albums',
                            'icon': Icons.album,
                          },
                          {
                            'id': 'songs',
                            'label': 'Songs',
                            'icon': Icons.audiotrack,
                          },
                          {
                            'id': 'playlists',
                            'label': 'Playlists',
                            'icon': Icons.list,
                          },
                          {
                            'id': 'folders',
                            'label': 'Folders',
                            'icon': Icons.folder,
                          },
                          {
                            'id': 'artists',
                            'label': 'Artists',
                            'icon': Icons.person,
                          },
                          {
                            'id': 'downloaded',
                            'label': 'Downloaded',
                            'icon': Icons.download_done,
                          },
                        ];

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Toggle items that appear in your sidebar library section.',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.54),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: allItems.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1, indent: 56),
                              itemBuilder: (context, index) {
                                final item = allItems[index];
                                final itemId = item['id'] as String;
                                final isPinned = pinnedItems.contains(itemId);

                                return CheckboxListTile(
                                  value: isPinned,
                                  onChanged: (value) =>
                                      settingsSignal.togglePinnedItem(itemId),
                                  title: Text(
                                    item['label'] as String,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  secondary: Icon(
                                    item['icon'] as IconData,
                                    color: isPinned
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.secondary
                                        : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.38),
                                    size: 20,
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.trailing,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Watch(
                    (context) =>
                        SizedBox(height: audioSignal.reservedHeight.value),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _pickDirectory(BuildContext context) async {
    final String? selectedDirectory = await FilePicker.platform
        .getDirectoryPath(dialogTitle: 'Select Music Directory');

    if (selectedDirectory != null) {
      await settingsSignal.updateMusicDirectory(selectedDirectory);
      audioSignal.reindexLibrary();
    }
  }
}
