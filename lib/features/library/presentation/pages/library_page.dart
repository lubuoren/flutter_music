import 'package:flutter/material.dart';

import '../../../common/presentation/pages/feature_placeholder_page.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: '音乐库',
      features: const [
        '网易云登录态音乐库',
        '我喜欢的音乐',
        '创建、编辑、删除歌单',
        '收藏专辑、艺术家、MV',
        '用户主页、听歌历史、云盘',
      ],
    );
  }
}
