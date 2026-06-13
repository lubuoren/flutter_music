import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/track.dart';
import '../../../../widgets/md3/track_tile.dart';
import '../../application/player_controller.dart';

class NextUpPage extends ConsumerWidget {
  const NextUpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(musicPlayerControllerProvider);
    final controller = ref.read(musicPlayerControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('播放队列'),
        actions: [
          IconButton(
            icon: Icon(
              player.shuffleEnabled
                  ? Icons.shuffle_on_rounded
                  : Icons.shuffle_rounded,
            ),
            tooltip: '随机播放',
            onPressed: controller.toggleShuffle,
          ),
        ],
      ),
      body: player.queue.isEmpty
          ? Center(
              child: Text(
                '当前没有播放队列',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: player.queue.length,
              itemBuilder: (context, index) {
                final track = player.queue[index];
                final selected = index == player.currentIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TrackTile(
                    selected: selected,
                    track: _toTileData(track),
                    onTap: () =>
                        controller.playQueue(player.queue, startIndex: index),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: '移出队列',
                      onPressed: () => controller.removeFromQueue(track),
                    ),
                  ),
                );
              },
            ),
    );
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
}
