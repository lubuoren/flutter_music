import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../../data/local/local_music_repository.dart';
import '../../../../data/models/track.dart';
import '../../../../features/playlist/application/local_playlist_controller.dart';
import '../../../../features/player/application/player_controller.dart';
import '../../../../widgets/md3/section_header.dart';
import '../../../../widgets/md3/track_tile.dart';

class LocalMusicPage extends ConsumerStatefulWidget {
  const LocalMusicPage({super.key});

  @override
  ConsumerState<LocalMusicPage> createState() => _LocalMusicPageState();
}

class _LocalMusicPageState extends ConsumerState<LocalMusicPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _keyword = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localMusic = ref.watch(localMusicControllerProvider);
    final tracks = _filterTracks(localMusic.tracks);

    ref.listen(
      localMusicControllerProvider.select((state) => state.errorMessage),
      (previous, next) {
        if (next != null && next != previous) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(next)));
        }
      },
    );

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          final isWideHeader = MediaQuery.sizeOf(context).width >= 720;
          return [
            SliverAppBar.large(
              title: const Text('本地音乐'),
              pinned: true,
              actions: [
                if (!kIsWeb)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: '重新扫描',
                    onPressed: localMusic.isScanning
                        ? null
                        : () => ref
                              .read(localMusicControllerProvider.notifier)
                              .rescan(),
                  ),
                if (!kIsWeb)
                  IconButton(
                    icon: const Icon(Icons.create_new_folder_rounded),
                    tooltip: '选择目录',
                    onPressed: localMusic.isScanning
                        ? null
                        : () => ref
                              .read(localMusicControllerProvider.notifier)
                              .pickAndScanDirectory(),
                  ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              sliver: SliverToBoxAdapter(
                child: _LocalMusicHero(
                  tracks: localMusic.tracks,
                  directories: localMusic.scanDirectories,
                  lastScannedAt: localMusic.lastScannedAt,
                  isScanning: localMusic.isScanning,
                  onPickDirectory: () => ref
                      .read(localMusicControllerProvider.notifier)
                      .pickAndScanDirectory(),
                  onPlayRandom: localMusic.tracks.isEmpty
                      ? null
                      : () {
                          final playable = localMusic.tracks;
                          final index =
                              DateTime.now().millisecond % playable.length;
                          ref
                              .read(musicPlayerControllerProvider.notifier)
                              .playQueue(playable, startIndex: index);
                        },
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabsHeaderDelegate(
                extent: isWideHeader ? 82 : 138,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                    child: isWideHeader
                        ? Row(
                            children: [
                              Expanded(
                                child: _LocalTabs(controller: _tabController),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 280,
                                child: _LocalSearch(
                                  controller: _searchController,
                                  keyword: _keyword,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _LocalTabs(controller: _tabController),
                              const SizedBox(height: 8),
                              _LocalSearch(
                                controller: _searchController,
                                keyword: _keyword,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: localMusic.tracks.isEmpty && !localMusic.isScanning
            ? _EmptyLocalLibrary(
                isWeb: kIsWeb,
                onPickDirectory: () => ref
                    .read(localMusicControllerProvider.notifier)
                    .pickAndScanDirectory(),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _TrackListView(tracks: tracks),
                  _AlbumGroupView(groups: _groupByAlbum(tracks)),
                  _ArtistGroupView(groups: _groupByArtist(tracks)),
                  _DirectoryGroupView(groups: _groupByDirectory(tracks)),
                  _TrackListView(
                    tracks: tracks.where((track) => track.isLiked).toList(),
                    emptyText: '还没有喜欢的本地歌曲',
                  ),
                ],
              ),
      ),
      floatingActionButton: localMusic.tracks.isEmpty
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('播放全部'),
              onPressed: () => ref
                  .read(musicPlayerControllerProvider.notifier)
                  .playQueue(localMusic.tracks),
            ),
    );
  }

  List<Track> _filterTracks(List<Track> tracks) {
    final sorted = [...tracks]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    if (_keyword.isEmpty) {
      return sorted;
    }
    return sorted.where((track) {
      final fields = [
        track.title,
        track.album,
        track.artists.join(' '),
        track.filePath == null ? null : p.dirname(track.filePath!),
      ].whereType<String>().join(' ').toLowerCase();
      return fields.contains(_keyword);
    }).toList();
  }

  Map<String, List<Track>> _groupByAlbum(List<Track> tracks) {
    return _groupBy(tracks, (track) => track.album ?? '未知专辑');
  }

  Map<String, List<Track>> _groupByArtist(List<Track> tracks) {
    return _groupBy(
      tracks,
      (track) => track.artists.isEmpty ? '未知艺术家' : track.artists.first,
    );
  }

  Map<String, List<Track>> _groupByDirectory(List<Track> tracks) {
    return _groupBy(tracks, (track) {
      final filePath = track.filePath;
      if (filePath == null) {
        return '未知目录';
      }
      return p.basename(p.dirname(filePath));
    });
  }

  Map<String, List<Track>> _groupBy(
    List<Track> tracks,
    String Function(Track track) keyOf,
  ) {
    final groups = <String, List<Track>>{};
    for (final track in tracks) {
      groups.putIfAbsent(keyOf(track), () => []).add(track);
    }
    return Map.fromEntries(
      groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }
}

class _LocalTabs extends StatelessWidget {
  const _LocalTabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      isScrollable: true,
      tabs: const [
        Tab(text: '歌曲'),
        Tab(text: '专辑'),
        Tab(text: '艺术家'),
        Tab(text: '目录'),
        Tab(text: '喜欢'),
      ],
    );
  }
}

class _LocalSearch extends StatelessWidget {
  const _LocalSearch({required this.controller, required this.keyword});

  final TextEditingController controller;
  final String keyword;

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      controller: controller,
      hintText: '搜索本地音乐',
      leading: const Icon(Icons.search_rounded),
      trailing: keyword.isEmpty
          ? null
          : [
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: controller.clear,
              ),
            ],
    );
  }
}

class _LocalMusicHero extends StatelessWidget {
  const _LocalMusicHero({
    required this.tracks,
    required this.directories,
    required this.lastScannedAt,
    required this.isScanning,
    required this.onPickDirectory,
    required this.onPlayRandom,
  });

  final List<Track> tracks;
  final List<String> directories;
  final DateTime? lastScannedAt;
  final bool isScanning;
  final VoidCallback onPickDirectory;
  final VoidCallback? onPlayRandom;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalDuration = tracks.fold<Duration>(
      Duration.zero,
      (value, track) => value + track.duration,
    );
    final totalSize = tracks.fold<int>(
      0,
      (value, track) => value + (track.fileSizeBytes ?? 0),
    );
    final lyricTrack = tracks.firstWhere(
      (track) => track.lyrics?.trim().isNotEmpty == true,
      orElse: () => tracks.isEmpty
          ? const Track(id: '', title: '', artists: [])
          : tracks.first,
    );

    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            final stats = _StatsGrid(
              subtitle: lastScannedAt == null
                  ? '尚未扫描'
                  : '上次扫描：${_formatDateTime(lastScannedAt!)}',
              items: [
                ('全部歌曲', '${tracks.length} 首'),
                ('歌曲总时长', _formatDuration(totalDuration)),
                ('扫描目录', '${directories.length} 个'),
                ('歌曲占用', _formatBytes(totalSize)),
              ],
            );
            final lyric = _LyricTeaser(
              track: lyricTrack.id.isEmpty ? null : lyricTrack,
              onTap: onPlayRandom,
            );
            return isWide
                ? Row(
                    children: [
                      Expanded(flex: 3, child: stats),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: lyric),
                    ],
                  )
                : Column(children: [stats, const SizedBox(height: 16), lyric]);
          },
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    return '${value.toStringAsFixed(index == 0 ? 0 : 1)} ${units[index]}';
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.items, required this.subtitle});

  final List<(String, String)> items;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.audio_file_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '本地歌曲',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.8,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.$1, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      item.$2,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LyricTeaser extends StatelessWidget {
  const _LyricTeaser({required this.track, required this.onTap});

  final Track? track;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lines =
        track?.lyrics
            ?.split('\n')
            .map((line) => line.replaceAll(RegExp(r'\[[^\]]+\]'), '').trim())
            .where((line) => line.isNotEmpty)
            .take(4)
            .toList() ??
        const <String>[];

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          height: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('歌词摘录', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Expanded(
                child: lines.isEmpty
                    ? Text(
                        '扫描含歌词的歌曲后，这里会显示一段本地歌词。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in lines)
                            Text(
                              line,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                        ],
                      ),
              ),
              if (track != null)
                Text(
                  '${track!.artists.join(' / ')} - ${track!.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackListView extends ConsumerWidget {
  const _TrackListView({required this.tracks, this.emptyText = '没有匹配的歌曲'});

  final List<Track> tracks;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(musicPlayerControllerProvider);
    if (tracks.isEmpty) {
      return Center(child: Text(emptyText));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TrackTile(
            selected: player.currentTrack?.id == track.id,
            track: _toTileData(track),
            onTap: () => ref
                .read(musicPlayerControllerProvider.notifier)
                .playQueue(tracks, startIndex: index),
            trailing: _TrackMenu(track: track),
          ),
        );
      },
    );
  }
}

class _AlbumGroupView extends StatelessWidget {
  const _AlbumGroupView({required this.groups});

  final Map<String, List<Track>> groups;

  @override
  Widget build(BuildContext context) {
    return _GroupListView(
      groups: groups,
      icon: Icons.album_rounded,
      subtitleOf: (tracks) => '${tracks.length} 首歌曲',
    );
  }
}

class _ArtistGroupView extends StatelessWidget {
  const _ArtistGroupView({required this.groups});

  final Map<String, List<Track>> groups;

  @override
  Widget build(BuildContext context) {
    return _GroupListView(
      groups: groups,
      icon: Icons.person_rounded,
      subtitleOf: (tracks) => '${tracks.length} 首歌曲',
    );
  }
}

class _DirectoryGroupView extends StatelessWidget {
  const _DirectoryGroupView({required this.groups});

  final Map<String, List<Track>> groups;

  @override
  Widget build(BuildContext context) {
    return _GroupListView(
      groups: groups,
      icon: Icons.folder_rounded,
      subtitleOf: (tracks) {
        final firstPath = tracks.first.filePath;
        return firstPath == null
            ? '${tracks.length} 首歌曲'
            : p.dirname(firstPath);
      },
    );
  }
}

class _GroupListView extends StatelessWidget {
  const _GroupListView({
    required this.groups,
    required this.icon,
    required this.subtitleOf,
  });

  final Map<String, List<Track>> groups;
  final IconData icon;
  final String Function(List<Track> tracks) subtitleOf;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Center(child: Text('没有匹配的内容'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
      children: [
        for (final entry in groups.entries) ...[
          M3SectionHeader(
            title: entry.key,
            actionLabel: '${entry.value.length} 首',
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon(icon)),
              title: Text(entry.key),
              subtitle: Text(
                subtitleOf(entry.value),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _TrackMenu extends ConsumerWidget {
  const _TrackMenu({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(
      localPlaylistControllerProvider.select((state) => state.playlists),
    );

    return PopupMenuButton<String>(
      tooltip: '更多',
      onSelected: (action) {
        switch (action) {
          case 'playNext':
            ref.read(musicPlayerControllerProvider.notifier).insertNext(track);
          case 'toggleLiked':
            ref.read(localMusicControllerProvider.notifier).toggleLiked(track);
          case 'showInFolder':
            _showInFolder(context, track);
          case 'createPlaylist':
            _showCreatePlaylistDialog(context, ref, [track]);
          default:
            if (action.startsWith('addTo:')) {
              final playlistId = action.substring(6);
              ref.read(localPlaylistControllerProvider.notifier).addTracks(
                playlistId,
                [track],
              );
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已添加到歌单')));
            }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'playNext',
          child: ListTile(
            leading: Icon(Icons.playlist_add_rounded),
            title: Text('下一首播放'),
          ),
        ),
        PopupMenuItem(
          value: 'toggleLiked',
          child: ListTile(
            leading: Icon(
              track.isLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
            title: Text(track.isLiked ? '取消喜欢' : '喜欢'),
          ),
        ),
        PopupMenuDivider(),
        ...playlists.map(
          (playlist) => PopupMenuItem(
            value: 'addTo:${playlist.id}',
            child: ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: Text(playlist.name),
              subtitle: Text('${playlist.trackCount} 首歌曲'),
            ),
          ),
        ),
        if (playlists.isNotEmpty) const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'createPlaylist',
          child: ListTile(
            leading: Icon(Icons.add_rounded),
            title: Text('创建新歌单'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'showInFolder',
          child: ListTile(
            leading: Icon(Icons.folder_open_rounded),
            title: Text('显示所在目录'),
          ),
        ),
      ],
    );
  }

  void _showCreatePlaylistDialog(
    BuildContext context,
    WidgetRef ref,
    List<Track> tracks,
  ) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('创建新歌单'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '输入歌单名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  return;
                }
                final notifier = ref.read(
                  localPlaylistControllerProvider.notifier,
                );
                final playlist = await notifier.createPlaylist(name);
                if (playlist != null && tracks.isNotEmpty) {
                  await notifier.addTracks(playlist.id, tracks);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
  }

  void _showInFolder(BuildContext context, Track track) {
    final filePath = track.filePath;
    if (filePath == null) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(p.dirname(filePath))));
  }
}

class _TabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TabsHeaderDelegate({required this.child, required this.extent});

  final Widget child;
  final double extent;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _TabsHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _EmptyLocalLibrary extends StatelessWidget {
  const _EmptyLocalLibrary({
    required this.isWeb,
    required this.onPickDirectory,
  });

  final bool isWeb;
  final VoidCallback onPickDirectory;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              isWeb ? 'Web 客户端使用云端搜索播放' : '选择一个音乐目录开始扫描',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isWeb
                  ? '浏览器版暂不支持扫描本地目录，可在搜索页使用网易云登录态播放云端歌曲、歌词和封面。'
                  : '支持 MP3、FLAC、M4A、OGG、WAV 等格式，并会读取标签、封面和同名 LRC。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: isWeb ? () => context.go('/search') : onPickDirectory,
              icon: Icon(
                isWeb ? Icons.cloud_queue_rounded : Icons.folder_open_rounded,
              ),
              label: Text(isWeb ? '打开云端搜索' : '选择目录'),
            ),
          ],
        ),
      ),
    );
  }
}

TrackTileData _toTileData(Track track) {
  return TrackTileData(
    id: track.id,
    title: track.title,
    subtitle: [
      track.artists.join(' / '),
      if (track.album != null) track.album!,
    ].join(' · '),
    duration: track.durationMs == 0 ? null : track.duration,
    coverPath: track.coverUrl,
  );
}
