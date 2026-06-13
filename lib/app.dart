import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/application/app_settings_controller.dart';

class VutronMusicApp extends ConsumerWidget {
  const VutronMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(appSettingsControllerProvider);

    return MaterialApp.router(
      title: 'VutronMusic',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.lightTheme(),
      darkTheme: settings.themeMode == AppThemeMode.black
          ? AppTheme.blackTheme()
          : AppTheme.darkTheme(),
      themeMode: settings.materialThemeMode,
    );
  }
}
