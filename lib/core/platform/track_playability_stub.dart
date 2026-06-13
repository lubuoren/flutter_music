import '../../data/models/track.dart';

bool canPlayTrack(Track track) {
  final url = track.url?.trim();
  return url != null && url.isNotEmpty;
}
