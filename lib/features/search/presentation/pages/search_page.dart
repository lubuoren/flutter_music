import 'package:flutter/material.dart';

import '../../../common/presentation/pages/feature_placeholder_page.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: '搜索',
      features: const [
        '搜索类型：单曲、专辑、艺术家、歌单、用户、MV、歌词、电台、视频、综合',
        '搜索关键词支持多个词，以空格分隔',
        '搜索结果进入歌曲、专辑、艺术家、歌单、用户、MV 详情页',
        '搜索 API 与 cloudsearch 兼容策略保留',
      ],
    );
  }
}
