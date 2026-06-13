import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/local/local_music_repository.dart';
import '../../../login/application/netease_auth_controller.dart';
import '../../application/app_settings_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final localMusic = ref.watch(localMusicControllerProvider);
    final neteaseAuth = ref.watch(neteaseAuthControllerProvider);
    final settingsController = ref.read(appSettingsControllerProvider.notifier);
    final localController = ref.read(localMusicControllerProvider.notifier);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('系统设置'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: '重新扫描本地音乐',
                onPressed: localMusic.isScanning
                    ? null
                    : localController.rescan,
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            sliver: SliverList.list(
              children: [
                _SettingsSection(
                  icon: Icons.palette_rounded,
                  title: '外观',
                  children: [
                    _ThemeModeTile(
                      value: settings.themeMode,
                      onChanged: settingsController.setThemeMode,
                    ),
                    SwitchListTile(
                      value: settings.showBanner,
                      secondary: const Icon(Icons.view_carousel_rounded),
                      title: const Text('首页 Banner'),
                      subtitle: const Text('网易云在线推荐接入后用于控制首页 Banner 展示'),
                      onChanged: settingsController.setShowBanner,
                    ),
                  ],
                ),
                _SettingsSection(
                  icon: Icons.audio_file_rounded,
                  title: '本地音乐',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.folder_open_rounded),
                      title: const Text('添加扫描目录'),
                      subtitle: const Text('选择目录后立即扫描本地音乐'),
                      trailing: localMusic.isScanning
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Icon(Icons.add_rounded),
                      onTap: localMusic.isScanning
                          ? null
                          : localController.pickAndScanDirectory,
                    ),
                    if (localMusic.scanDirectories.isEmpty)
                      const ListTile(
                        leading: Icon(Icons.info_outline_rounded),
                        title: Text('尚未添加本地目录'),
                        subtitle: Text('本地音乐页和首页会基于扫描结果展示歌曲、专辑、艺术家和目录'),
                      )
                    else
                      for (final directory in localMusic.scanDirectories)
                        ListTile(
                          leading: const Icon(Icons.folder_rounded),
                          title: Text(
                            directory,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: const Text('已加入扫描目录'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            tooltip: '移除目录',
                            onPressed: () =>
                                localController.removeScanDirectory(directory),
                          ),
                        ),
                  ],
                ),
                _SettingsSection(
                  icon: Icons.cloud_rounded,
                  title: '在线音乐',
                  children: [
                    _NeteaseApiBaseUrlTile(
                      value: settings.neteaseApiBaseUrl,
                      onSubmitted: settingsController.setNeteaseApiBaseUrl,
                    ),
                    ListTile(
                      leading: const Icon(Icons.account_circle_rounded),
                      title: const Text('网易云账号'),
                      subtitle: Text(
                        neteaseAuth.isLoggedIn
                            ? '${neteaseAuth.profile!.nickname} · UID ${neteaseAuth.profile!.userId}'
                            : neteaseAuth.hasCookie
                            ? '已保存 Cookie，等待校验登录态'
                            : '未登录',
                      ),
                      trailing: neteaseAuth.isLoading
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/login/account'),
                    ),
                    const ListTile(
                      leading: Icon(Icons.info_outline_rounded),
                      title: Text('网易云 API 服务'),
                      subtitle: Text(
                        'Phase 4 使用 api-enhanced 自建 HTTP 服务，Flutter 只保存服务地址并通过 dio 调用',
                      ),
                    ),
                  ],
                ),
                _SettingsSection(
                  icon: Icons.play_circle_rounded,
                  title: '播放',
                  children: [
                    SwitchListTile(
                      value: settings.clickPlayerBarToLyrics,
                      secondary: const Icon(Icons.lyrics_rounded),
                      title: const Text('点击播放栏打开歌词'),
                      subtitle: const Text('开启后点击播放栏曲目信息进入正在播放页'),
                      onChanged: settingsController.setClickPlayerBarToLyrics,
                    ),
                    SwitchListTile(
                      value: settings.showChorus,
                      secondary: const Icon(Icons.graphic_eq_rounded),
                      title: const Text('显示副歌标记'),
                      subtitle: const Text('在线歌曲副歌时间接入后显示在播放进度条上'),
                      onChanged: settingsController.setShowChorus,
                    ),
                    ListTile(
                      leading: const Icon(Icons.hourglass_bottom_rounded),
                      title: const Text('淡入淡出时长'),
                      subtitle: Slider(
                        value: settings.fadeDuration,
                        min: 0,
                        max: 3,
                        divisions: 30,
                        label: '${settings.fadeDuration.toStringAsFixed(1)}s',
                        onChanged: settingsController.setFadeDuration,
                      ),
                      trailing: Text(
                        '${settings.fadeDuration.toStringAsFixed(1)}s',
                      ),
                    ),
                  ],
                ),
                const _SettingsSection(
                  icon: Icons.tune_rounded,
                  title: '后续阶段',
                  children: [
                    _RoadmapTile(
                      icon: Icons.equalizer_rounded,
                      title: '音效设置',
                      subtitle: 'Phase 6：均衡器、卷积混响、变调、变速',
                    ),
                    _RoadmapTile(
                      icon: Icons.desktop_windows_rounded,
                      title: '桌面增强',
                      subtitle: 'Phase 7：托盘、MPRIS、全局快捷键、桌面歌词',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NeteaseApiBaseUrlTile extends StatefulWidget {
  const _NeteaseApiBaseUrlTile({
    required this.value,
    required this.onSubmitted,
  });

  final String value;
  final ValueChanged<String> onSubmitted;

  @override
  State<_NeteaseApiBaseUrlTile> createState() => _NeteaseApiBaseUrlTileState();
}

class _NeteaseApiBaseUrlTileState extends State<_NeteaseApiBaseUrlTile> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _NeteaseApiBaseUrlTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.link_rounded),
      title: const Text('Netease API Base URL'),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: defaultNeteaseApiBaseUrl(),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: widget.onSubmitted,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.save_rounded),
        tooltip: '保存 API 地址',
        onPressed: () => widget.onSubmitted(_controller.text),
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({required this.value, required this.onChanged});

  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.contrast_rounded),
      title: const Text('主题模式'),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<AppThemeMode>(
            segments: const [
              ButtonSegment(
                value: AppThemeMode.system,
                icon: Icon(Icons.brightness_auto_rounded),
                label: Text('跟随'),
              ),
              ButtonSegment(
                value: AppThemeMode.light,
                icon: Icon(Icons.light_mode_rounded),
                label: Text('浅色'),
              ),
              ButtonSegment(
                value: AppThemeMode.dark,
                icon: Icon(Icons.dark_mode_rounded),
                label: Text('深色'),
              ),
              ButtonSegment(
                value: AppThemeMode.black,
                icon: Icon(Icons.nights_stay_rounded),
                label: Text('纯黑'),
              ),
            ],
            selected: {value},
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index != children.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadmapTile extends StatelessWidget {
  const _RoadmapTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: false,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.schedule_rounded),
    );
  }
}
