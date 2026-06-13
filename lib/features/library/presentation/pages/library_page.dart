import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/platform/cover_image_provider.dart';
import '../../../../data/models/playlist.dart';
import '../../../login/application/netease_auth_controller.dart';
import '../../../playlist/application/netease_playlist_controller.dart';
import '../../../../widgets/md3/section_header.dart';

enum _PlaylistFilter { all, mine, subscribed }

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  _PlaylistFilter _filter = _PlaylistFilter.all;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(neteaseAuthControllerProvider);
    final cloudPlaylists = ref.watch(neteaseUserPlaylistsControllerProvider);
    final controller = ref.read(
      neteaseUserPlaylistsControllerProvider.notifier,
    );
    final playlists = _filteredPlaylists(
      cloudPlaylists.playlists,
      auth.profile?.userId,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('音乐库'),
            actions: [
              IconButton(
                icon: const Icon(Icons.login_rounded),
                tooltip: auth.isLoggedIn ? '网易云账号' : '登录网易云',
                onPressed: () => context.push('/login/account'),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: '刷新云端歌单',
                onPressed: cloudPlaylists.isLoading || !auth.isLoggedIn
                    ? null
                    : controller.refresh,
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            sliver: SliverList.list(
              children: [
                if (!auth.isLoggedIn)
                  _CloudLoginPanel(auth: auth)
                else ...[
                  _CloudProfilePanel(
                    auth: auth,
                    playlistCount: cloudPlaylists.playlists.length,
                    mineCount: _ownedCount(
                      cloudPlaylists.playlists,
                      auth.profile?.userId,
                    ),
                    subscribedCount: _subscribedCount(
                      cloudPlaylists.playlists,
                      auth.profile?.userId,
                    ),
                    onRefresh: cloudPlaylists.isLoading
                        ? null
                        : controller.refresh,
                  ),
                  const SizedBox(height: 24),
                  M3SectionHeader(
                    title: '网易云歌单',
                    actionLabel: cloudPlaylists.playlists.isEmpty
                        ? null
                        : '${cloudPlaylists.playlists.length} 个',
                  ),
                  const SizedBox(height: 12),
                  _PlaylistFilterBar(
                    value: _filter,
                    onChanged: (value) {
                      setState(() {
                        _filter = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (cloudPlaylists.isLoading)
                    const LinearProgressIndicator()
                  else if (cloudPlaylists.errorMessage != null)
                    _LibraryMessageCard(
                      icon: Icons.cloud_off_rounded,
                      title: '云端歌单加载失败',
                      subtitle:
                          '${cloudPlaylists.errorMessage}\n请确认 API 服务地址和登录态可用。',
                      actionLabel: '重试',
                      onAction: controller.refresh,
                    )
                  else if (cloudPlaylists.playlists.isEmpty)
                    _LibraryMessageCard(
                      icon: Icons.queue_music_rounded,
                      title: '还没有云端歌单',
                      subtitle: '登录账号后，这里会显示网易云创建和收藏的歌单。',
                      actionLabel: '刷新',
                      onAction: controller.refresh,
                    )
                  else if (playlists.isEmpty)
                    const _LibraryMessageCard(
                      icon: Icons.filter_alt_off_rounded,
                      title: '当前筛选没有歌单',
                      subtitle: '切换到全部歌单查看更多内容。',
                    )
                  else
                    _CloudPlaylistGrid(playlists: playlists),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Playlist> _filteredPlaylists(List<Playlist> playlists, String? userId) {
    return switch (_filter) {
      _PlaylistFilter.all => playlists,
      _PlaylistFilter.mine =>
        playlists
            .where((playlist) => playlist.creatorUserId == userId)
            .toList(),
      _PlaylistFilter.subscribed =>
        playlists
            .where((playlist) => playlist.creatorUserId != userId)
            .toList(),
    };
  }

  int _ownedCount(List<Playlist> playlists, String? userId) {
    return playlists
        .where((playlist) => playlist.creatorUserId == userId)
        .length;
  }

  int _subscribedCount(List<Playlist> playlists, String? userId) {
    return playlists
        .where((playlist) => playlist.creatorUserId != userId)
        .length;
  }
}

class _CloudLoginPanel extends StatelessWidget {
  const _CloudLoginPanel({required this.auth});

  final NeteaseAuthState auth;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.cloud_queue_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('登录网易云账号', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              auth.hasCookie
                  ? '已保存 Cookie，等待校验登录态。校验通过后会自动展示云端歌单。'
                  : '使用二维码或 Cookie 登录后，可以同步查看创建和收藏的云端歌单。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => context.push('/login/account'),
              icon: const Icon(Icons.login_rounded),
              label: const Text('去登录'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloudProfilePanel extends StatelessWidget {
  const _CloudProfilePanel({
    required this.auth,
    required this.playlistCount,
    required this.mineCount,
    required this.subscribedCount,
    required this.onRefresh,
  });

  final NeteaseAuthState auth;
  final int playlistCount;
  final int mineCount;
  final int subscribedCount;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final profile = auth.profile;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage:
                  profile?.avatarUrl == null || profile!.avatarUrl!.isEmpty
                  ? null
                  : NetworkImage(profile.avatarUrl!),
              child: profile?.avatarUrl == null || profile!.avatarUrl!.isEmpty
                  ? const Icon(Icons.person_rounded)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?.nickname ?? '网易云用户',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile == null ? '登录态校验中' : 'UID ${profile.userId}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetricChip(label: '全部', value: playlistCount),
                      _MetricChip(label: '创建', value: mineCount),
                      _MetricChip(label: '收藏', value: subscribedCount),
                    ],
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              icon: auth.isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              tooltip: '刷新云端歌单',
              onPressed: auth.isLoading ? null : onRefresh,
              color: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text('$label $value'),
      avatar: const Icon(Icons.bar_chart_rounded, size: 18),
    );
  }
}

class _PlaylistFilterBar extends StatelessWidget {
  const _PlaylistFilterBar({required this.value, required this.onChanged});

  final _PlaylistFilter value;
  final ValueChanged<_PlaylistFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_PlaylistFilter>(
      segments: const [
        ButtonSegment(
          value: _PlaylistFilter.all,
          icon: Icon(Icons.all_inclusive_rounded),
          label: Text('全部'),
        ),
        ButtonSegment(
          value: _PlaylistFilter.mine,
          icon: Icon(Icons.edit_note_rounded),
          label: Text('创建'),
        ),
        ButtonSegment(
          value: _PlaylistFilter.subscribed,
          icon: Icon(Icons.favorite_rounded),
          label: Text('收藏'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _CloudPlaylistGrid extends StatelessWidget {
  const _CloudPlaylistGrid({required this.playlists});

  final List<Playlist> playlists;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsForWidth(constraints.maxWidth);
        final tileWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: tileWidth + 88,
          ),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            return _CloudPlaylistCard(playlist: playlists[index]);
          },
        );
      },
    );
  }

  int _columnsForWidth(double width) {
    if (width >= 1120) {
      return 5;
    }
    if (width >= 860) {
      return 4;
    }
    if (width >= 560) {
      return 3;
    }
    return 2;
  }
}

class _CloudPlaylistCard extends StatelessWidget {
  const _CloudPlaylistCard({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final image = coverImageProvider(playlist.coverUrl);
    final colorScheme = Theme.of(context).colorScheme;
    final trackCount = playlist.trackCount == 0
        ? playlist.tracks.length
        : playlist.trackCount;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/playlist/${playlist.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image == null)
                    ColoredBox(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.queue_music_rounded,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                    )
                  else
                    Image(
                      image: image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return ColoredBox(
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.queue_music_rounded,
                            size: 48,
                            color: colorScheme.primary,
                          ),
                        );
                      },
                    ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.scrim.withValues(alpha: 0.56),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          '$trackCount 首',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    playlist.creatorName == null ||
                            playlist.creatorName!.isEmpty
                        ? '网易云歌单'
                        : 'by ${playlist.creatorName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryMessageCard extends StatelessWidget {
  const _LibraryMessageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
