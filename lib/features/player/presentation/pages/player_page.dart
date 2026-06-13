import 'dart:io';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../data/local/local_music_repository.dart';
import '../../../../data/models/track.dart';
import '../../application/lyric_controller.dart';
import '../../application/player_controller.dart';
import '../../widgets/lyric_view.dart';

class PlayerPage extends ConsumerWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(musicPlayerControllerProvider);
    final track = player.currentTrack;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.expand_more_rounded),
          onPressed: () => context.pop(),
          tooltip: '收起',
        ),
        title: const Text('正在播放'),
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: '播放队列',
            onPressed: () => context.push('/next'),
          ),
          IconButton(
            icon: const Icon(Icons.comment_outlined),
            tooltip: '评论',
            onPressed: track == null
                ? null
                : () => context.push('/comments/track/${track.id}'),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final cover = _AlbumCover(track: track);
          final detail = _TrackDetail(track: track);

          return Padding(
            padding: const EdgeInsets.all(24),
            child: isWide
                ? Row(
                    children: [
                      Expanded(child: cover),
                      const SizedBox(width: 32),
                      Expanded(child: detail),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(flex: 3, child: cover),
                      const SizedBox(height: 16),
                      Expanded(flex: 2, child: detail),
                    ],
                  ),
          );
        },
      ),
      bottomNavigationBar: const _PlayerControlPanel(),
    );
  }
}

class _AlbumCover extends StatelessWidget {
  const _AlbumCover({required this.track});

  final Track? track;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final coverPath = track?.coverUrl;

    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: coverPath == null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.tertiaryContainer,
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.album_rounded,
                    size: 120,
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.4,
                    ),
                  ),
                )
              : Image.file(File(coverPath), fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _TrackDetail extends ConsumerWidget {
  const _TrackDetail({required this.track});

  final Track? track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = this.track;
    final lyricState = ref.watch(lyricControllerProvider);

    if (track == null) {
      return Center(
        child: Text(
          '从本地音乐选择一首歌开始播放',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.title,
          style: Theme.of(context).textTheme.headlineMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          [
            track.artists.join(' / '),
            if (track.album != null) track.album!,
          ].join(' · '),
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: LyricView(
                lines: lyricState.lines,
                currentIndex: lyricState.currentIndex,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerControlPanel extends ConsumerWidget {
  const _PlayerControlPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(musicPlayerControllerProvider);
    final controller = ref.read(musicPlayerControllerProvider.notifier);
    final track = player.currentTrack;
    final isLoading =
        player.processingState == ProcessingState.loading ||
        player.processingState == ProcessingState.buffering;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProgressBar(
              progress: player.position,
              buffered: player.bufferedPosition,
              total: player.duration ?? track?.duration ?? Duration.zero,
              onSeek: controller.seek,
              timeLabelTextStyle: Theme.of(context).textTheme.bodySmall,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    track?.isLiked == true
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                  ),
                  tooltip: track?.isLiked == true ? '取消喜欢' : '喜欢',
                  onPressed: track == null || track.type != TrackType.local
                      ? null
                      : () => ref
                            .read(localMusicControllerProvider.notifier)
                            .toggleLiked(track),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded),
                  onPressed: player.hasPrevious
                      ? controller.playPrevious
                      : null,
                ),
                FloatingActionButton(
                  onPressed: isLoading ? null : controller.togglePlayPause,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : Icon(
                          player.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: player.hasNext ? controller.playNext : null,
                ),
                IconButton(
                  icon: Icon(_loopIcon(player.loopMode)),
                  tooltip: '循环模式',
                  onPressed: controller.cycleLoopMode,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _loopIcon(LoopMode mode) {
    return switch (mode) {
      LoopMode.off => Icons.repeat_rounded,
      LoopMode.all => Icons.repeat_on_rounded,
      LoopMode.one => Icons.repeat_one_on_rounded,
    };
  }
}
