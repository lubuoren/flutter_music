import 'package:flutter/material.dart';

import '../../../data/models/lyric_line.dart';

class LyricView extends StatefulWidget {
  const LyricView({
    super.key,
    required this.lines,
    this.currentIndex,
  });

  final List<LyricLine> lines;
  final int? currentIndex;

  @override
  State<LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends State<LyricView> {
  final ScrollController _scrollController = ScrollController();
  int? _lastIndex;

  @override
  void didUpdateWidget(covariant LyricView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != _lastIndex && widget.currentIndex != null) {
      _lastIndex = widget.currentIndex;
      _scrollToCurrentLine();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentLine() {
    final index = widget.currentIndex;
    if (index == null || index >= widget.lines.length) {
      return;
    }

    if (!_scrollController.hasClients) {
      return;
    }

    // 估算每个项目高度（40px 行高 + 4px 间距 = 44px）
    const itemExtent = 44.0;
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = (index * itemExtent) - (viewportHeight / 2) + (itemExtent / 2);

    _scrollController.animateTo(
      targetOffset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.lines.isEmpty) {
      return Center(
        child: Text(
          '暂无歌词',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 60),
      itemCount: widget.lines.length,
      itemBuilder: (context, index) {
        final line = widget.lines[index];
        final isCurrent = index == widget.currentIndex;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: theme.textTheme.bodyLarge!.copyWith(
              color: isCurrent
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              height: 1.6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(line.text, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (line.translation != null && line.translation!.isNotEmpty)
                  Text(
                    line.translation!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
