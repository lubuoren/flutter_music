import 'package:flutter/material.dart';

import '../../../common/presentation/pages/feature_placeholder_page.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: '探索',
      features: const [
        '网易云搜索歌曲、专辑、艺术家、歌单、MV',
        '推荐歌单、热门歌单、排行榜',
        '每日推荐、私人 FM 入口',
        '登录态保护：音乐库、每日推荐、喜欢列表需要登录',
      ],
    );
  }
}
