import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/track.dart';
import 'local_music_platform_interface.dart';

LocalMusicPlatform createLocalMusicPlatform() {
  return LocalMusicPlatformIo();
}

class LocalMusicPlatformIo implements LocalMusicPlatform {
  @override
  Future<String?> pickDirectory() async {
    await _requestStoragePermission();
    return FilePicker.platform.getDirectoryPath(dialogTitle: '选择本地音乐目录');
  }

  @override
  Future<List<Track>> scanDirectory(String directoryPath) async {
    await _requestStoragePermission();
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      throw FileSystemException('目录不存在', directoryPath);
    }

    final files = await compute(_collectAudioFiles, directoryPath);
    final tracks = <Track>[];
    for (final path in files) {
      final track = await _readTrack(File(path));
      if (track != null) {
        tracks.add(track);
      }
    }
    return tracks;
  }

  Future<void> _requestStoragePermission() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return;
    }

    final audioStatus = await Permission.audio.request();
    if (audioStatus.isGranted || audioStatus.isLimited) {
      return;
    }

    final storageStatus = await Permission.storage.request();
    if (!storageStatus.isGranted && !storageStatus.isLimited) {
      throw StateError('未获得本地音乐读取权限');
    }
  }

  Future<Track?> _readTrack(File file) async {
    try {
      final metadata = readMetadata(file, getImage: true);
      final title = _clean(metadata.title) ?? _filenameWithoutExtension(file);
      final artists = _artistsFromMetadata(
        metadata.artist,
        metadata.performers,
      );
      final coverPath = await _persistCover(file, metadata.pictures);
      final lyrics = _clean(metadata.lyrics) ?? await _readSidecarLyrics(file);

      return Track(
        id: sha1.convert(utf8.encode(file.absolute.path)).toString(),
        title: title,
        artists: artists,
        album: _clean(metadata.album),
        durationMs: metadata.duration?.inMilliseconds ?? 0,
        type: TrackType.local,
        source: 'localTrack',
        filePath: file.absolute.path,
        coverUrl: coverPath,
        url: file.absolute.uri.toString(),
        lyrics: lyrics,
        fileSizeBytes: file.lengthSync(),
        matched: false,
        addedAt: DateTime.now(),
        md5: lyrics == null
            ? null
            : sha1.convert(utf8.encode(lyrics)).toString(),
      );
    } on Object {
      return Track(
        id: sha1.convert(utf8.encode(file.absolute.path)).toString(),
        title: _filenameWithoutExtension(file),
        artists: const ['未知艺术家'],
        type: TrackType.local,
        source: 'localTrack',
        filePath: file.absolute.path,
        url: file.absolute.uri.toString(),
        fileSizeBytes: file.existsSync() ? file.lengthSync() : null,
        addedAt: DateTime.now(),
      );
    }
  }

  Future<String?> _persistCover(File audioFile, List<Picture> pictures) async {
    if (pictures.isEmpty) {
      return _findSidecarCover(audioFile);
    }

    final picture = pictures.firstWhere(
      (item) => item.pictureType == PictureType.coverFront,
      orElse: () => pictures.first,
    );
    final extension = switch (picture.mimetype.toLowerCase()) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      _ => '.jpg',
    };
    final cacheDirectory = await getApplicationSupportDirectory();
    final coverDirectory = Directory(p.join(cacheDirectory.path, 'covers'));
    await coverDirectory.create(recursive: true);
    final filename =
        '${sha1.convert(utf8.encode(audioFile.absolute.path))}$extension';
    final coverFile = File(p.join(coverDirectory.path, filename));
    if (!coverFile.existsSync()) {
      await coverFile.writeAsBytes(picture.bytes, flush: true);
    }
    return coverFile.path;
  }

  Future<String?> _readSidecarLyrics(File audioFile) async {
    final lyricFile = File(p.setExtension(audioFile.path, '.lrc'));
    if (!lyricFile.existsSync()) {
      return null;
    }
    return lyricFile.readAsString();
  }

  String? _findSidecarCover(File audioFile) {
    final directory = audioFile.parent;
    const names = [
      'cover.jpg',
      'cover.jpeg',
      'cover.png',
      'folder.jpg',
      'folder.jpeg',
      'folder.png',
    ];
    for (final name in names) {
      final file = File(p.join(directory.path, name));
      if (file.existsSync()) {
        return file.path;
      }
    }
    return null;
  }

  List<String> _artistsFromMetadata(String? artist, List<String> performers) {
    final values = [
      if (_clean(artist) != null) _clean(artist)!,
      ...performers.map(_clean).whereType<String>(),
    ];
    if (values.isEmpty) {
      return const ['未知艺术家'];
    }
    return values
        .expand((value) => value.split(RegExp(r'\s*(?:/|;|,|、)\s*')))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  String _filenameWithoutExtension(File file) {
    return p.basenameWithoutExtension(file.path);
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}

List<String> _collectAudioFiles(String directoryPath) {
  final directory = Directory(directoryPath);
  final extensions = supportedFileExtensions.toSet();
  final files = <String>[];

  for (final entity in directory.listSync(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) {
      continue;
    }
    final extension = p.extension(entity.path).toLowerCase();
    if (extensions.contains(extension)) {
      files.add(entity.path);
    }
  }

  files.sort();
  return files;
}
