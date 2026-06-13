import 'package:flutter/material.dart';

import '../../../common/presentation/pages/feature_placeholder_page.dart';

class MvPage extends StatelessWidget {
  const MvPage({super.key, required this.mvId});

  final String? mvId;

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: 'MV 播放',
      features: const [
        'MV 详情、动态信息',
        'MV 播放地址（多清晰度）',
        '相似 MV 推荐',
        '收藏/取消收藏 MV、点赞 MV',
      ],
    );
  }
}
