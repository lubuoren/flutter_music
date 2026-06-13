import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/local/local_music_repository.dart';
import '../../../../data/models/playlist.dart';
import '../../../../data/models/track.dart';
import '../../../player/application/player_controller.dart';
import '../../../../widgets/md3/section_header.dart';
import '../../../../widgets/md3/track_tile.dart';
import '../../application/local_playlist_controller.dart';

class PlaylistPage extends ConsumerStatefulWidget {
  const PlaylistPage({
    super.key,
    required this.playlistId,
    required this.title,
  });

  final String? playlistId;
  final String title;

  @override
  ConsumerState<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends ConsumerState<PlaylistPage> {
  @override
  Widget build(BuildContext context) {
    final playlistId = widget.playlistId;

    // 本地歌单
    final localId = playlistId;
    if (localId != null && localId.startsWith('local-')) {
      return _LocalPlaylistView(
        playlistId: localId,
        title: widget.title,
      );
    }

    // 喜欢歌曲（来自本地数据）
    if (playlistId == 'liked-songs') {
      return const _LikedSongsView();
    }

    // 其他（网易云歌单、每日推荐、流媒体歌单等）— 占位
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.queue_music_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '此歌单需要在线音乐能力（Phase 4）',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '网易云 / 流媒体将在后续版本接入',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// 本地歌单详情视图。
class _LocalPlaylistView extends ConsumerStatefulWidget {
  const _LocalPlaylistView({required this.playlistId, required this.title});

  final String playlistId;
  final String title;

  @override
  ConsumerState<_LocalPlaylistView> createState() =>
      _LocalPlaylistViewState();
}

class _LocalPlaylistViewState extends ConsumerState<_LocalPlaylistView> {
  final TextEditingController _renameController = TextEditingController();

  @override
  void dispose() {
    _renameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playlistState = ref.watch(localPlaylistControllerProvider);
    final playlist = playlistState.playlists
        .where((p) => p.id == widget.playlistId)
        .firstOrNull;

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: Text('歌单不存在或已被删除')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: '重命名',
            onPressed: () => _showRenameDialog(context, playlist),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: '删除歌单',
            onPressed: () => _confirmDelete(context, playlist),
          ),
        ],
      ),
      body: playlist.tracks.isEmpty
          ? _EmptyPlaylistBody(playlistId: playlist.id)
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                M3SectionHeader(
                  title: playlist.name,
                  actionLabel: '${playlist.trackCount} 首歌曲',
                ),
                if (playlist.description != null &&
                    playlist.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: Text(
                      playlist.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                for (var i = 0; i < playlist.tracks.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TrackTile(
                      track: _toTileData(playlist.tracks[i]),
                      onTap: () => ref
                          .read(musicPlayerControllerProvider.notifier)
                          .playQueue(playlist.tracks, startIndex: i),
                      trailing: IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: '移出歌单',
                        onPressed: () => ref
                            .read(localPlaylistControllerProvider.notifier)
                            .removeTrack(playlist.id, playlist.tracks[i].id),
                      ),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
      floatingActionButton: playlist.tracks.isEmpty
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('播放全部'),
              onPressed: () => ref
                  .read(musicPlayerControllerProvider.notifier)
                  .playQueue(playlist.tracks),
            ),
    );
  }

  void _showRenameDialog(BuildContext context, Playlist playlist) {
    _renameController.text = playlist.name;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重命名歌单'),
          content: TextField(
            controller: _renameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: '输入新名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final newName = _renameController.text.trim();
                if (newName.isNotEmpty) {
                  ref
                      .read(localPlaylistControllerProvider.notifier)
                      .renamePlaylist(playlist.id, newName);
                }
                Navigator.pop(context);
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Playlist playlist) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除歌单'),
          content: Text('确定要删除歌单「${playlist.name}」吗？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                ref
                    .read(localPlaylistControllerProvider.notifier)
                    .deletePlaylist(playlist.id);
                Navigator.pop(context);
                Navigator.pop(this.context);
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }
}

/// 本地喜欢的歌曲视图。
class _LikedSongsView extends ConsumerWidget {
  const _LikedSongsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localState = ref.watch(localMusicControllerProvider);
    final likedTracks =
        localState.tracks.where((t) => t.isLiked).toList();

    if (likedTracks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('我喜欢的音乐')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_border_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                '还没有喜欢的歌曲',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '在本地音乐页面点喜欢后，歌曲会出现在这里',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('我喜欢的音乐')),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: likedTracks.length,
        itemBuilder: (context, index) {
          final track = likedTracks[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TrackTile(
              track: _toTileData(track),
              onTap: () => ref
                  .read(musicPlayerControllerProvider.notifier)
                  .playQueue(likedTracks, startIndex: index),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('播放全部'),
        onPressed: () => ref
            .read(musicPlayerControllerProvider.notifier)
            .playQueue(likedTracks),
      ),
    );
  }
}

class _EmptyPlaylistBody extends StatelessWidget {
  const _EmptyPlaylistBody({required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '歌单是空的',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '在本地音乐页面通过歌曲菜单添加歌曲',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

TrackTileData _toTileData(Track track) {
  return TrackTileData(
    id: track.id,
    title: track.title,
    subtitle: track.artists.join(' / '),
    duration: track.durationMs == 0 ? null : track.duration,
    coverPath: track.coverUrl,
  );
}
