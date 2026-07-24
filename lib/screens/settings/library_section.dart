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

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/settings_signal.dart';
import '../../signals/audio_signal.dart';
import '../../signals/overlay_signal.dart';
import '../../router/routes.dart';
import '../../services/YoutubeDatasource.dart';
import '../../theme/app_theme_tokens.dart';
import '../../utils/navigation.dart';
import '../../widgets/components/app_dialog.dart';
import '../../widgets/components/settings_section.dart';
import '../../widgets/components/sliver_page_header.dart';

class LibrarySection extends StatelessWidget {
  const LibrarySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          const SliverPageHeader(title: 'Library', maxWidth: 600),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Storage Management
                    const SettingsSectionLabel('Storage Management'),
                    SettingsSection(
                      child: SignalBuilder(builder: (context) {
                        final dir = settingsSignal.musicDirectory.value;
                        final stats = audioSignal.storageStats.value;
                        final count = stats['count'] as int;
                        final size = stats['size'] as int;
                        final isScanning = audioSignal.isScanning.value;
                        final isDefaultDir = dir == null;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                16,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.folder_outlined,
                                    size: 16,
                                    color: context.colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      dir ?? audioSignal.defaultMusicPath,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                spacing: 32,
                                children: [
                                  _storageStatItem(
                                    context,
                                    Icons.audiotrack_outlined,
                                    'Songs',
                                    count.toString(),
                                  ),
                                  _storageStatItem(
                                    context,
                                    Icons.storage_outlined,
                                    'Storage',
                                    _formatSize(size),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
                              child: _DirectoryActionRow(
                                primaryLabel: isDefaultDir ? 'Change' : 'Reset',
                                primaryIcon: isDefaultDir
                                    ? Icons.edit_outlined
                                    : Icons.restart_alt,
                                onPrimary: isDefaultDir
                                    ? () => _pickDirectory(context)
                                    : () => _confirmResetDirectory(context),
                                secondaryLabel: isScanning
                                    ? 'Indexing...'
                                    : 'Re-index',
                                secondaryIcon: Icons.refresh,
                                onSecondary: isScanning
                                    ? null
                                    : () => audioSignal.reindexLibrary(),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),

                    const SizedBox(height: 24),

                    // Maintenance
                    const SettingsSectionLabel('Maintenance'),
                    SettingsSection(
                      child: Column(
                        children: [
                          SettingsTile(
                            icon: Icons.cleaning_services_outlined,
                            title: 'Clear Missing Files',
                            subtitle:
                                'Remove non-existent files from your library',
                            onTap: () => _confirmClearMissing(context),
                          ),
                          const SettingsDivider(indent: 16),
                          SettingsTile(
                            icon: Icons.auto_fix_high_outlined,
                            title: 'Force Full Scan',
                            subtitle:
                                'Re-index everything and refresh all metadata',
                            onTap: () => _confirmForceScan(context),
                          ),
                          const SettingsDivider(indent: 16),
                          SettingsTile(
                            icon: Icons.storage_outlined,
                            title: 'Manage Caches',
                            subtitle: 'Clear cached metadata, art, and lyrics',
                            onTap: () {
                              debugPrint(
                                'MANAGE_CACHES: pushing /settings/library/manage_cache',
                              );
                              navigatePush(
                                context,
                                AppRoutes.settingsLibraryManageCache,
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Exclusions
                    const SettingsSectionLabel('Exclusions'),
                    SettingsSection(
                      child: SignalBuilder(builder: (context) {
                        final excluded = settingsSignal.excludedPaths.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (excluded.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'No excluded files or folders.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: excluded.length,
                                separatorBuilder: (context, index) =>
                                    const SettingsDivider(indent: 16),
                                itemBuilder: (context, index) {
                                  final stored = excluded[index];
                                  final isFile = stored.startsWith('f:');
                                  final path = stored.substring(2);
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isFile
                                              ? Icons.description_outlined
                                              : Icons.folder_off_outlined,
                                          size: 20,
                                          color: context.colorScheme.onSurface
                                              .withValues(alpha: 0.54),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                path.split('/').last,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                path,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            size: 20,
                                          ),
                                          onPressed: () => settingsSignal
                                              .removeExcludedPath(stored),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            const SettingsDivider(indent: 16),
                            SettingsTile(
                              icon: Icons.add_circle_outline,
                              title: 'Add Exclusion',
                              onTap: () => _pickExclusion(context),
                            ),
                          ],
                        );
                      }),
                    ),
                    SignalBuilder(builder: (context) =>
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

  Future<void> _pickDirectory(BuildContext context) async {
    final String? selectedDirectory = await getDirectoryPath(
        confirmButtonText: 'Select Music Directory');

    if (selectedDirectory != null) {
      await settingsSignal.updateMusicDirectory(selectedDirectory);
      audioSignal.reindexLibrary();
    }
  }

  void _confirmResetDirectory(BuildContext context) {
    overlaySignal.push(ActiveOverlay.resetDirectoryConfirm);

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => AppDialog(
        titleIcon: Icon(
          Icons.folder_off_outlined,
          color: context.colorScheme.secondary,
        ),
        title: 'Reset Music Directory',
        content: const Text(
          'This will clear the music directory setting. Your library will remain unchanged until you pick a new folder or trigger a re-index. Continue?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              overlaySignal.pop(ActiveOverlay.resetDirectoryConfirm);
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: context.colorScheme.secondary.withValues(alpha: 0.2),
              ),
              shape: const StadiumBorder(),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.colorScheme.secondary),
            ),
          ),
          FilledButton(
            onPressed: () async {
              overlaySignal.pop(ActiveOverlay.resetDirectoryConfirm);
              Navigator.pop(context);
              await settingsSignal.updateMusicDirectory(null);
            },
            style: FilledButton.styleFrom(
              backgroundColor: context.colorScheme.secondary,
              foregroundColor: context.colorScheme.surface,
              shape: const StadiumBorder(),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickExclusion(BuildContext context) async {
    final files = await openFiles(
      confirmButtonText: 'Select Files or Folders to Exclude',
    );

    if (files.isNotEmpty) {
      for (final file in files) {
        await settingsSignal.addExcludedPath(file.path);
      }
    }
  }

  void _confirmClearMissing(BuildContext context) {
    overlaySignal.push(ActiveOverlay.clearMissingConfirm);

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => AppDialog(
        titleIcon: Icon(
          Icons.cleaning_services_outlined,
          color: context.colorScheme.secondary,
        ),
        title: 'Clear Missing Files',
        content: const Text(
          'This will remove all songs from your library that no longer exist on your disk. Continue?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              overlaySignal.pop(ActiveOverlay.clearMissingConfirm);
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: context.colorScheme.secondary.withValues(alpha: 0.2),
              ),
              shape: const StadiumBorder(),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.colorScheme.secondary),
            ),
          ),
          FilledButton(
            onPressed: () {
              overlaySignal.pop(ActiveOverlay.clearMissingConfirm);
              Navigator.pop(context);
              audioSignal.clearMissingFiles();
            },
            style: FilledButton.styleFrom(
              backgroundColor: context.colorScheme.secondary,
              foregroundColor: context.colorScheme.surface,
              shape: const StadiumBorder(),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _confirmForceScan(BuildContext context) {
    overlaySignal.push(ActiveOverlay.forceScanConfirm);

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => AppDialog(
        titleIcon: Icon(Icons.refresh, color: context.colorScheme.secondary),
        title: 'Force Full Scan',
        content: const Text(
          'This will clear your library cache and perform a complete search of your music directory. This may take a while. Continue?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              overlaySignal.pop(ActiveOverlay.forceScanConfirm);
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: context.colorScheme.secondary.withValues(alpha: 0.2),
              ),
              shape: const StadiumBorder(),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.colorScheme.secondary),
            ),
          ),
          FilledButton(
            onPressed: () {
              overlaySignal.pop(ActiveOverlay.forceScanConfirm);
              Navigator.pop(context);
              audioSignal.reindexLibrary();
            },
            style: FilledButton.styleFrom(
              backgroundColor: context.colorScheme.secondary,
              foregroundColor: context.colorScheme.surface,
              shape: const StadiumBorder(),
            ),
            child: const Text('Scan'),
          ),
        ],
      ),
    );
  }

  Widget _storageStatItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: context.colorScheme.secondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: context.colorScheme.onSurface.withValues(alpha: 0.54),
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
            color: context.colorScheme.onSurface,
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

class _YtAuthDialog extends StatefulWidget {
  const _YtAuthDialog();

  @override
  State<_YtAuthDialog> createState() => _YtAuthDialogState();
}

class _YtAuthDialogState extends State<_YtAuthDialog> {
  final _cookieController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _cookieController.dispose();
    super.dispose();
  }

  void _submit() async {
    final cookie = _cookieController.text.trim();
    if (cookie.isEmpty) return;

    if (cookie.contains('…') || cookie.contains('...')) {
      setState(() {
        _error =
            'Cookie is truncated. Please copy the entire string, not just the visible part.';
      });
      return;
    }

    // Strip out any non-ascii characters that might crash the HTTP client
    final sanitizedCookie = cookie.replaceAll(RegExp(r'[^\x20-\x7E]'), '');

    // Fetch account name in the background so we can store it
    String? username;
    try {
      // Temporarily set the cookie so getAccountName can use it
      await settingsSignal.updateYtAuthCookie(sanitizedCookie);
      final datasource = YoutubeDatasource();
      username = await datasource.getAccountName();
    } catch (_) {}

    await settingsSignal.updateYtAuthCookie(
      sanitizedCookie,
      username: username,
    );
    audioSignal.reindexLibrary();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'YouTube Music Login',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'To access your personalized YouTube Music library, you must provide your authentication cookie.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Go to music.youtube.com in your browser and log in.\n'
            '2. Open Developer Tools (F12) -> Network tab.\n'
            '3. Refresh the page, click on any request to music.youtube.com.\n'
            '4. Scroll down to Request Headers, copy the entire value of "cookie".',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cookieController,
            decoration: InputDecoration(
              labelText: 'Cookie String',
              border: const OutlineInputBorder(),
              isDense: true,
              errorText: _error,
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _DirectoryActionRow extends StatelessWidget {
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final VoidCallback? onSecondary;

  const _DirectoryActionRow({
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.secondaryIcon,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: onPrimary,
              icon: Icon(primaryIcon, size: 18),
              label: Text(primaryLabel),
              style: FilledButton.styleFrom(
                backgroundColor: context.colorScheme.secondary.withValues(
                  alpha: 0.8,
                ),
                foregroundColor: context.colorScheme.surface,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onSecondary,
              icon: Icon(secondaryIcon, size: 18),
              label: Text(secondaryLabel),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: context.colorScheme.secondary.withValues(alpha: 0.2),
                ),
                shape: const StadiumBorder(),
                foregroundColor: context.colorScheme.onSurface.withValues(
                  alpha: 0.7,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
