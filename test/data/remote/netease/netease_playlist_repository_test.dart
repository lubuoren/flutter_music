import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/data/models/track.dart';
import 'package:flutter_music/data/remote/netease/netease_playlist_repository.dart';

void main() {
  group('NeteasePlaylistRepository', () {
    test('playlistsFromUserPlaylistJson maps cloud playlist summaries', () {
      final playlists = NeteasePlaylistRepository.playlistsFromUserPlaylistJson(
        {
          'code': 200,
          'playlist': [
            {
              'id': 123,
              'name': 'Daily Mix',
              'description': 'Cloud playlist',
              'coverImgUrl': 'https://cover',
              'trackCount': 42,
              'subscribed': true,
              'createTime': 1710000000000,
              'updateTime': 1710100000000,
              'creator': {'userId': 99, 'nickname': 'User'},
            },
          ],
        },
      );

      expect(playlists, hasLength(1));
      expect(playlists.single.id, '123');
      expect(playlists.single.name, 'Daily Mix');
      expect(playlists.single.description, 'Cloud playlist');
      expect(playlists.single.coverUrl, 'https://cover');
      expect(playlists.single.trackCount, 42);
      expect(playlists.single.source, 'netease');
      expect(playlists.single.creatorUserId, '99');
      expect(playlists.single.creatorName, 'User');
      expect(playlists.single.subscribed, isTrue);
      expect(playlists.single.createdAt?.millisecondsSinceEpoch, 1710000000000);
      expect(playlists.single.updatedAt?.millisecondsSinceEpoch, 1710100000000);
    });

    test('playlistFromDetailJson maps metadata and supplied tracks', () {
      const tracks = [
        Track(id: '1', title: 'Song A', artists: ['Artist A']),
        Track(id: '2', title: 'Song B', artists: ['Artist B']),
      ];

      final playlist = NeteasePlaylistRepository.playlistFromDetailJson({
        'code': 200,
        'playlist': {
          'id': '456',
          'name': 'Full List',
          'coverImgUrl': 'https://cover',
          'trackCount': 2,
          'creator': {'userId': '100', 'nickname': 'Creator'},
        },
      }, tracks: tracks);

      expect(playlist.id, '456');
      expect(playlist.name, 'Full List');
      expect(playlist.creatorName, 'Creator');
      expect(playlist.tracks, tracks);
      expect(playlist.trackCount, 2);
    });

    test('playlistFromPlaylistJson normalizes netease cover urls', () {
      final httpPlaylist = NeteasePlaylistRepository.playlistFromPlaylistJson({
        'id': 1,
        'name': 'HTTP Cover',
        'coverImgUrl': 'http://p1.music.126.net/cover.jpg',
      });
      final protocolRelativePlaylist =
          NeteasePlaylistRepository.playlistFromPlaylistJson({
            'id': 2,
            'name': 'Protocol Relative Cover',
            'coverImgUrl': '//p2.music.126.net/cover.jpg',
          });

      expect(httpPlaylist.coverUrl, 'https://p1.music.126.net/cover.jpg');
      expect(
        protocolRelativePlaylist.coverUrl,
        'https://p2.music.126.net/cover.jpg',
      );
    });

    test('playlistFromPlaylistJson reads nested cover fallbacks', () {
      final playlist = NeteasePlaylistRepository.playlistFromPlaylistJson({
        'id': 3,
        'name': 'Nested Cover',
        'socialPlaylistCover': {
          'coverUrl': 'http://p3.music.126.net/nested.jpg',
        },
      });

      expect(playlist.coverUrl, 'https://p3.music.126.net/nested.jpg');
    });

    test('tracksFromPlaylistJson maps embedded playlist tracks', () {
      final tracks = NeteasePlaylistRepository.tracksFromPlaylistJson({
        'tracks': [
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

      expect(tracks, hasLength(1));
      expect(tracks.single.id, '123');
      expect(tracks.single.title, 'Song');
      expect(tracks.single.artists, ['Artist']);
      expect(tracks.single.album, 'Album');
      expect(tracks.single.coverUrl, 'https://cover');
    });

    test('trackIdsFromPlaylistJson tolerates map and scalar ids', () {
      final ids = NeteasePlaylistRepository.trackIdsFromPlaylistJson({
        'trackIds': [
          {'id': 123},
          '456',
          789,
          {'id': ''},
        ],
      });

      expect(ids, ['123', '456', '789']);
    });

    test('dailyTracksFromRecommendJson maps data.dailySongs', () {
      final tracks = NeteasePlaylistRepository.dailyTracksFromRecommendJson({
        'code': 200,
        'data': {
          'dailySongs': [
            {
              'id': 555,
              'name': 'Daily Song',
              'dt': 200000,
              'ar': [
                {'name': 'Daily Artist'},
              ],
              'al': {
                'name': 'Daily Album',
                'picUrl': 'http://p1.music.126.net/x.jpg',
              },
            },
          ],
        },
      });

      expect(tracks, hasLength(1));
      expect(tracks.single.id, '555');
      expect(tracks.single.title, 'Daily Song');
      expect(tracks.single.artists, ['Daily Artist']);
      expect(tracks.single.album, 'Daily Album');
      expect(tracks.single.source, 'netease');
      expect(tracks.single.type, TrackType.online);
      // 封面 http 应被归一化为 https。
      expect(tracks.single.coverUrl, 'https://p1.music.126.net/x.jpg');
    });

    test('dailyTracksFromRecommendJson returns empty when missing', () {
      expect(
        NeteasePlaylistRepository.dailyTracksFromRecommendJson({'code': 200}),
        isEmpty,
      );
    });
  });
}
