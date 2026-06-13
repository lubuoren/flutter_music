import 'package:flutter/material.dart';

import '../../../common/presentation/pages/feature_placeholder_page.dart';

class AlbumPage extends StatelessWidget {
  const AlbumPage({super.key, required this.albumId});

  final String? albumId;

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: '专辑',
      features: const [
        '专辑详情、封面、艺术家',
        '专辑歌曲列表与播放',
        '专辑动态信息（收藏数、评论数、分享数）',
        '收藏/取消收藏专辑',
        '新碟上架、全部新碟',
      ],
    );
  }
}
