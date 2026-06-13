import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/models/netease_comment.dart';
import '../../../../data/remote/netease/netease_comment_repository.dart';
import '../../application/netease_comments_controller.dart';

class CommentsPage extends ConsumerWidget {
  const CommentsPage({
    super.key,
    required this.resourceType,
    required this.resourceId,
  });

  final String resourceType;
  final String? resourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = NeteaseCommentsTarget(
      resourceType: resourceType,
      resourceId: resourceId ?? '',
    );
    final provider = neteaseCommentsControllerProvider(target);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 360) {
            controller.loadMore();
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar.large(
                title: const Text('评论'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: '刷新评论',
                    onPressed: controller.refresh,
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: _CommentHeader(
                    state: state,
                    onSortChanged: controller.changeSort,
                  ),
                ),
              ),
              if (state.isLoading && state.comments.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _CommentMessage(
                    icon: Icons.forum_rounded,
                    title: '正在加载评论',
                    subtitle: '稍等一下，正在连接网易云评论区。',
                    loading: true,
                  ),
                )
              else if (state.errorMessage != null && state.comments.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _CommentMessage(
                    icon: Icons.cloud_off_rounded,
                    title: '评论加载失败',
                    subtitle:
                        '${state.errorMessage}\n请确认 api-enhanced 服务地址和登录态可用。',
                  ),
                )
              else if (state.comments.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _CommentMessage(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: '暂无评论',
                    subtitle: '这里暂时还没有评论，换个排序或稍后再来看看。',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                  sliver: SliverList.separated(
                    itemCount: state.comments.length + 1,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 84,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    itemBuilder: (context, index) {
                      if (index == state.comments.length) {
                        return _LoadMoreFooter(state: state);
                      }
                      return _AnimatedCommentTile(
                        key: ValueKey(state.comments[index].id),
                        comment: state.comments[index],
                        index: index,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentHeader extends StatelessWidget {
  const _CommentHeader({required this.state, required this.onSortChanged});

  final NeteaseCommentsState state;
  final ValueChanged<NeteaseCommentSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.comment_rounded, color: colorScheme.primary),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: Text(
                '评论(${state.totalCount})',
                key: ValueKey(state.totalCount),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<NeteaseCommentSort>(
          segments: [
            for (final sort in NeteaseCommentSort.values)
              ButtonSegment(value: sort, label: Text(sort.label)),
          ],
          selected: {state.sort},
          onSelectionChanged: (selected) => onSortChanged(selected.single),
        ),
        if (state.errorMessage != null && state.comments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            state.errorMessage!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _AnimatedCommentTile extends StatelessWidget {
  const _AnimatedCommentTile({
    super.key,
    required this.comment,
    required this.index,
  });

  final NeteaseComment comment;
  final int index;

  @override
  Widget build(BuildContext context) {
    final durationMs = math.min(460, 180 + index * 18);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: _CommentTile(comment: comment),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final NeteaseComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: comment.user.id.isEmpty
          ? null
          : () => context.push('/user/${comment.user.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommentAvatar(user: comment.user),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.user.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.content,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                  if (comment.replied case final replied?) ...[
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.6,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '@${replied.nickname}: ',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: replied.content),
                          ],
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _CommentMeta(comment: comment),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({required this.user});

  final NeteaseCommentUser user;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarUrl = _avatarUrl(user.avatarUrl);

    return CircleAvatar(
      radius: 24,
      backgroundColor: colorScheme.secondaryContainer,
      foregroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
      child: Text(
        user.nickname.isEmpty ? '?' : user.nickname.characters.first,
        style: TextStyle(color: colorScheme.onSecondaryContainer),
      ),
    );
  }

  String? _avatarUrl(String? url) {
    final normalized = url?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return '${normalized.replaceFirst('http:', 'https:')}?param=96y96';
  }
}

class _CommentMeta extends StatelessWidget {
  const _CommentMeta({required this.comment});

  final NeteaseComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(_formatTime(comment.time), style: metaStyle),
        if (comment.ipLocation != null && comment.ipLocation!.isNotEmpty)
          Text('来自${comment.ipLocation}', style: metaStyle),
        _MetaIcon(
          icon: comment.liked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          label: _countLabel(comment.likedCount),
          selected: comment.liked,
        ),
        if (comment.replyCount > 0)
          _MetaIcon(
            icon: Icons.forum_outlined,
            label: _countLabel(comment.replyCount),
          ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inMinutes < 1) {
      return '刚刚';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    }
    return '${time.year}年${time.month}月${time.day}日';
  }

  String _countLabel(int count) {
    if (count <= 0) {
      return '0';
    }
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    }
    return count.toString();
  }
}

class _MetaIcon extends StatelessWidget {
  const _MetaIcon({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = selected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.state});

  final NeteaseCommentsState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      child: Padding(
        key: ValueKey('${state.isLoadingMore}-${state.hasMore}'),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: state.isLoadingMore
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  state.hasMore ? '继续下滑加载更多' : '已经到底了',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
      ),
    );
  }
}

class _CommentMessage extends StatelessWidget {
  const _CommentMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: Column(
            key: ValueKey(title),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (loading) ...[
                const SizedBox(height: 20),
                const SizedBox(width: 160, child: LinearProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
