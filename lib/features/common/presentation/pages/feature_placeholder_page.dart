import 'package:flutter/material.dart';

class FeaturePlaceholderPage extends StatelessWidget {
  const FeaturePlaceholderPage({
    super.key,
    required this.title,
    required this.features,
  });

  final String title;
  final List<String> features;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Hero(
              tag: 'feature-$title',
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '按 VutronMusic 原功能边界预留页面，后续逐项接入真实业务逻辑。',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final feature = features[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(feature),
                    subtitle: Text('功能等价性检查项：$title / ${index + 1}'),
                  ),
                );
              }, childCount: features.length),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('已保留 $title 功能入口')));
        },
        icon: const Icon(Icons.playlist_play_rounded),
        label: const Text('查看功能清单'),
      ),
    );
  }
}
