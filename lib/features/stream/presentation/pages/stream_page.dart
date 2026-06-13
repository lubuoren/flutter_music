import 'package:flutter/material.dart';

import '../../../common/presentation/pages/feature_placeholder_page.dart';

class StreamPage extends StatelessWidget {
  const StreamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: '流媒体音乐',
      features: const [
        'Navidrome、Jellyfin、Emby 三种服务',
        '统一 StreamingMusicProvider 抽象',
        '浏览流媒体歌单、专辑、艺术家',
        '播放流媒体歌曲、获取流媒体歌词与封面',
        '流媒体喜欢列表、scrobble 听歌记录',
      ],
    );
  }
}
