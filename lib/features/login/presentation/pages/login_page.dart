import 'package:flutter/material.dart';

import '../../../common/presentation/pages/feature_placeholder_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: '登录网易云账号',
      features: const [
        '二维码登录（生成 key、轮询扫码状态）',
        '手机号登录、邮箱登录',
        '游客登录与登录态校验',
        '刷新 Cookie、登录状态、用户账号信息',
        '退出登录',
      ],
    );
  }
}
