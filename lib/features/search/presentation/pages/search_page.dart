import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/netease_search_controller.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(neteaseSearchControllerProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('搜索'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                tooltip: '在线音乐设置',
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            sliver: SliverList.list(
              children: [
                SearchBar(
                  controller: _searchController,
                  leading: const Icon(Icons.search_rounded),
                  hintText: '搜索网易云歌曲',
                  trailing: [
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded),
                      tooltip: '搜索',
                      onPressed: _submitSearch,
                    ),
                  ],
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submitSearch(),
                ),
                const SizedBox(height: 16),
                if (state.isLoading)
                  const LinearProgressIndicator()
                else if (state.errorMessage != null)
                  _SearchMessage(
                    icon: Icons.cloud_off_rounded,
                    title: '搜索失败',
                    subtitle:
                        '${state.errorMessage}\n请确认设置页里的 api-enhanced 服务地址可访问。',
                  )
                else if (!state.hasSearched)
                  const _SearchMessage(
                    icon: Icons.manage_search_rounded,
                    title: '开始在线搜索',
                    subtitle:
                        'Phase 4 先接入 api-enhanced 的搜索接口，播放 URL、登录和喜欢歌曲会继续补齐。',
                  )
                else if (state.results.isEmpty)
                  _SearchMessage(
                    icon: Icons.search_off_rounded,
                    title: '没有找到结果',
                    subtitle: '换一个关键词再试试：${state.keyword}',
                  )
                else
                  ...state.results.map(
                    (track) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.music_note_rounded),
                        ),
                        title: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            track.artists.join(' / '),
                            if (track.album != null) track.album!,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.cloud_queue_rounded),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submitSearch() {
    ref
        .read(neteaseSearchControllerProvider.notifier)
        .search(_searchController.text);
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

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
          ],
        ),
      ),
    );
  }
}
