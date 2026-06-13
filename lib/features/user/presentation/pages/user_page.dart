import 'package:flutter/material.dart';

import '../../../common/presentation/pages/feature_placeholder_page.dart';

class UserPage extends StatelessWidget {
  const UserPage({super.key, required this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: '用户主页',
      features: const ['用户详情、头像、签名', '用户歌单列表', '听歌历史（最近/全部）', '每日签到'],
    );
  }
}
