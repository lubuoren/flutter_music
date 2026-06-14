import 'package:flutter/material.dart';

import '../../../playlist/presentation/widgets/netease_collection_view.dart';

class ArtistPage extends StatelessWidget {
  const ArtistPage({super.key, required this.artistId});

  final String? artistId;

  @override
  Widget build(BuildContext context) {
    final id = artistId?.trim() ?? '';
    if (id.isEmpty) {
      return const Scaffold(body: Center(child: Text('缺少艺术家 ID')));
    }
    return NeteaseCollectionView(
      collectionId: 'artist:$id',
      fallbackTitle: '艺术家',
      emptyIcon: Icons.person_rounded,
      emptyTitle: '暂无热门歌曲',
      emptySubtitle: '该艺术家没有可显示的热门歌曲',
      subtitleBuilder: (playlist) => '热门歌曲 · ${playlist.tracks.length} 首',
    );
  }
}
