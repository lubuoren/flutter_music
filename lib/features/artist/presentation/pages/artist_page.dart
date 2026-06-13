import 'package:flutter/material.dart';

import '../../../common/presentation/pages/feature_placeholder_page.dart';

class ArtistPage extends StatelessWidget {
  const ArtistPage({super.key, required this.artistId});

  final String? artistId;

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: '艺术家',
      features: const [
        '艺术家详情、热门歌曲',
        '艺术家专辑列表',
        '艺术家 MV 列表',
        '相似艺术家',
        '关注/取消关注艺术家',
        '艺术家排行榜',
      ],
    );
  }
}
