import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../signals/settings_signal.dart';
import '../../signals/audio_signal.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/sliver_page_header.dart';

class LibrarySection extends StatelessWidget {
  const LibrarySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          const SliverPageHeader(
            title: 'Library',
            maxWidth: 600,
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                      ).colorScheme.onSurface.withValues(alpha: 0.54),
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
                                            .withValues(alpha: 0.54),
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

                  // Storage Management
                  _sectionLabel('Storage Management', context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                      surfaceTintColor: Theme.of(context).colorScheme.secondary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Watch((context) {
                        final stats = audioSignal.storageStats.value;
                        final count = stats['count'] as int;
                        final size = stats['size'] as int;

                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              _storageStatItem(
                                context,
                                Icons.audiotrack_outlined,
                                'Songs',
                                count.toString(),
                              ),
                              const SizedBox(width: 32),
                              _storageStatItem(
                                context,
                                Icons.storage_outlined,
                                'Storage',
                                _formatSize(size),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Indexing
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

                  // Maintenance
                  _sectionLabel('Maintenance', context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                      surfaceTintColor: Theme.of(context).colorScheme.secondary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.cleaning_services_outlined, size: 20, color: Theme.of(context).colorScheme.secondary),
                            title: const Text('Clear Missing Files', style: TextStyle(fontSize: 14)),
                            subtitle: const Text('Remove non-existent files from your library', style: TextStyle(fontSize: 12)),
                            onTap: () => _confirmClearMissing(context),
                          ),
                          const Divider(height: 1, indent: 56),
                          ListTile(
                            leading: Icon(Icons.auto_fix_high_outlined, size: 20, color: Theme.of(context).colorScheme.secondary),
                            title: const Text('Force Full Scan', style: TextStyle(fontSize: 14)),
                            subtitle: const Text('Re-index everything and refresh all metadata', style: TextStyle(fontSize: 12)),
                            onTap: () => _confirmForceScan(context),
                          ),
                          const Divider(height: 1, indent: 56),
                          ListTile(
                            leading: Icon(Icons.storage_outlined, size: 20, color: Theme.of(context).colorScheme.secondary),
                            title: const Text('Manage Caches', style: TextStyle(fontSize: 14)),
                            subtitle: const Text('Clear cached metadata, art, and lyrics', style: TextStyle(fontSize: 12)),
                            onTap: () => context.push('/settings/cache'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Exclusions
                  _sectionLabel('Exclusions', context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                      surfaceTintColor: Theme.of(context).colorScheme.secondary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Watch((context) {
                        final excluded = settingsSignal.excludedPaths.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (excluded.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'No excluded folders or files.',
                                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: excluded.length,
                                separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
                                itemBuilder: (context, index) {
                                  final path = excluded[index];
                                  return ListTile(
                                    leading: Icon(
                                      path.contains('.') ? Icons.description_outlined : Icons.folder_off_outlined,
                                      size: 20,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                    ),
                                    title: Text(
                                      path.split('/').last,
                                      style: const TextStyle(fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(path, style: const TextStyle(fontSize: 10)),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                                      onPressed: () => settingsSignal.removeExcludedPath(path),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                  );
                                },
                              ),
                            const Divider(height: 1),
                            ListTile(
                              leading: Icon(Icons.add_circle_outline, size: 20, color: Theme.of(context).colorScheme.secondary),
                              title: const Text('Add Exclusion', style: TextStyle(fontSize: 14)),
                              onTap: () => _pickExclusion(context),
                            ),
                          ],
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
                                  ).colorScheme.onSurface.withValues(alpha: 0.54),
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
        ],
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

  Future<void> _pickExclusion(BuildContext context) async {
    // Show a dialog to choose between Folder or File
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AppDialog(
        titleIcon: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.secondary),
        title: 'Add Exclusion',
        content: const Text(
          'Do you want to exclude a folder or a specific file?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'file'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
              ),
              shape: const StadiumBorder(),
            ),
            child: Text(
              'File',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'folder'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.surface,
              shape: const StadiumBorder(),
            ),
            child: const Text('Folder'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    String? path;
    if (choice == 'folder') {
      path = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select Folder to Exclude');
    } else {
      final result = await FilePicker.platform.pickFiles(dialogTitle: 'Select File to Exclude');
      path = result?.files.single.path;
    }

    if (path != null) {
      await settingsSignal.addExcludedPath(path);
    }
  }

  void _confirmClearMissing(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AppDialog(
        titleIcon: Icon(Icons.cleaning_services_outlined, color: Theme.of(context).colorScheme.secondary),
        title: 'Clear Missing Files',
        content: const Text(
          'This will remove all songs from your library that no longer exist on your disk. Continue?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
              ),
              shape: const StadiumBorder(),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              audioSignal.clearMissingFiles();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.surface,
              shape: const StadiumBorder(),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _confirmForceScan(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AppDialog(
        titleIcon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.secondary),
        title: 'Force Full Scan',
        content: const Text(
          'This will clear your library cache and perform a complete search of your music directory. This may take a while. Continue?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
              ),
              shape: const StadiumBorder(),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              audioSignal.reindexLibrary();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.surface,
              shape: const StadiumBorder(),
            ),
            child: const Text('Scan'),
          ),
        ],
      ),
    );
  }

  Widget _storageStatItem(BuildContext context, IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }
}
