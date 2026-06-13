import 'dart:io';

import '../../data/models/track.dart';

bool canPlayTrack(Track track) {
  final filePath = track.filePath;
  if (filePath != null && filePath.isNotEmpty) {
    return File(filePath).existsSync();
  }

  final url = track.url?.trim();
  return url != null && url.isNotEmpty;
}
