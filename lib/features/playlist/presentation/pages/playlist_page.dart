import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/platform/cover_image_provider.dart';
import '../../../../data/local/local_music_repository.dart';
import '../../../../data/models/playlist.dart';
import '../../../../data/models/track.dart';
import '../../../player/application/player_controller.dart';
import '../../../../widgets/md3/section_header.dart';
import '../../../../widgets/md3/track_tile.dart';
import '../../application/local_playlist_controller.dart';
import '../../application/netease_playlist_controller.dart';

class PlaylistPage extends ConsumerStatefulWidget {
  const PlaylistPage({
    super.key,
    required this.playlistId,
    required this.title,
    this.source,
  });

  final String? playlistId;
  final String title;
  final String? source;

  @override
  ConsumerState<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends ConsumerState<PlaylistPage> {
  @override
  Widget build(BuildContext context) {
    final playlistId = widget.playlistId;
    final source = widget.source ?? _sourceFromPlaylistId(playlistId);

    // 喜欢歌曲（来自本地数据）
    if (playlistId == 'liked-songs') {
      return const _LikedSongsView();
    }

    // 本地歌单
    final localId = playlistId;
    if (source == 'local' && localId != null && localId.startsWith('local-')) {
      return _LocalPlaylistView(playlistId: localId, title: widget.title);
    }

    // 网易云歌单详情
    if (source == 'netease' &&
        playlistId != null &&
        playlistId.isNotEmpty &&
        playlistId != 'daily-songs') {
      return _NeteasePlaylistView(
        playlistId: playlistId,
        fallbackTitle: widget.title,
      );
    }

    // 其他（每日推荐、流媒体歌单等）— 占位
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.queue_music_rounded,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              source == 'stream' ? '此歌单需要流媒体能力（Phase 5）' : '此歌单需要推荐接口接入',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              source == 'stream'
                  ? 'Navidrome / Jellyfin / Emby 将在后续版本接入'
                  : '每日推荐将在后续版本接入',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _sourceFromPlaylistId(String? playlistId) {
    if (playlistId == null) {
      return 'netease';
    }
    if (playlistId == 'liked-songs' || playlistId.startsWith('local-')) {
      return 'local';
    }
    if (playlistId.startsWith('stream-')) {
      return 'stream';
    }
    return 'netease';
  }
}

/// 本地歌单详情视图。
class _LocalPlaylistView extends ConsumerStatefulWidget {
  const _LocalPlaylistView({required this.playlistId, required this.title});

  final String playlistId;
  final String title;

  @override
  ConsumerState<_LocalPlaylistView> createState() => _LocalPlaylistViewState();
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
    final likedTracks = localState.tracks.where((t) => t.isLiked).toList();

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
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text('还没有喜欢的歌曲', style: Theme.of(context).textTheme.titleMedium),
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

/// 网易云歌单详情视图。
class _NeteasePlaylistView extends ConsumerStatefulWidget {
  const _NeteasePlaylistView({
    required this.playlistId,
    required this.fallbackTitle,
  });

  final String playlistId;
  final String fallbackTitle;

  @override
  ConsumerState<_NeteasePlaylistView> createState() =>
      _NeteasePlaylistViewState();
}

class _NeteasePlaylistViewState extends ConsumerState<_NeteasePlaylistView> {
  late final TextEditingController _searchController;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = neteasePlaylistDetailControllerProvider(widget.playlistId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final playlist = state.playlist;

    ref.listen(provider.select((state) => state.playbackErrorMessage), (
      previous,
      next,
    ) {
      if (next != null && next != previous && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next)));
      }
    });

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(playlist?.name ?? widget.fallbackTitle),
            actions: [
              if (playlist != null)
                IconButton(
                  icon: const Icon(Icons.comment_rounded),
                  tooltip: '评论',
                  onPressed: () =>
                      context.push('/comments/playlist/${playlist.id}'),
                ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: '刷新歌单',
                onPressed: state.isLoading ? null : controller.refresh,
              ),
            ],
          ),
          if (state.isLoading && playlist == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.errorMessage != null && playlist == null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _PlaylistMessage(
                icon: Icons.cloud_off_rounded,
                title: '歌单加载失败',
                subtitle: state.errorMessage!,
                actionLabel: '重试',
                onAction: controller.refresh,
              ),
            )
          else if (playlist == null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _PlaylistMessage(
                icon: Icons.queue_music_rounded,
                title: '未获取到歌单',
                subtitle: '请确认歌单 ID 是否正确',
                actionLabel: '返回',
                onAction: () => Navigator.maybePop(context),
              ),
            )
          else ...[
            if (state.isLoading)
              const SliverToBoxAdapter(child: LinearProgressIndicator()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              sliver: SliverToBoxAdapter(
                child: _NeteasePlaylistHeader(
                  playlist: playlist,
                  searchController: _searchController,
                  isResolvingQueue: state.isResolvingQueue,
                  onPlayAll: playlist.tracks.isEmpty || state.isResolvingQueue
                      ? null
                      : controller.playAll,
                  onComment: () =>
                      context.push('/comments/playlist/${playlist.id}'),
                  onSearchChanged: (value) {
                    setState(() {
                      _keyword = value.trim();
                    });
                  },
                ),
              ),
            ),
            if (playlist.tracks.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _PlaylistMessage(
                  icon: Icons.music_off_rounded,
                  title: '歌单暂无歌曲',
                  subtitle: '这个云端歌单没有返回可展示的歌曲',
                ),
              )
            else
              _NeteaseTrackListSliver(
                playlist: playlist,
                keyword: _keyword,
                resolvingTrackId: state.resolvingTrackId,
                isResolvingQueue: state.isResolvingQueue,
                onPlayTrack: controller.playFromIndex,
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ],
      ),
      floatingActionButton: playlist == null || playlist.tracks.isEmpty
          ? null
          : FloatingActionButton.extended(
              icon: state.isResolvingQueue
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(state.isResolvingQueue ? '解析中' : '播放全部'),
              onPressed: state.isResolvingQueue ? null : controller.playAll,
            ),
    );
  }
}

class _NeteasePlaylistHeader extends StatelessWidget {
  const _NeteasePlaylistHeader({
    required this.playlist,
    required this.searchController,
    required this.isResolvingQueue,
    required this.onPlayAll,
    required this.onComment,
    required this.onSearchChanged,
  });

  final Playlist playlist;
  final TextEditingController searchController;
  final bool isResolvingQueue;
  final VoidCallback? onPlayAll;
  final VoidCallback onComment;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final cover = _PlaylistCover(
          coverUrl: playlist.coverUrl,
          size: isWide ? 220 : 168,
        );
        final info = _PlaylistInfo(
          playlist: playlist,
          searchController: searchController,
          isResolvingQueue: isResolvingQueue,
          onPlayAll: onPlayAll,
          onComment: onComment,
          onSearchChanged: onSearchChanged,
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cover,
              const SizedBox(width: 24),
              Expanded(child: info),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [cover, const SizedBox(height: 18), info],
        );
      },
    );
  }
}

class _PlaylistInfo extends StatelessWidget {
  const _PlaylistInfo({
    required this.playlist,
    required this.searchController,
    required this.isResolvingQueue,
    required this.onPlayAll,
    required this.onComment,
    required this.onSearchChanged,
  });

  final Playlist playlist;
  final TextEditingController searchController;
  final bool isResolvingQueue;
  final VoidCallback? onPlayAll;
  final VoidCallback onComment;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final description = playlist.description?.trim();
    final creator = playlist.creatorName?.trim();
    final trackCount = playlist.trackCount == 0
        ? playlist.tracks.length
        : playlist.trackCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(playlist.name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          [
            '歌单',
            if (creator != null && creator.isNotEmpty) 'by $creator',
          ].join(' '),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '${_formatPlaylistDate(playlist.updatedAt)} · $trackCount 首歌曲',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showDescriptionDialog(context, playlist),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onPlayAll,
              icon: isResolvingQueue
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(isResolvingQueue ? '解析中' : '播放'),
            ),
            OutlinedButton.icon(
              onPressed: onComment,
              icon: const Icon(Icons.comment_rounded),
              label: const Text('评论'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: '搜索歌单音乐',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: onSearchChanged,
        ),
      ],
    );
  }

  void _showDescriptionDialog(BuildContext context, Playlist playlist) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('歌单介绍'),
          content: SingleChildScrollView(
            child: Text(playlist.description?.trim() ?? ''),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}

class _PlaylistCover extends StatelessWidget {
  const _PlaylistCover({required this.coverUrl, required this.size});

  final String? coverUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = coverImageProvider(coverUrl);
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: image == null
            ? ColoredBox(
                color: colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.queue_music_rounded,
                  size: size * 0.34,
                  color: colorScheme.primary,
                ),
              )
            : Image(
                image: image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return ColoredBox(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.queue_music_rounded,
                      size: size * 0.34,
                      color: colorScheme.primary,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _NeteaseTrackListSliver extends StatelessWidget {
  const _NeteaseTrackListSliver({
    required this.playlist,
    required this.keyword,
    required this.resolvingTrackId,
    required this.isResolvingQueue,
    required this.onPlayTrack,
  });

  final Playlist playlist;
  final String keyword;
  final String? resolvingTrackId;
  final bool isResolvingQueue;
  final ValueChanged<int> onPlayTrack;

  @override
  Widget build(BuildContext context) {
    final tracks = _filteredTracks();
    if (tracks.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _PlaylistMessage(
          icon: Icons.search_off_rounded,
          title: '没有匹配的歌曲',
          subtitle: '换一个关键词再试试',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = tracks[index];
          final track = item.$1;
          final sourceIndex = item.$2;
          final isResolving = resolvingTrackId == track.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TrackTile(
              track: _toTileData(track),
              onTap: isResolvingQueue ? null : () => onPlayTrack(sourceIndex),
              trailing: isResolving
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.play_arrow_rounded),
                      tooltip: '播放',
                      onPressed: isResolvingQueue
                          ? null
                          : () => onPlayTrack(sourceIndex),
                    ),
            ),
          );
        }, childCount: tracks.length),
      ),
    );
  }

  List<(Track, int)> _filteredTracks() {
    final normalizedKeyword = keyword.trim().toLowerCase();
    final tracks = <(Track, int)>[];
    for (var i = 0; i < playlist.tracks.length; i++) {
      final track = playlist.tracks[i];
      if (normalizedKeyword.isEmpty || _matches(track, normalizedKeyword)) {
        tracks.add((track, i));
      }
    }
    return tracks;
  }

  bool _matches(Track track, String keyword) {
    return track.title.toLowerCase().contains(keyword) ||
        track.artists.any((artist) => artist.toLowerCase().contains(keyword)) ||
        (track.album?.toLowerCase().contains(keyword) ?? false);
  }
}

class _PlaylistMessage extends StatelessWidget {
  const _PlaylistMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: colorScheme.primary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
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
          Text('歌单是空的', style: Theme.of(context).textTheme.titleMedium),
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

String _formatPlaylistDate(DateTime? date) {
  if (date == null) {
    return '未知时间';
  }
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
