import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/track.dart';

final lyricOffsetRepositoryProvider = Provider<LyricOffsetRepository>((ref) {
  return LyricOffsetRepository();
});

class LyricOffsetRepository {
  static const _prefix = 'lyric_offsets.v1';

  Future<double> loadOffset(Track track) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getDouble(_key(track)) ?? track.offset;
  }

  Future<Track> applyOffset(Track track) async {
    final offset = await loadOffset(track);
    return track.copyWith(offset: offset);
  }

  Future<List<Track>> applyOffsets(List<Track> tracks) async {
    final preferences = await SharedPreferences.getInstance();
    return [
      for (final track in tracks)
        track.copyWith(
          offset: preferences.getDouble(_key(track)) ?? track.offset,
        ),
    ];
  }

  Future<void> saveOffset(Track track, double offset) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_key(track), offset);
  }

  String _key(Track track) {
    final source = track.source?.trim();
    final namespace = source == null || source.isEmpty
        ? track.type.name
        : source;
    return '$_prefix.$namespace.${track.id}';
  }
}
