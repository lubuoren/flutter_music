import '../../data/models/track.dart';

bool canPlayTrack(Track track) {
  final url = track.url?.trim();
  if (url == null || url.isEmpty) {
    return false;
  }

  final uri = Uri.tryParse(url);
  return uri != null &&
      (uri.scheme == 'http' ||
          uri.scheme == 'https' ||
          uri.scheme == 'blob' ||
          uri.scheme == 'data');
}
