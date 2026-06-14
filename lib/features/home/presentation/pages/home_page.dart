import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/local/local_music_repository.dart';
import '../../../../data/models/track.dart';
import '../../../../features/player/application/player_controller.dart';
import '../../../../widgets/md3/music_card.dart';
import '../../../../widgets/md3/section_header.dart';
import '../../../../widgets/md3/track_tile.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localState = ref.watch(localMusicControllerProvider);
    final tracks = localState.tracks;
    final recentTracks = _recentTracks(tracks).take(5).toList();
    final likedTracks = tracks.where((track) => track.isLiked).take(6).toList();
    final recentAdded = [...tracks]
      ..sort((a, b) {
        final aAdded = a.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bAdded = b.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bAdded.compareTo(aAdded);
      });

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('VutronMusic'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => context.push('/search'),
              tooltip: '搜索',
            ),
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => context.push('/settings'),
              tooltip: '设置',
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ForYouPanel(
                  tracks: tracks,
                  recentTracks: recentTracks,
                  likedCount: tracks.where((track) => track.isLiked).length,
                ),
                const SizedBox(height: 24),
                M3SectionHeader(
                  title: '最近播放',
                  actionLabel: '本地音乐',
                  onTap: () => context.push('/localMusic'),
                ),
                const SizedBox(height: 12),
                _TrackSection(
                  tracks: recentTracks,
                  allTracks: tracks,
                  emptyTitle: '扫描本地音乐后会显示最近播放',
                  emptySubtitle: '先完成目录扫描，再从本地音乐页开始播放',
                  emptyIcon: Icons.history_rounded,
                ),
                const SizedBox(height: 24),
                M3SectionHeader(
                  title: '我喜欢的本地歌曲',
                  actionLabel: likedTracks.isEmpty ? null : '查看全部',
                  onTap: () => context.push('/localMusic'),
                ),
                const SizedBox(height: 12),
                _CompactTrackGrid(tracks: likedTracks, allTracks: tracks),
                const SizedBox(height: 24),
                M3SectionHeader(
                  title: '最近添加',
                  actionLabel: '本地音乐',
                  onTap: () => context.push('/localMusic'),
                ),
                const SizedBox(height: 12),
                _TrackSection(
                  tracks: recentAdded.take(5).toList(),
                  allTracks: tracks,
                  emptyTitle: '还没有本地歌曲',
                  emptySubtitle: '选择音乐目录后，这里会显示最近添加',
                  emptyIcon: Icons.folder_open_rounded,
                ),
                const SizedBox(height: 24),
                const M3SectionHeader(title: '在线与流媒体入口'),
                const SizedBox(height: 12),
                _RemoteEntryGrid(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Track> _recentTracks(List<Track> tracks) {
    final played = tracks.where((track) => track.lastPlayedAt != null).toList()
      ..sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));
    return played;
  }
}

class _ForYouPanel extends ConsumerWidget {
  const _ForYouPanel({
    required this.tracks,
    required this.recentTracks,
    required this.likedCount,
  });

  final List<Track> tracks;
  final List<Track> recentTracks;
  final int likedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final lastTrack = recentTracks.firstOrNull;

    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            final summary = _LibrarySummary(
              tracks: tracks,
              likedCount: likedCount,
              onPlayAll: tracks.isEmpty
                  ? null
                  : () => ref
                        .read(musicPlayerControllerProvider.notifier)
                        .playQueue(tracks),
              onOpenLocal: () => context.push('/localMusic'),
            );
            final continueCard = _ContinueCard(
              track: lastTrack,
              onTap: lastTrack == null
                  ? () => context.push('/localMusic')
                  : () {
                      final index = tracks.indexWhere(
                        (track) => track.id == lastTrack.id,
                      );
                      ref
                          .read(musicPlayerControllerProvider.notifier)
                          .playQueue(tracks, startIndex: index < 0 ? 0 : index);
                    },
            );
            return isWide
                ? Row(
                    children: [
                      Expanded(flex: 3, child: summary),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: continueCard),
                    ],
                  )
                : Column(
                    children: [
                      summary,
                      const SizedBox(height: 16),
                      continueCard,
                    ],
                  );
          },
        ),
      ),
    );
  }
}

class _LibrarySummary extends StatelessWidget {
  const _LibrarySummary({
    required this.tracks,
    required this.likedCount,
    required this.onPlayAll,
    required this.onOpenLocal,
  });

  final List<Track> tracks;
  final int likedCount;
  final VoidCallback? onPlayAll;
  final VoidCallback onOpenLocal;

  @override
  Widget build(BuildContext context) {
    final albums = tracks
        .map((track) => track.album)
        .whereType<String>()
        .toSet();
    final artists = tracks.expand((track) => track.artists).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('For You', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          '从本地音乐库开始，逐步接入网易云推荐、每日歌曲和私人 FM。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricChip(label: '歌曲', value: tracks.length.toString()),
            _MetricChip(label: '专辑', value: albums.length.toString()),
            _MetricChip(label: '艺术家', value: artists.length.toString()),
            _MetricChip(label: '喜欢', value: likedCount.toString()),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onPlayAll,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('播放本地库'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenLocal,
              icon: const Icon(Icons.audio_file_rounded),
              label: const Text('管理本地音乐'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.track, required this.onTap});

  final Track? track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          height: 170,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('继续播放', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Icon(
                track == null
                    ? Icons.folder_open_rounded
                    : Icons.graphic_eq_rounded,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                track?.title ?? '扫描本地音乐',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                track?.artists.join(' / ') ?? '建立你的本地音乐库',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text('$label $value'),
      avatar: const Icon(Icons.bar_chart_rounded, size: 18),
    );
  }
}

class _TrackSection extends ConsumerWidget {
  const _TrackSection({
    required this.tracks,
    required this.allTracks,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
  });

  final List<Track> tracks;
  final List<Track> allTracks;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tracks.isEmpty) {
      return Card(
        child: ListTile(
          leading: Icon(emptyIcon),
          title: Text(emptyTitle),
          subtitle: Text(emptySubtitle),
          onTap: () => context.push('/localMusic'),
        ),
      );
    }

    return Column(
      children: [
        for (final track in tracks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TrackTile(
              track: _toTileData(track),
              onTap: () {
                final index = allTracks.indexWhere(
                  (item) => item.id == track.id,
                );
                ref
                    .read(musicPlayerControllerProvider.notifier)
                    .playQueue(allTracks, startIndex: index < 0 ? 0 : index);
              },
            ),
          ),
      ],
    );
  }
}

class _CompactTrackGrid extends ConsumerWidget {
  const _CompactTrackGrid({required this.tracks, required this.allTracks});

  final List<Track> tracks;
  final List<Track> allTracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tracks.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.favorite_border_rounded),
          title: const Text('还没有喜欢的本地歌曲'),
          subtitle: const Text('在本地音乐列表中点喜欢后会出现在这里'),
          onTap: () => context.push('/localMusic'),
        ),
      );
    }

    final columns = MediaQuery.sizeOf(context).width >= 900 ? 3 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 3.6,
      ),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return Card(
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.favorite_rounded),
            title: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              track.artists.join(' / '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              final trackIndex = allTracks.indexWhere(
                (item) => item.id == track.id,
              );
              ref
                  .read(musicPlayerControllerProvider.notifier)
                  .playQueue(
                    allTracks,
                    startIndex: trackIndex < 0 ? 0 : trackIndex,
                  );
            },
          ),
        );
      },
    );
  }
}

class _RemoteEntryGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cards = [
      ('每日推荐', '登录网易云后查看每日推荐歌曲', '/daily/songs'),
      ('私人 FM', 'Phase 4 接入网易云私人 FM', '/explore'),
      ('流媒体服务', 'Navidrome / Jellyfin / Emby', '/stream'),
      ('系统设置', '主题、播放、歌词与音效', '/settings'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.7,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return M3MusicCard(
          title: card.$1,
          subtitle: card.$2,
          onTap: () => context.push(card.$3),
        );
      },
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
