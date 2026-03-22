import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print("Usage: dart /tmp/test_audio_metadata.dart <path/to/audio/file>");
    return;
  }

  final path = args[0];
  final file = File(path);

  if (!await file.exists()) {
    print("File not found: $path");
    return;
  }

  print("Testing audio_metadata_reader for: $path");

  try {
    final reader = await file.open();
    try {
      if (ID3v2Parser.canUserParser(reader)) {
        print("\n--- ID3v2 Metadata ---");
        final mp3 = ID3v2Parser(fetchImage: true).parse(reader);
        _printMp3(mp3);
      } else if (FlacParser.canUserParser(reader)) {
        print("\n--- FLAC Metadata ---");
        final flac = FlacParser(fetchImage: true).parse(reader);
        _printFlac(flac);
      } else if (MP4Parser.canUserParser(reader)) {
        print("\n--- MP4 Metadata ---");
        final mp4 = MP4Parser(fetchImage: true).parse(reader);
        _printMp4(mp4);
      } else if (OGGParser.canUserParser(reader)) {
        print("\n--- OGG Metadata ---");
        final ogg = OGGParser(fetchImage: true).parse(reader);
        _printOgg(ogg);
      } else {
        print("\n--- Standard readMetadata ---");
        final meta = readMetadata(file, getImage: true);
        print("Title: ${meta.title}");
        print("Artist: ${meta.artist}");
        print("Album: ${meta.album}");
      }
    } finally {
      await reader.close();
    }
  } catch (e, stack) {
    print("Error: $e");
    print(stack);
  }
}

void _printMp3(dynamic mp3) {
  print("Title: ${mp3.songName}");
  print("Artist: ${mp3.bandOrOrchestra ?? mp3.leadPerformer}");
  print("Album: ${mp3.album}");
  print("Year: ${mp3.year}");
  print("Track: ${mp3.trackNumber} / ${mp3.trackTotal}");
  print("Disc: ${mp3.discNumber}");
  print("Duration: ${mp3.duration}");
  print("Pictures: ${mp3.pictures.length}");
  
  if (mp3.customMetadata != null) {
    print("\nReplayGain (TXXX):");
    final custom = mp3.customMetadata as Map;
    print("  Track Gain: ${custom['REPLAYGAIN_TRACK_GAIN'] ?? custom['replaygain_track_gain']}");
    print("  Track Peak: ${custom['REPLAYGAIN_TRACK_PEAK'] ?? custom['replaygain_track_peak']}");
    print("  Album Gain: ${custom['REPLAYGAIN_ALBUM_GAIN'] ?? custom['replaygain_album_gain']}");
    print("  Album Peak: ${custom['REPLAYGAIN_ALBUM_PEAK'] ?? custom['replaygain_album_peak']}");
  }
}


void _printFlac(dynamic flac) {
  print("Title: ${flac.title}");
  print("Artist: ${flac.artist}");
  print("Album: ${flac.album}");
  print("Date: ${flac.date}");
  print("Track: ${flac.trackNumber} / ${flac.trackTotal}");
  print("Duration: ${flac.duration}");
  print("Pictures: ${flac.pictures.length}");
  
  print("\nReplayGain (Vorbis):");
  print("  Track Gain: ${flac.replayGainTrackGain}");
  print("  Track Peak: ${flac.replayGainTrackPeak}");
  print("  Album Gain: ${flac.replayGainAlbumGain}");
  print("  Album Peak: ${flac.replayGainAlbumPeak}");
}


void _printMp4(dynamic mp4) {
  print("Title: ${mp4.title}");
  print("Artist: ${mp4.artist}");
  print("Album: ${mp4.album}");
  print("Year: ${mp4.year}");
  print("Duration: ${mp4.duration}");
}

void _printOgg(dynamic ogg) {
  print("Title: ${ogg.title}");
  print("Artist: ${ogg.artist}");
  print("Album: ${ogg.album}");
  print("Duration: ${ogg.duration}");
}

