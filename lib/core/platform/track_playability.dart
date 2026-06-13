import '../../data/models/track.dart';
import 'track_playability_stub.dart'
    if (dart.library.io) 'track_playability_io.dart'
    if (dart.library.js_interop) 'track_playability_web.dart'
    as impl;

bool canPlayTrack(Track track) {
  return impl.canPlayTrack(track);
}
