import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/models/playlist.dart';
import '../../../../widgets/md3/track_tile.dart';
import '../../../../widgets/resilient_cover_image.dart';
import '../../application/netease_playlist_controller.dart';

/// 通用网易云「合辑」详情视图。
///
/// 基于 [neteasePlaylistDetailControllerProvider]（按前缀键 `album:<id>` /
/// `artist:<id>` 复用其拉取、歌词 offset 与逐曲/全部播放逻辑），渲染封面、
/// 标题、副标题、播放全部与可点击播放的歌曲列表。专辑与艺术家详情页共用。
class NeteaseCollectionView extends ConsumerWidget {
  const NeteaseCollectionView({
    super.key,
    required this.collectionId,
    required this.fallbackTitle,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.subtitleBuilder,
    this.showArtistLink = false,
  });

  /// 控制器 family 键，例如 `album:123` 或 `artist:456`。
  final String collectionId;

  /// 数据加载完成前 AppBar 显示的标题。
  final String fallbackTitle;

  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  /// 头部副标题构造器；为空时显示「N 首」。
  final String Function(Playlist playlist)? subtitleBuilder;

  /// 是否在头部显示跳转到「歌手」的入口（专辑详情用，跳到 [Playlist.creatorUserId]）。
  final bool showArtistLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = neteasePlaylistDetailControllerProvider(collectionId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final playlist = state.playlist;

    ref.listen(provider.select((state) => state.playbackErrorMessage), (
      previous,
      next,
    ) {
      if (next != null && next != previous && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next)));
      }
    });

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(playlist?.name ?? fallbackTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: '刷新',
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
              child: _CollectionMessage(
                icon: Icons.cloud_off_rounded,
                title: '加载失败',
                subtitle: state.errorMessage!,
                actionLabel: '重试',
                onAction: controller.refresh,
              ),
            )
          else if (playlist == null || playlist.tracks.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _CollectionMessage(
                icon: emptyIcon,
                title: emptyTitle,
                subtitle: emptySubtitle,
              ),
            )
          else ...[
            if (state.isLoading)
              const SliverToBoxAdapter(child: LinearProgressIndicator()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              sliver: SliverToBoxAdapter(
                child: _CollectionHeader(
                  playlist: playlist,
                  subtitle:
                      subtitleBuilder?.call(playlist) ??
                      '${playlist.tracks.length} 首',
                  isResolvingQueue: state.isResolvingQueue,
                  onPlayAll: state.isResolvingQueue ? null : controller.playAll,
                  onArtistTap:
                      showArtistLink &&
                          (playlist.creatorUserId?.isNotEmpty ?? false)
                      ? () => context.push('/artist/${playlist.creatorUserId}')
                      : null,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final track = playlist.tracks[index];
                  final isResolving = state.resolvingTrackId == track.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TrackTile(
                      track: TrackTileData(
                        id: track.id,
                        title: track.title,
                        subtitle: track.artists.join(' / '),
                        duration: track.durationMs == 0 ? null : track.duration,
                        coverPath: track.coverUrl,
                      ),
                      onTap: state.isResolvingQueue
                          ? null
                          : () => controller.playFromIndex(index),
                      trailing: isResolving
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.play_arrow_rounded),
                              tooltip: '播放',
                              onPressed: state.isResolvingQueue
                                  ? null
                                  : () => controller.playFromIndex(index),
                            ),
                    ),
                  );
                }, childCount: playlist.tracks.length),
              ),
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

class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({
    required this.playlist,
    required this.subtitle,
    required this.isResolvingQueue,
    required this.onPlayAll,
    this.onArtistTap,
  });

  final Playlist playlist;
  final String subtitle;
  final bool isResolvingQueue;
  final VoidCallback? onPlayAll;
  final VoidCallback? onArtistTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final cover = _CollectionCover(
          coverUrl: playlist.coverUrl ?? _firstTrackCoverUrl(playlist),
          size: isWide ? 220 : 168,
        );
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(playlist.name, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            if (onArtistTap != null &&
                (playlist.creatorName?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 10),
              ActionChip(
                avatar: const Icon(Icons.person_rounded, size: 18),
                label: Text(playlist.creatorName!),
                onPressed: onArtistTap,
              ),
            ],
            const SizedBox(height: 18),
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
          ],
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [cover, const SizedBox(width: 24), Expanded(child: info)],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [cover, const SizedBox(height: 18), info],
        );
      },
    );
  }

  String? _firstTrackCoverUrl(Playlist playlist) {
    for (final track in playlist.tracks) {
      final coverUrl = track.coverUrl?.trim();
      if (coverUrl != null && coverUrl.isNotEmpty) {
        return coverUrl;
      }
    }
    return null;
  }
}

class _CollectionCover extends StatelessWidget {
  const _CollectionCover({required this.coverUrl, required this.size});

  final String? coverUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.album_rounded,
        size: size * 0.34,
        color: colorScheme.primary,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: ResilientCoverImage(coverUrl: coverUrl, fallback: fallback),
      ),
    );
  }
}

class _CollectionMessage extends StatelessWidget {
  const _CollectionMessage({
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
            Icon(icon, size: 56, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
