import 'package:flutter/material.dart';

import '../../../common/presentation/pages/feature_placeholder_page.dart';

class StreamLoginPage extends StatelessWidget {
  const StreamLoginPage({super.key, required this.service});

  final String service;

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: '$service 流媒体登录',
      features: const [
        '输入服务地址、用户名、密码',
        '登录校验与账号保存',
        '登录态持久化（store.accounts）',
        '退出登录与切换服务',
      ],
    );
  }
}
