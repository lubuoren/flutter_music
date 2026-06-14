import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/data/models/lyric_source_marker.dart';
import 'package:flutter_music/data/models/track.dart';
import 'package:flutter_music/data/remote/netease/netease_music_repository.dart';

void main() {
  group('NeteaseMusicRepository', () {
    test('tracksFromSearchJson maps api-enhanced search songs', () {
      final tracks = NeteaseMusicRepository.tracksFromSearchJson({
        'code': 200,
        'result': {
          'songs': [
            {
              'id': 123,
              'name': 'Song',
              'dt': 245000,
              'ar': [
                {'id': 1, 'name': 'Artist A'},
                {'id': 2, 'name': 'Artist B'},
              ],
              'al': {'id': 9, 'name': 'Album', 'picUrl': 'https://cover'},
            },
          ],
        },
      });

      expect(tracks, hasLength(1));
      expect(tracks.single.id, '123');
      expect(tracks.single.title, 'Song');
      expect(tracks.single.artists, ['Artist A', 'Artist B']);
      expect(tracks.single.album, 'Album');
      expect(tracks.single.durationMs, 245000);
      expect(tracks.single.source, 'netease');
      expect(tracks.single.coverUrl, 'https://cover');
    });

    test('tracksFromSearchJson tolerates empty result', () {
      expect(NeteaseMusicRepository.tracksFromSearchJson({}), isEmpty);
      expect(
        NeteaseMusicRepository.tracksFromSearchJson({
          'result': {'songs': []},
        }),
        isEmpty,
      );
    });

    test('trackWithPlaybackUrlFromSongUrlJson maps matching song url', () {
      const track = Track(id: '123', title: 'Song', artists: ['Artist']);

      final playableTrack =
          NeteaseMusicRepository.trackWithPlaybackUrlFromSongUrlJson(track, {
            'code': 200,
            'data': [
              {'id': 999, 'url': 'https://other', 'time': 180000},
              {
                'id': 123,
                'url': 'http://audio.example/song.mp3',
                'time': 245000,
              },
            ],
          });

      expect(playableTrack.url, 'http://audio.example/song.mp3');
      expect(playableTrack.durationMs, 245000);
    });

    test('trackWithPlaybackUrlFromSongUrlJson keeps existing duration', () {
      const track = Track(
        id: '123',
        title: 'Song',
        artists: ['Artist'],
        durationMs: 123000,
      );

      final playableTrack =
          NeteaseMusicRepository.trackWithPlaybackUrlFromSongUrlJson(track, {
            'code': 200,
            'data': [
              {
                'id': 123,
                'url': 'https://audio.example/song.mp3',
                'time': 245000,
              },
            ],
          });

      expect(playableTrack.url, 'https://audio.example/song.mp3');
      expect(playableTrack.durationMs, 123000);
    });

    test('tracksWithPlaybackUrlsFromSongUrlJson maps batch song urls', () {
      const tracks = [
        Track(id: '123', title: 'Song A', artists: ['Artist']),
        Track(
          id: '456',
          title: 'Song B',
          artists: ['Artist'],
          durationMs: 180000,
        ),
      ];

      final playableTracks =
          NeteaseMusicRepository.tracksWithPlaybackUrlsFromSongUrlJson(tracks, {
            'code': 200,
            'data': [
              {'id': 456, 'url': 'https://audio.example/b.mp3', 'time': 200000},
              {'id': 123, 'url': 'https://audio.example/a.mp3', 'time': 245000},
            ],
          });

      expect(playableTracks[0].url, 'https://audio.example/a.mp3');
      expect(playableTracks[0].durationMs, 245000);
      expect(playableTracks[1].url, 'https://audio.example/b.mp3');
      expect(playableTracks[1].durationMs, 180000);
    });

    test('trackWithDetailFromSongDetailJson fills cloud cover metadata', () {
      const track = Track(id: '123', title: 'Old', artists: ['Old Artist']);

      final detailedTrack =
          NeteaseMusicRepository.trackWithDetailFromSongDetailJson(track, {
            'code': 200,
            'songs': [
              {
                'id': 123,
                'name': 'Song',
                'dt': 245000,
                'ar': [
                  {'name': 'Artist'},
                ],
                'al': {'name': 'Album', 'picUrl': 'https://cover'},
              },
            ],
          });

      expect(detailedTrack.title, 'Song');
      expect(detailedTrack.artists, ['Artist']);
      expect(detailedTrack.album, 'Album');
      expect(detailedTrack.durationMs, 245000);
      expect(detailedTrack.coverUrl, 'https://cover');
    });

    test('tracksWithDetailFromSongDetailJson fills cloud covers in batch', () {
      const tracks = [
        Track(id: '123', title: 'Old A', artists: ['Old Artist']),
        Track(id: '456', title: 'Old B', artists: ['Old Artist']),
      ];

      final detailedTracks =
          NeteaseMusicRepository.tracksWithDetailFromSongDetailJson(tracks, {
            'code': 200,
            'songs': [
              {
                'id': 456,
                'name': 'Song B',
                'dt': 180000,
                'ar': [
                  {'name': 'Artist B'},
                ],
                'al': {'name': 'Album B', 'picUrl': 'https://cover-b'},
              },
              {
                'id': 123,
                'name': 'Song A',
                'dt': 245000,
                'ar': [
                  {'name': 'Artist A'},
                ],
                'al': {'name': 'Album A', 'picUrl': 'https://cover-a'},
              },
            ],
          });

      expect(detailedTracks, hasLength(2));
      expect(detailedTracks[0].id, '123');
      expect(detailedTracks[0].title, 'Song A');
      expect(detailedTracks[0].coverUrl, 'https://cover-a');
      expect(detailedTracks[1].id, '456');
      expect(detailedTracks[1].title, 'Song B');
      expect(detailedTracks[1].coverUrl, 'https://cover-b');
    });

    test('lyricsFromLyricNewJson combines lrc and translation', () {
      final lyrics = NeteaseMusicRepository.lyricsFromLyricNewJson({
        'code': 200,
        'lrc': {'lyric': '[00:01.00]你好'},
        'tlyric': {'lyric': '[00:01.00]Hello'},
        'romalrc': {'lyric': ''},
      });

      expect(
        lyrics,
        [
          markLyricSource(lyricSourceMain),
          '[00:01.00]你好',
          markLyricSource(lyricSourceTranslation),
          '[00:01.00]Hello',
        ].join('\n'),
      );
    });

    test('lyricsFromLyricNewJson prefers yrc word lyric', () {
      final lyrics = NeteaseMusicRepository.lyricsFromLyricNewJson({
        'code': 200,
        'yrc': {'lyric': '[1000,2000](1000,500,0)你(1500,500,0)好'},
        'ytlrc': {'lyric': '[00:01.00]Hello'},
      });

      expect(
        lyrics,
        [
          markLyricSource(lyricSourceMain),
          '[1000,2000](1000,500,0)你(1500,500,0)好',
          markLyricSource(lyricSourceTranslation),
          '[00:01.00]Hello',
        ].join('\n'),
      );
    });
  });
}
