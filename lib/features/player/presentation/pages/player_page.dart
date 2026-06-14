import 'dart:async';
import 'dart:math' as math;

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../../core/platform/cover_image_bytes.dart';
import '../../../../data/local/local_music_repository.dart';
import '../../../../data/models/lyric_line.dart';
import '../../../../data/models/track.dart';
import '../../../../widgets/resilient_cover_image.dart';
import '../../application/lyric_controller.dart';
import '../../application/player_controller.dart';
import '../../widgets/lyric_view.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  var _showPortraitLyrics = false;

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(
      musicPlayerControllerProvider.select((state) => state.currentTrack),
    );

    return LayoutBuilder(
      builder: (context, pageConstraints) {
        final isWide = pageConstraints.maxWidth >= 900;
        final usesSideBySideLayout =
            isWide || pageConstraints.maxWidth > pageConstraints.maxHeight;
        final detail = _TrackDetail(
          track: track,
          isWide: isWide,
          showInlineLyrics: usesSideBySideLayout,
          showLyricsAction: false,
        );

        return Theme(
          data: _playerForegroundTheme(context),
          child: Scaffold(
            extendBody: true,
            extendBodyBehindAppBar: true,
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.expand_more_rounded),
                onPressed: () => context.pop(),
                tooltip: '收起',
              ),
              title: const Text('正在播放'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.queue_music_rounded),
                  tooltip: '播放队列',
                  onPressed: () => context.push('/next'),
                ),
                IconButton(
                  icon: const Icon(Icons.comment_outlined),
                  tooltip: '评论',
                  onPressed: track == null
                      ? null
                      : () => context.push('/comments/track/${track.id}'),
                ),
              ],
            ),
            body: Stack(
              fit: StackFit.expand,
              children: [
                _PlayerPageBackground(coverUrl: track?.coverUrl),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      24,
                      kToolbarHeight + 16,
                      24,
                      24,
                    ),
                    child: usesSideBySideLayout
                        ? Row(
                            children: [
                              Expanded(
                                child: _LandscapeCoverPanel(track: track),
                              ),
                              const SizedBox(width: 32),
                              Expanded(child: detail),
                            ],
                          )
                        : _PortraitMediaStage(
                            track: track,
                            showLyrics: _showPortraitLyrics,
                            onToggle: _togglePortraitStage,
                          ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: usesSideBySideLayout
                ? null
                : const _PlayerControlPanel(),
          ),
        );
      },
    );
  }

  ThemeData _playerForegroundTheme(BuildContext context) {
    final base = Theme.of(context);
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: base.colorScheme.primary,
          brightness: Brightness.dark,
        ).copyWith(
          surface: Colors.transparent,
          onSurface: Colors.white,
          onSurfaceVariant: Colors.white.withValues(alpha: 0.74),
        );
    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: base.textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      iconTheme: base.iconTheme.copyWith(color: colorScheme.onSurface),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: colorScheme.primary,
        thumbColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.2),
      ),
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.onSurface.withValues(alpha: 0.2),
      ),
    );
  }

  void _togglePortraitStage() {
    setState(() {
      _showPortraitLyrics = !_showPortraitLyrics;
    });
  }
}

class _PlayerPageBackground extends StatefulWidget {
  const _PlayerPageBackground({required this.coverUrl});

  final String? coverUrl;

  @override
  State<_PlayerPageBackground> createState() => _PlayerPageBackgroundState();
}

class _PlayerPageBackgroundState extends State<_PlayerPageBackground> {
  _VutronGradientColors? _gradientColors;
  var _gradientRequestId = 0;

  @override
  void initState() {
    super.initState();
    _updateGradientFuture();
  }

  @override
  void didUpdateWidget(covariant _PlayerPageBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl) {
      _updateGradientFuture();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    setState(_updateGradientFuture);
  }

  void _updateGradientFuture() {
    final requestId = ++_gradientRequestId;
    final candidates = coverImageUrlCandidates(widget.coverUrl);
    if (candidates.isEmpty) {
      _gradientColors = null;
      return;
    }

    unawaited(
      _vutronGradientFromCover(candidates)
          .then((colors) {
            if (!mounted || requestId != _gradientRequestId) {
              return;
            }
            setState(() {
              _gradientColors = colors;
            });
          })
          .catchError((Object error, StackTrace stackTrace) {
            debugPrint('Player background extraction failed: $error');
            if (mounted && requestId == _gradientRequestId) {
              setState(() {
                _gradientColors = null;
              });
            }
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _gradientColors;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      child: colors == null
          ? const SizedBox.expand(key: ValueKey('empty-player-gradient'))
          : _GradientPlayerBackground(
              key: ValueKey('${widget.coverUrl}-${colors.primary.toARGB32()}'),
              colors: colors,
            ),
    );
  }

  Future<_VutronGradientColors?> _vutronGradientFromCover(
    List<String> candidates,
  ) async {
    for (final candidate in candidates) {
      try {
        final bytes = await coverImageBytes(candidate);
        if (bytes == null || bytes.isEmpty) {
          continue;
        }
        final baseArgb = await compute(_extractVutronGradientBaseArgb, bytes);
        if (baseArgb != null) {
          return _VutronGradientColors.fromBase(Color(baseArgb));
        }
      } catch (error) {
        debugPrint('Skipping cover candidate $candidate: $error');
        continue;
      }
    }
    return null;
  }
}

Future<int?> _extractVutronGradientBaseArgb(Uint8List bytes) async {
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width == 0 || decoded.height == 0) {
    return null;
  }

  const maxDimension = 192;
  final resized = decoded.width > maxDimension || decoded.height > maxDimension
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxDimension : null,
          height: decoded.height > decoded.width ? maxDimension : null,
          interpolation: img.Interpolation.average,
        )
      : decoded;
  final rgbaBytes = resized.getBytes(order: img.ChannelOrder.rgba);
  final averageArgb = _averageImageArgb(rgbaBytes);
  try {
    final palette = await PaletteGenerator.fromByteData(
      EncodedImage(
        ByteData.sublistView(rgbaBytes),
        width: resized.width,
        height: resized.height,
      ),
      maximumColorCount: 16,
    );
    final base = _vutronGradientBaseColor(palette);
    if (base != null) {
      return base.toARGB32();
    }
  } on Object {
    return averageArgb;
  }
  return averageArgb;
}

Color? _vutronGradientBaseColor(PaletteGenerator palette) {
  final swatches = <PaletteColor?>[
    palette.darkMutedColor,
    palette.vibrantColor,
    palette.mutedColor,
    palette.darkVibrantColor,
    palette.dominantColor,
    palette.lightMutedColor,
    palette.lightVibrantColor,
    ...palette.paletteColors,
  ];
  final seen = <int>{};

  for (final swatch in swatches) {
    final color = swatch?.color;
    if (color == null || !seen.add(color.toARGB32())) {
      continue;
    }
    if (_isUsableVutronGradientBase(color)) {
      return color;
    }
  }

  return null;
}

int _averageImageArgb(Uint8List rgbaBytes) {
  var red = 0;
  var green = 0;
  var blue = 0;
  var count = 0;

  for (var index = 0; index + 3 < rgbaBytes.length; index += 4) {
    final alpha = rgbaBytes[index + 3];
    if (alpha < 16) {
      continue;
    }
    red += rgbaBytes[index];
    green += rgbaBytes[index + 1];
    blue += rgbaBytes[index + 2];
    count++;
  }

  if (count == 0) {
    return 0xFF000000;
  }

  final averageRed = red ~/ count;
  final averageGreen = green ~/ count;
  final averageBlue = blue ~/ count;
  return 0xFF000000 | (averageRed << 16) | (averageGreen << 8) | averageBlue;
}

bool _isUsableVutronGradientBase(Color color) {
  final colors = _VutronGradientColors.fromBase(color);
  final minLuminance = math.min(
    colors.primary.computeLuminance(),
    colors.secondary.computeLuminance(),
  );
  final averageLuminance =
      (colors.primary.computeLuminance() +
          colors.secondary.computeLuminance()) /
      2;

  return minLuminance >= 0.015 &&
      averageLuminance >= 0.045 &&
      averageLuminance <= 0.72;
}

class _VutronGradientColors {
  const _VutronGradientColors({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;

  factory _VutronGradientColors.fromBase(Color base) {
    return _VutronGradientColors(
      primary: _darken(base, 0.1),
      secondary: _rotateHue(_lighten(base, 0.2), -30),
    );
  }

  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness * (1 - amount)).clamp(0, 1).toDouble())
        .toColor();
  }

  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness * (1 + amount)).clamp(0, 1).toDouble())
        .toColor();
  }

  static Color _rotateHue(Color color, double degrees) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withHue((hsl.hue + degrees) % 360).toColor();
  }
}

class _GradientPlayerBackground extends StatelessWidget {
  const _GradientPlayerBackground({super.key, required this.colors});

  final _VutronGradientColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
          colors: [colors.primary, colors.secondary],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class PlayerLyricsPage extends ConsumerWidget {
  const PlayerLyricsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      musicPlayerControllerProvider.select((state) => state.currentTrack),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          track?.title ?? '歌词',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: '播放队列',
            onPressed: () => context.push('/next'),
          ),
          IconButton(
            icon: const Icon(Icons.comment_outlined),
            tooltip: '评论',
            onPressed: track == null
                ? null
                : () => context.push('/comments/track/${track.id}'),
          ),
        ],
      ),
      body: track == null
          ? Center(
              child: Text(
                '从本地音乐选择一首歌开始播放',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            )
          : const _LyricsPageBody(),
      bottomNavigationBar: const _PlayerControlPanel(),
    );
  }
}

class _LyricsPageBody extends ConsumerWidget {
  const _LyricsPageBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(musicPlayerControllerProvider);
    final lyricState = ref.watch(lyricControllerProvider);
    final track = player.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          children: [
            Text(
              [
                track.artists.join(' / '),
                if (track.album != null) track.album!,
              ].join(' · '),
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            _LyricTools(track: track, alignment: Alignment.center),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isPortrait =
                      constraints.maxWidth <= constraints.maxHeight;
                  return _CenteredLyricView(
                    widthFactor: isPortrait ? 4 / 5 : 1,
                    lines: lyricState.lines,
                    currentIndex: lyricState.currentIndex,
                    secondaryTextMode: lyricState.secondaryTextMode,
                    position:
                        player.position +
                        Duration(milliseconds: (track.offset * 1000).round()),
                    onLineTap: (line) {
                      ref
                          .read(musicPlayerControllerProvider.notifier)
                          .seek(Duration(milliseconds: line.start));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortraitMediaStage extends ConsumerWidget {
  const _PortraitMediaStage({
    required this.track,
    required this.showLyrics,
    required this.onToggle,
  });

  final Track? track;
  final bool showLyrics;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shouldShowLyrics = showLyrics && track != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.035),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: shouldShowLyrics
            ? _PortraitLyricsStage(
                key: ValueKey('lyrics-${track!.id}'),
                track: track!,
              )
            : _PortraitCoverStage(
                key: ValueKey('cover-${track?.id ?? 'empty'}'),
                track: track,
              ),
      ),
    );
  }
}

class _PortraitCoverStage extends StatelessWidget {
  const _PortraitCoverStage({super.key, required this.track});

  final Track? track;

  @override
  Widget build(BuildContext context) {
    final track = this.track;
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(flex: 6, child: _AlbumCover(track: track)),
        const SizedBox(height: 20),
        if (track == null)
          Text(
            '从本地音乐选择一首歌开始播放',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          )
        else ...[
          Text(
            track.title,
            style: theme.textTheme.headlineMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            [
              track.artists.join(' / '),
              if (track.album != null) track.album!,
            ].join(' · '),
            style: theme.textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _PortraitLyricsStage extends ConsumerWidget {
  const _PortraitLyricsStage({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(musicPlayerControllerProvider);
    final lyricState = ref.watch(lyricControllerProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          _LyricTools(track: track, alignment: Alignment.center),
          const SizedBox(height: 12),
          Expanded(
            child: _CenteredLyricView(
              widthFactor: 4 / 5,
              lines: lyricState.lines,
              currentIndex: lyricState.currentIndex,
              secondaryTextMode: lyricState.secondaryTextMode,
              position:
                  player.position +
                  Duration(milliseconds: (track.offset * 1000).round()),
              onLineTap: (line) {
                ref
                    .read(musicPlayerControllerProvider.notifier)
                    .seek(Duration(milliseconds: line.start));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredLyricView extends StatelessWidget {
  const _CenteredLyricView({
    required this.widthFactor,
    required this.lines,
    required this.currentIndex,
    required this.secondaryTextMode,
    required this.position,
    required this.onLineTap,
  });

  final double widthFactor;
  final List<LyricLine> lines;
  final int? currentIndex;
  final LyricSecondaryTextMode secondaryTextMode;
  final Duration position;
  final ValueChanged<LyricLine> onLineTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        heightFactor: 1,
        child: LyricView(
          lines: lines,
          currentIndex: currentIndex,
          secondaryTextMode: secondaryTextMode,
          position: position,
          textAlign: TextAlign.center,
          onLineTap: onLineTap,
        ),
      ),
    );
  }
}

class _LandscapeCoverPanel extends StatelessWidget {
  const _LandscapeCoverPanel({required this.track});

  final Track? track;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const estimatedControlsHeight = 132.0;
        final maxPanelWidth = math.min(
          constraints.maxWidth,
          math.max(0.0, constraints.maxHeight - estimatedControlsHeight),
        );

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxPanelWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: _AlbumCover(track: track)),
                const SizedBox(height: 12),
                const _PlayerControlPanel(
                  useSafeArea: false,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AlbumCover extends StatelessWidget {
  const _AlbumCover({required this.track});

  final Track? track;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final coverPath = track?.coverUrl;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primaryContainer, colorScheme.tertiaryContainer],
        ),
      ),
      child: Icon(
        Icons.album_rounded,
        size: 120,
        color: colorScheme.onPrimaryContainer.withValues(alpha: 0.4),
      ),
    );

    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: ResilientCoverImage(coverUrl: coverPath, fallback: fallback),
        ),
      ),
    );
  }
}

class _TrackDetail extends ConsumerWidget {
  const _TrackDetail({
    required this.track,
    required this.isWide,
    required this.showInlineLyrics,
    this.showLyricsAction = true,
  });

  final Track? track;
  final bool isWide;
  final bool showInlineLyrics;
  final bool showLyricsAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = this.track;

    if (track == null) {
      return Center(
        child: Text(
          '从本地音乐选择一首歌开始播放',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    if (!showInlineLyrics) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            track.title,
            style: Theme.of(context).textTheme.headlineMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            [
              track.artists.join(' / '),
              if (track.album != null) track.album!,
            ].join(' · '),
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          _LyricOffsetControls(track: track, alignment: Alignment.center),
          if (showLyricsAction) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.lyrics_rounded),
              label: const Text('查看歌词'),
              onPressed: () => context.push('/player/lyrics'),
            ),
          ],
        ],
      );
    }

    final lyricState = ref.watch(lyricControllerProvider);
    final player = ref.watch(musicPlayerControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.title,
          style: Theme.of(context).textTheme.headlineMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          [
            track.artists.join(' / '),
            if (track.album != null) track.album!,
          ].join(' · '),
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        _LyricTools(track: track),
        const SizedBox(height: 12),
        Expanded(
          child: Align(
            alignment: isWide ? Alignment.centerRight : Alignment.center,
            child: FractionallySizedBox(
              widthFactor: isWide ? 0.9 : 1,
              heightFactor: 1,
              child: LyricView(
                lines: lyricState.lines,
                currentIndex: lyricState.currentIndex,
                secondaryTextMode: lyricState.secondaryTextMode,
                position:
                    player.position +
                    Duration(milliseconds: (track.offset * 1000).round()),
                textAlign: isWide ? TextAlign.left : TextAlign.center,
                onLineTap: (line) {
                  ref
                      .read(musicPlayerControllerProvider.notifier)
                      .seek(Duration(milliseconds: line.start));
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LyricTools extends ConsumerWidget {
  const _LyricTools({
    required this.track,
    this.alignment = Alignment.centerLeft,
  });

  final Track track;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricState = ref.watch(lyricControllerProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LyricOffsetControls(track: track, alignment: alignment),
        if (lyricState.hasSecondaryTextAlternatives)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: alignment,
              child: _LyricSecondaryTextToggle(
                mode: lyricState.secondaryTextMode,
                onChanged: (mode) {
                  ref
                      .read(lyricControllerProvider.notifier)
                      .setSecondaryTextMode(mode);
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _LyricSecondaryTextToggle extends StatelessWidget {
  const _LyricSecondaryTextToggle({
    required this.mode,
    required this.onChanged,
  });

  final LyricSecondaryTextMode mode;
  final ValueChanged<LyricSecondaryTextMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<LyricSecondaryTextMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: LyricSecondaryTextMode.translation,
          label: Text('翻译'),
        ),
        ButtonSegment(
          value: LyricSecondaryTextMode.romanization,
          label: Text('罗马音'),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) {
        onChanged(selection.single);
      },
      style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
    );
  }
}

class _LyricOffsetControls extends ConsumerWidget {
  const _LyricOffsetControls({
    required this.track,
    this.alignment = Alignment.centerLeft,
  });

  final Track track;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: alignment,
      child: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.replay_5_rounded),
            tooltip: '歌词提前 0.5 秒',
            onPressed: () => _adjustOffset(ref, -0.5),
          ),
          ActionChip(
            avatar: Icon(
              Icons.restore_rounded,
              size: 18,
              color: colorScheme.onPrimaryContainer,
            ),
            label: Text(_offsetLabel(track.offset)),
            labelStyle: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
            backgroundColor: colorScheme.primaryContainer,
            side: BorderSide(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.16),
            ),
            onPressed: () => _setOffset(ref, 0),
          ),
          IconButton(
            icon: const Icon(Icons.forward_5_rounded),
            tooltip: '歌词后退 0.5 秒',
            onPressed: () => _adjustOffset(ref, 0.5),
          ),
        ],
      ),
    );
  }

  Future<void> _adjustOffset(WidgetRef ref, double delta) {
    return _setOffset(ref, track.offset + delta);
  }

  Future<void> _setOffset(WidgetRef ref, double value) async {
    await ref
        .read(musicPlayerControllerProvider.notifier)
        .setLyricOffset(track, double.parse(value.toStringAsFixed(1)));
  }

  String _offsetLabel(double offset) {
    if (offset == 0) {
      return '未调整';
    }
    final prefix = offset > 0 ? '延后' : '提前';
    return '$prefix${offset.abs().toStringAsFixed(1)}s';
  }
}

class _PlayerControlPanel extends ConsumerWidget {
  const _PlayerControlPanel({
    this.useSafeArea = true,
    this.padding = const EdgeInsets.fromLTRB(24, 8, 24, 16),
  });

  final bool useSafeArea;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(musicPlayerControllerProvider);
    final controller = ref.read(musicPlayerControllerProvider.notifier);
    final track = player.currentTrack;
    final isLoading =
        player.processingState == ProcessingState.loading ||
        player.processingState == ProcessingState.buffering;

    final panel = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProgressBar(
            progress: player.position,
            buffered: player.bufferedPosition,
            total: player.duration ?? track?.duration ?? Duration.zero,
            onSeek: controller.seek,
            timeLabelTextStyle: Theme.of(context).textTheme.bodySmall,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(
                  track?.isLiked == true
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
                tooltip: track?.isLiked == true ? '取消喜欢' : '喜欢',
                onPressed: track == null || track.type != TrackType.local
                    ? null
                    : () => ref
                          .read(localMusicControllerProvider.notifier)
                          .toggleLiked(track),
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                onPressed: player.hasPrevious ? controller.playPrevious : null,
              ),
              FloatingActionButton(
                onPressed: isLoading ? null : controller.togglePlayPause,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : Icon(
                        player.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: player.hasNext ? controller.playNext : null,
              ),
              IconButton(
                icon: Icon(_loopIcon(player.loopMode)),
                tooltip: '循环模式',
                onPressed: controller.cycleLoopMode,
              ),
            ],
          ),
        ],
      ),
    );

    if (!useSafeArea) {
      return panel;
    }

    return SafeArea(child: panel);
  }

  IconData _loopIcon(LoopMode mode) {
    return switch (mode) {
      LoopMode.off => Icons.repeat_rounded,
      LoopMode.all => Icons.repeat_on_rounded,
      LoopMode.one => Icons.repeat_one_on_rounded,
    };
  }
}
