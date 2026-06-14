import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/explore/presentation/pages/explore_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/library/presentation/pages/library_page.dart';
import '../../features/local_music/presentation/pages/local_music_page.dart';
import '../../features/login/presentation/pages/login_page.dart';
import '../../features/mv/presentation/pages/mv_page.dart';
import '../../features/playlist/presentation/pages/playlist_page.dart';
import '../../features/player/presentation/pages/player_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/stream/presentation/pages/stream_login_page.dart';
import '../../features/stream/presentation/pages/stream_page.dart';
import '../../features/user/presentation/pages/user_page.dart';
import '../../features/album/presentation/pages/album_page.dart';
import '../../features/artist/presentation/pages/artist_page.dart';
import '../../features/artist/presentation/pages/artist_mv_page.dart';
import '../../features/comments/presentation/pages/comments_page.dart';
import '../../features/player/presentation/pages/next_up_page.dart';
import '../shell/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (context, state) =>
                    _transitionPage(state, const HomePage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                pageBuilder: (context, state) =>
                    _transitionPage(state, const ExplorePage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                pageBuilder: (context, state) =>
                    _transitionPage(state, const LibraryPage()),
              ),
              GoRoute(
                path: '/library/liked-songs',
                pageBuilder: (context, state) => _transitionPage(
                  state,
                  PlaylistPage(
                    playlistId: 'liked-songs',
                    title: '我喜欢的音乐',
                    source: 'local',
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/localMusic',
                pageBuilder: (context, state) =>
                    _transitionPage(state, const LocalMusicPage()),
              ),
              GoRoute(
                path: '/localPlaylist/:id',
                pageBuilder: (context, state) => _transitionPage(
                  state,
                  PlaylistPage(
                    playlistId: state.pathParameters['id'],
                    title: '本地歌单',
                    source: 'local',
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) =>
                    _transitionPage(state, const SettingsPage()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/stream',
        pageBuilder: (context, state) =>
            _playerBarPage(state, const StreamPage()),
      ),
      GoRoute(
        path: '/streamLogin/:service',
        pageBuilder: (_, state) => _playerBarPage(
          state,
          StreamLoginPage(service: state.pathParameters['service'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/streamPlaylist/:service/:id',
        pageBuilder: (context, state) => _playerBarPage(
          state,
          PlaylistPage(
            playlistId: state.pathParameters['id'],
            title: '${state.pathParameters['service']} 歌单',
            source: 'stream',
          ),
        ),
      ),
      GoRoute(
        path: '/stream-liked-songs/:service',
        pageBuilder: (context, state) => _playerBarPage(
          state,
          PlaylistPage(
            playlistId: 'stream-${state.pathParameters['service']}-liked-songs',
            title: '${state.pathParameters['service']} 喜欢的音乐',
            source: 'stream',
          ),
        ),
      ),
      GoRoute(
        path: '/playlist/:id',
        pageBuilder: (context, state) => _playerBarPage(
          state,
          PlaylistPage(
            playlistId: state.pathParameters['id'],
            title: '歌单',
            source: 'netease',
          ),
        ),
      ),
      GoRoute(
        path: '/daily/songs',
        pageBuilder: (context, state) => _playerBarPage(
          state,
          const PlaylistPage(
            playlistId: 'daily-songs',
            title: '每日推荐',
            source: 'netease',
          ),
        ),
      ),
      GoRoute(
        path: '/login/account',
        pageBuilder: (context, state) =>
            _playerBarPage(state, const LoginPage()),
      ),
      GoRoute(
        path: '/album/:id',
        pageBuilder: (context, state) => _playerBarPage(
          state,
          AlbumPage(albumId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/artist/:id',
        pageBuilder: (context, state) => _playerBarPage(
          state,
          ArtistPage(artistId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/artist/:id/mv',
        pageBuilder: (context, state) => _playerBarPage(
          state,
          ArtistMvPage(artistId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) =>
            _playerBarPage(state, const SearchPage()),
      ),
      GoRoute(
        path: '/user/:id',
        pageBuilder: (context, state) =>
            _playerBarPage(state, UserPage(userId: state.pathParameters['id'])),
      ),
      GoRoute(
        path: '/mv/:id',
        pageBuilder: (context, state) =>
            _playerBarPage(state, MvPage(mvId: state.pathParameters['id'])),
      ),
      GoRoute(
        path: '/next',
        pageBuilder: (context, state) =>
            _playerBarPage(state, const NextUpPage()),
      ),
      GoRoute(
        path: '/comments/:resourceType/:id',
        pageBuilder: (context, state) => _playerBarPage(
          state,
          CommentsPage(
            resourceType: state.pathParameters['resourceType'] ?? 'track',
            resourceId: state.pathParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: '/player/lyrics',
        pageBuilder: (context, state) =>
            _transitionPage(state, const PlayerLyricsPage()),
      ),
      GoRoute(
        path: '/player',
        pageBuilder: (context, state) =>
            _transitionPage(state, const PlayerPage()),
      ),
      GoRoute(path: '/:pathMatch(.*)*', redirect: (context, state) => '/'),
    ],
  );
});

CustomTransitionPage<void> _playerBarPage(GoRouterState state, Widget child) {
  return _transitionPage(state, PlayerBarRouteScaffold(child: child));
}

CustomTransitionPage<void> _transitionPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.025, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}
