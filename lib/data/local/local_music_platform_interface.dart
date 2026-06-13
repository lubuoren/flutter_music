import '../models/track.dart';

abstract class LocalMusicPlatform {
  Future<String?> pickDirectory();

  Future<List<Track>> scanDirectory(String directoryPath);
}
