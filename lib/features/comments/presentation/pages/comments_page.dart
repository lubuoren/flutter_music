import 'package:flutter/material.dart';

import '../../../common/presentation/pages/feature_placeholder_page.dart';

class CommentsPage extends StatelessWidget {
  const CommentsPage({
    super.key,
    required this.resourceType,
    required this.resourceId,
  });

  final String resourceType;
  final String? resourceId;

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: '评论',
      features: const [
        '获取评论（热门/最新，分页）',
        '楼层评论（盖楼）',
        '发表评论、回复评论',
        '点赞/取消点赞评论',
        '支持歌曲、专辑、歌单、MV、电台等资源类型',
      ],
    );
  }
}
