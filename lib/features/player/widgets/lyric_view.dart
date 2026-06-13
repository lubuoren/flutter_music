import 'package:flutter/material.dart';

import '../../../data/models/lyric_line.dart';

class LyricView extends StatefulWidget {
  const LyricView({
    super.key,
    required this.lines,
    this.currentIndex,
    this.position = Duration.zero,
    this.textAlign = TextAlign.left,
    this.onLineTap,
  });

  final List<LyricLine> lines;
  final int? currentIndex;
  final Duration position;
  final TextAlign textAlign;
  final ValueChanged<LyricLine>? onLineTap;

  @override
  State<LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends State<LyricView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  int? _lastIndex;

  @override
  void initState() {
    super.initState();
    _lastIndex = widget.currentIndex;
    if (widget.currentIndex != null) {
      _scrollToCurrentLine();
    }
  }

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lineContext = _lineKeys[index]?.currentContext;
      if (!mounted || lineContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        lineContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
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

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0, 0.25, 0.75, 1],
        ).createShader(bounds);
      },
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 180),
        children: [
          for (var index = 0; index < widget.lines.length; index++)
            _LyricLineTile(
              key: _lineKeys.putIfAbsent(index, GlobalKey.new),
              line: widget.lines[index],
              isCurrent: index == widget.currentIndex,
              positionMs: widget.position.inMilliseconds,
              textAlign: widget.textAlign,
              onTap: widget.onLineTap == null
                  ? null
                  : () => widget.onLineTap!(widget.lines[index]),
            ),
        ],
      ),
    );
  }
}

class _LyricLineTile extends StatelessWidget {
  const _LyricLineTile({
    super.key,
    required this.line,
    required this.isCurrent,
    required this.positionMs,
    required this.textAlign,
    this.onTap,
  });

  final LyricLine line;
  final bool isCurrent;
  final int positionMs;
  final TextAlign textAlign;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final alignment = switch (textAlign) {
      TextAlign.center => CrossAxisAlignment.center,
      TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };

    return AnimatedScale(
      scale: isCurrent ? 1 : 0.95,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: _scaleAlignment(textAlign),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: alignment,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                style: theme.textTheme.headlineSmall!.copyWith(
                  fontSize: 28,
                  color: _lineColor(colorScheme),
                  fontWeight: FontWeight.w600,
                  height: 1.18,
                ),
                child: _LyricText(
                  line: line,
                  colorScheme: colorScheme,
                  isCurrent: isCurrent,
                  positionMs: positionMs,
                  textAlign: textAlign,
                ),
              ),
              if (line.translation != null && line.translation!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontSize: 26,
                      color: isCurrent
                          ? colorScheme.onSurface.withValues(alpha: 0.82)
                          : colorScheme.onSurface.withValues(alpha: 0.38),
                      fontWeight: FontWeight.w600,
                      height: 1.18,
                    ),
                    child: Text(
                      line.translation!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: textAlign,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Alignment _scaleAlignment(TextAlign textAlign) {
    return switch (textAlign) {
      TextAlign.center => Alignment.center,
      TextAlign.right || TextAlign.end => Alignment.centerRight,
      _ => Alignment.centerLeft,
    };
  }

  Color _lineColor(ColorScheme colorScheme) {
    if (!isCurrent || line.isWordByWord) {
      return colorScheme.onSurface.withValues(alpha: 0.46);
    }
    return colorScheme.onSurface;
  }
}

class _LyricText extends StatelessWidget {
  const _LyricText({
    required this.line,
    required this.colorScheme,
    required this.isCurrent,
    required this.positionMs,
    required this.textAlign,
  });

  final LyricLine line;
  final ColorScheme colorScheme;
  final bool isCurrent;
  final int positionMs;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    if (!line.isWordByWord) {
      return Text(
        line.text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      );
    }

    final playedColor = colorScheme.onSurface;
    final unplayedColor = colorScheme.onSurface.withValues(alpha: 0.46);
    return Text.rich(
      TextSpan(
        children: [
          for (final word in line.words)
            TextSpan(
              text: word.text,
              style: TextStyle(
                color: isCurrent && positionMs >= word.start
                    ? playedColor
                    : unplayedColor,
              ),
            ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
    );
  }
}
