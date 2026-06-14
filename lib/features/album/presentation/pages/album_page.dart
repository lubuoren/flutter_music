import 'package:flutter/material.dart';

import '../../../playlist/presentation/widgets/netease_collection_view.dart';

class AlbumPage extends StatelessWidget {
  const AlbumPage({super.key, required this.albumId});

  final String? albumId;

  @override
  Widget build(BuildContext context) {
    final id = albumId?.trim() ?? '';
    if (id.isEmpty) {
      return const Scaffold(body: Center(child: Text('缺少专辑 ID')));
    }
    return NeteaseCollectionView(
      collectionId: 'album:$id',
      fallbackTitle: '专辑',
      emptyIcon: Icons.album_rounded,
      emptyTitle: '暂无歌曲',
      emptySubtitle: '该专辑没有可显示的歌曲',
      showArtistLink: true,
      subtitleBuilder: (playlist) {
        final artist = playlist.creatorName;
        final count = '${playlist.tracks.length} 首';
        return artist == null || artist.isEmpty ? count : '$artist · $count';
      },
    );
  }
}
