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
                    const NoTransitionPage(child: HomePage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ExplorePage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: LibraryPage()),
              ),
              GoRoute(
                path: '/library/liked-songs',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: PlaylistPage(
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
                    const NoTransitionPage(child: LocalMusicPage()),
              ),
              GoRoute(
                path: '/localPlaylist/:id',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: PlaylistPage(
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
                    const NoTransitionPage(child: SettingsPage()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/stream',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: StreamPage()),
      ),
      GoRoute(
        path: '/streamLogin/:service',
        pageBuilder: (_, state) => NoTransitionPage(
          child: StreamLoginPage(
            service: state.pathParameters['service'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/streamPlaylist/:service/:id',
        pageBuilder: (context, state) => NoTransitionPage(
          child: PlaylistPage(
            playlistId: state.pathParameters['id'],
            title: '${state.pathParameters['service']} 歌单',
            source: 'stream',
          ),
        ),
      ),
      GoRoute(
        path: '/stream-liked-songs/:service',
        pageBuilder: (context, state) => NoTransitionPage(
          child: PlaylistPage(
            playlistId: 'stream-${state.pathParameters['service']}-liked-songs',
            title: '${state.pathParameters['service']} 喜欢的音乐',
            source: 'stream',
          ),
        ),
      ),
      GoRoute(
        path: '/playlist/:id',
        pageBuilder: (context, state) => NoTransitionPage(
          child: PlaylistPage(
            playlistId: state.pathParameters['id'],
            title: '歌单',
            source: 'netease',
          ),
        ),
      ),
      GoRoute(
        path: '/daily/songs',
        pageBuilder: (context, state) => NoTransitionPage(
          child: PlaylistPage(
            playlistId: 'daily-songs',
            title: '每日推荐',
            source: 'netease',
          ),
        ),
      ),
      GoRoute(
        path: '/login/account',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginPage()),
      ),
      GoRoute(
        path: '/album/:id',
        pageBuilder: (context, state) => NoTransitionPage(
          child: AlbumPage(albumId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/artist/:id',
        pageBuilder: (context, state) => NoTransitionPage(
          child: ArtistPage(artistId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/artist/:id/mv',
        pageBuilder: (context, state) => NoTransitionPage(
          child: ArtistMvPage(artistId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SearchPage()),
      ),
      GoRoute(
        path: '/user/:id',
        pageBuilder: (context, state) => NoTransitionPage(
          child: UserPage(userId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/mv/:id',
        pageBuilder: (context, state) =>
            NoTransitionPage(child: MvPage(mvId: state.pathParameters['id'])),
      ),
      GoRoute(
        path: '/next',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: NextUpPage()),
      ),
      GoRoute(
        path: '/comments/:resourceType/:id',
        pageBuilder: (context, state) => NoTransitionPage(
          child: CommentsPage(
            resourceType: state.pathParameters['resourceType'] ?? 'track',
            resourceId: state.pathParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: '/player/lyrics',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: PlayerLyricsPage()),
      ),
      GoRoute(
        path: '/player',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: PlayerPage()),
      ),
      GoRoute(path: '/:pathMatch(.*)*', redirect: (context, state) => '/'),
    ],
  );
});
