import 'package:flutter/material.dart';

import '../../../common/presentation/pages/feature_placeholder_page.dart';

class ArtistMvPage extends StatelessWidget {
  const ArtistMvPage({super.key, required this.artistId});

  final String? artistId;

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: '艺术家 MV',
      features: const ['艺术家 MV 列表分页加载', 'MV 封面、标题、播放量', '进入 MV 播放页'],
    );
  }
}
