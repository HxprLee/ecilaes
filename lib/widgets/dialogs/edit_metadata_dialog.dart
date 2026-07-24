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
import 'package:file_selector/file_selector.dart';
import '../../models/song.dart';
import '../../signals/audio_signal.dart';
import '../../signals/overlay_signal.dart';
import '../../services/song_cache.dart';
import '../components/app_dialog.dart';
import '../components/app_toast.dart';

class EditMetadataDialog extends StatefulWidget {
  final Song song;

  const EditMetadataDialog({super.key, required this.song});

  static void show(BuildContext context, {required Song song}) {
    overlaySignal.push(ActiveOverlay.editMetadata);

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => EditMetadataDialog(song: song),
    );
  }

  @override
  State<EditMetadataDialog> createState() => _EditMetadataDialogState();
}

class _EditMetadataDialogState extends State<EditMetadataDialog> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _albumController;

  String? _newImagePath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(text: widget.song.artist);
    _albumController = TextEditingController(text: widget.song.album ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    const typeGroup = XTypeGroup(
      label: 'Images',
      extensions: ['jpg', 'jpeg', 'png'],
    );
    final XFile? result = await openFile(
      acceptedTypeGroups: [typeGroup],
      confirmButtonText: 'Select Image',
    );
    if (result != null) {
      setState(() {
        _newImagePath = result.path;
      });
    }
  }

  Future<void> _saveMetadata() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await audioSignal.updateSongMetadata(
        widget.song.path,
        title: _titleController.text.trim(),
        artist: _artistController.text.trim(),
        album: _albumController.text.trim(),
        imagePath: _newImagePath,
      );

      if (mounted) {
        overlaySignal.pop(ActiveOverlay.editMetadata);
        Navigator.pop(context, true);
        ToastService.show(
          'Metadata saved!',
          variant: AppToastVariant.success,
        );
      }
    } catch (e) {
      if (mounted) {
        ToastService.show(
          'Error saving metadata: $e',
          variant: AppToastVariant.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      titleIcon: Icon(
        Icons.edit_outlined,
        color: Theme.of(context).colorScheme.secondary,
        size: 24,
      ),
      title: 'Edit info',
      maxWidth: 440,
      maxHeight: 700,
      actions: [
        OutlinedButton(
          onPressed: _isSaving
              ? null
              : () {
                  overlaySignal.pop(ActiveOverlay.editMetadata);
                  Navigator.pop(context);
                },
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.2),
            ),
            shape: const StadiumBorder(),
          ),
          child: Text(
            'Cancel',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _saveMetadata,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.8),
            foregroundColor: Theme.of(context).colorScheme.surface,
            shape: const StadiumBorder(),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    image: _newImagePath != null
                        ? DecorationImage(
                            image: FileImage(File(_newImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _newImagePath == null
                      ? widget.song.hasAlbumArt
                            ? FutureBuilder<File>(
                                future: SongCache.getAlbumArtFile(
                                  widget.song.path,
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData &&
                                      snapshot.data!.existsSync()) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        snapshot.data!,
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  }
                                  return _buildPlaceholder();
                                },
                              )
                            : _buildPlaceholder()
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _artistController,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
              decoration: InputDecoration(
                labelText: 'Artist',
                labelStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _albumController,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
              decoration: InputDecoration(
                labelText: 'Album',
                labelStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 40,
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Change cover',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.6),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
