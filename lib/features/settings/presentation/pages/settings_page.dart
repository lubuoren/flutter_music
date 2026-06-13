import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/local/local_music_repository.dart';
import '../../application/app_settings_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final localMusic = ref.watch(localMusicControllerProvider);
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
                  icon: Icons.play_circle_rounded,
                  title: '播放',
                  children: [
                    SwitchListTile(
                      value: settings.clickPlayerBarToLyrics,
                      secondary: const Icon(Icons.lyrics_rounded),
                      title: const Text('点击播放栏打开歌词'),
                      subtitle: const Text('后续接入滚动歌词页后生效'),
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
                _SettingsSection(
                  icon: Icons.tune_rounded,
                  title: '待接入能力',
                  children: const [
                    _RoadmapTile(
                      icon: Icons.queue_music_rounded,
                      title: '本地歌单',
                      subtitle: '创建、编辑、删除歌单，以及向歌单添加/移除歌曲',
                    ),
                    _RoadmapTile(
                      icon: Icons.lyrics_rounded,
                      title: '滚动歌词与逐字歌词',
                      subtitle: '解析 LRC/LDDC，播放页同步滚动和逐字高亮',
                    ),
                    _RoadmapTile(
                      icon: Icons.equalizer_rounded,
                      title: '音效设置',
                      subtitle: '均衡器、卷积混响、变调、变速',
                    ),
                    _RoadmapTile(
                      icon: Icons.desktop_windows_rounded,
                      title: '桌面增强',
                      subtitle: '托盘、MPRIS、全局快捷键、桌面歌词',
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
