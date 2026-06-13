import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/platform/cover_image_provider.dart';
import '../../settings/application/app_settings_controller.dart';
import '../application/player_controller.dart';

class PlayerBar extends ConsumerWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final player = ref.watch(musicPlayerControllerProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    final track = player.currentTrack;
    final coverImage = coverImageProvider(track?.coverUrl);

    ref.listen(
      musicPlayerControllerProvider.select((state) => state.errorMessage),
      (previous, next) {
        if (next != null && next != previous) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(next)));
        }
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        return Material(
          elevation: 2,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: _progressValue(player.position, player.duration),
                    minHeight: 2,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: settings.clickPlayerBarToLyrics
                              ? () => context.push('/player')
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: isCompact ? 0 : 8,
                              right: 8,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      colorScheme.secondaryContainer,
                                  backgroundImage: coverImage,
                                  child: coverImage == null
                                      ? const Icon(Icons.album_rounded)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track?.title ?? 'VutronMusic',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        track?.artists.join(' / ') ?? '等待播放',
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (isCompact)
                        const _CompactPlaybackControls()
                      else
                        const _PlaybackControls(),
                      if (!isCompact) const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.queue_music_rounded),
                        tooltip: '下一首播放队列',
                        onPressed: () => context.push('/next'),
                      ),
                      if (!isCompact)
                        IconButton(
                          icon: const Icon(Icons.equalizer_rounded),
                          tooltip: '音效与播放设置',
                          onPressed: () => context.push('/settings'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double? _progressValue(Duration position, Duration? duration) {
    if (duration == null || duration.inMilliseconds <= 0) {
      return null;
    }
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);
  }
}

class _CompactPlaybackControls extends ConsumerWidget {
  const _CompactPlaybackControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(musicPlayerControllerProvider);
    final controller = ref.read(musicPlayerControllerProvider.notifier);
    final isLoading =
        player.processingState == ProcessingState.loading ||
        player.processingState == ProcessingState.buffering;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded),
          tooltip: '上一首',
          onPressed: player.hasPrevious ? controller.playPrevious : null,
        ),
        IconButton.filledTonal(
          onPressed: isLoading ? null : controller.togglePlayPause,
          icon: isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  player.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
          tooltip: player.isPlaying ? '暂停' : '播放',
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded),
          tooltip: '下一首',
          onPressed: player.hasNext ? controller.playNext : null,
        ),
      ],
    );
  }
}

class _PlaybackControls extends ConsumerWidget {
  const _PlaybackControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(musicPlayerControllerProvider);
    final controller = ref.read(musicPlayerControllerProvider.notifier);
    final isLoading =
        player.processingState == ProcessingState.loading ||
        player.processingState == ProcessingState.buffering;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            player.shuffleEnabled
                ? Icons.shuffle_on_rounded
                : Icons.shuffle_rounded,
          ),
          tooltip: '随机播放',
          onPressed: controller.toggleShuffle,
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded),
          tooltip: '上一首',
          onPressed: player.hasPrevious ? controller.playPrevious : null,
        ),
        FilledButton.icon(
          onPressed: isLoading ? null : controller.togglePlayPause,
          icon: isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  player.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
          label: Text(player.isPlaying ? '暂停' : '播放'),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded),
          tooltip: '下一首',
          onPressed: player.hasNext ? controller.playNext : null,
        ),
        IconButton(
          icon: Icon(_loopIcon(player.loopMode)),
          tooltip: '循环模式',
          onPressed: controller.cycleLoopMode,
        ),
      ],
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
