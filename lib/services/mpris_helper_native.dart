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

import 'dart:developer' as developer;

import 'dart:io';
import 'package:audio_service_mpris/mpris.dart';
import 'package:audio_service_mpris/metadata.dart';
import 'package:audio_service_platform_interface/audio_service_platform_interface.dart';
import 'package:dbus/dbus.dart';

/// Linux-only: register the MPRIS D-Bus object so that GNOME Shell media
/// controls, KDE Plasma, playerctl, and other MPRIS clients can see and
/// control playback.
///
/// This is the Linux implementation. On other platforms [mpris_helper.dart]
/// provides a no-op stub.
// Public (not library-private) so the conditional import in
// `mpris_helper.dart` can resolve it on platforms where dart:io is
// available. We still gate the actual registration on Platform.isLinux
// because dart:io is also present on Android/iOS where D-Bus does not
// exist — without this guard, AudioService.init() would hang on those
// platforms trying to connect to a non-existent session bus.
void registerMprisPlatformImpl() {
  if (!Platform.isLinux) return;
  developer.log('Registering EcilaesMprisService', name: 'ecilaes.mpris');
  EcilaesMprisService.registerWith();
}

/// Extended MPRIS D-Bus object that fixes [doSeek] to forward the seek
/// request to the audio handler instead of being a no-op.
class _EcilaesMprisPlayer extends OrgMprisMediaPlayer2 {
  _EcilaesMprisPlayer({required super.identity})
      : super(
          path: DBusObjectPath('/org/mpris/MediaPlayer2'),
        );

  @override
  Future<DBusMethodResponse> doSeek(int offset) async {
    developer.log('MPRIS Seek offset=$offset', name: 'ecilaes.mpris');
    // MPRIS Seek() is relative — add offset to current position.
    final newPosition = position + Duration(microseconds: offset);
    position = newPosition;
    await emitSeeked(newPosition);
    // Forward to the audio handler so playback actually scrubs.
    _seekCallback?.call(newPosition);
    return DBusMethodSuccessResponse([]);
  }

  void Function(Duration)? _seekCallback;

  void setSeekCallback(void Function(Duration) cb) {
    _seekCallback = cb;
  }
}

/// AudioServicePlatform implementation that wires MPRIS D-Bus into audio_service.
/// Fixes two issues in the original audio_service_mpris:
/// 1. doSeek() now forwards seek to the audio handler (GNOME/KDE/playerctl scrubbing works)
/// 2. playPause now defaults to play instead of crashing on an uninitialized flag
class EcilaesMprisService extends AudioServicePlatform {
  late final DBusClient _dBusClient;
  late final _EcilaesMprisPlayer _mpris;
  AudioHandlerCallbacks? _handlerCallbacks;

  void _listenToOpenUriStream() {
    _mpris.openUriStream.listen((uri) {
      if (_handlerCallbacks == null) return;
      _handlerCallbacks!.playFromUri(PlayFromUriRequest(uri: uri));
    });
  }

  void _listenToSeekStream() {
    _mpris.positionStream.listen((position) {
      if (_handlerCallbacks == null) return;
      _handlerCallbacks!.seek(SeekRequest(position: position));
    });
  }

  void _listenToControlStream() {
    _mpris.controlStream.listen((event) {
      if (_handlerCallbacks == null) return;

      switch (event) {
        case 'play':
          _handlerCallbacks!.play(const PlayRequest());
        case 'pause':
          _handlerCallbacks!.pause(const PauseRequest());
        case 'next':
          _handlerCallbacks!.skipToNext(const SkipToNextRequest());
        case 'previous':
          _handlerCallbacks!.skipToPrevious(const SkipToPreviousRequest());
        case 'playPause':
          _handlerCallbacks!.play(const PlayRequest());
      }
    });
  }

  void _listenToVolumeStream() {
    _mpris.volumeStream.listen((value) {
      if (_handlerCallbacks == null) return;
      final req = CustomActionRequest(
          name: 'dbusVolume', extras: {'value': value});
      _handlerCallbacks!.customAction(req);
    });
  }

  static void registerWith() {
    AudioServicePlatform.instance = EcilaesMprisService();
  }

  @override
  Future<void> configure(ConfigureRequest request) async {
    _dBusClient = DBusClient.session();
    _mpris = _EcilaesMprisPlayer(
      identity: request.config.androidNotificationChannelName,
    );

    // Wire doSeek to the handler via seek callback.
    _mpris.setSeekCallback((position) {
      _handlerCallbacks?.seek(SeekRequest(position: position));
    });

    _listenToControlStream();
    _listenToSeekStream();
    _listenToOpenUriStream();
    _listenToVolumeStream();

    await _dBusClient.registerObject(_mpris);
    await _dBusClient.requestName(
      'org.mpris.MediaPlayer2.${request.config.androidNotificationChannelId}.instance$pid',
      flags: {DBusRequestNameFlag.doNotQueue},
    );
  }

  @override
  Future<void> setState(SetStateRequest request) async {
    _mpris.position = request.state.updatePosition;
    _mpris.playbackState =
        request.state.playing ? 'Playing' : 'Paused';
  }

  @override
  Future<void> setQueue(SetQueueRequest request) async {}

  @override
  Future<void> setMediaItem(SetMediaItemRequest request) async {
    List<String>? artist;
    if (request.mediaItem.artist != null) {
      artist = [request.mediaItem.artist!];
    }

    List<String>? genre;
    if (request.mediaItem.genre != null) {
      genre = [request.mediaItem.genre!];
    }

    _mpris.metadata = Metadata(
      title: request.mediaItem.title,
      length: request.mediaItem.duration,
      artist: artist,
      artUrl: request.mediaItem.artUri.toString(),
      album: request.mediaItem.album,
      genre: genre,
    );
  }

  @override
  Future<void> stopService(StopServiceRequest request) async {
    _mpris.playbackState = 'Stopped';
  }

  @override
  Future<void> notifyChildrenChanged(
      NotifyChildrenChangedRequest request) async {}

  @override
  void setHandlerCallbacks(AudioHandlerCallbacks callbacks) {
    _handlerCallbacks = callbacks;
  }
}
