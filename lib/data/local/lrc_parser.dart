import '../models/lyric_line.dart';
import '../models/lyric_source_marker.dart';

enum _LyricSource { main, translation, romanization }

class _ParsedLyricLine {
  const _ParsedLyricLine({
    required this.line,
    required this.order,
    this.source,
  });

  final LyricLine line;
  final int order;
  final _LyricSource? source;
}

/// 解析歌词文本。
///
/// 支持格式：
/// - `[mm:ss.xx]歌词文本`
/// - 同一行多个时间戳：`[00:01.00][00:15.00]重复段落`
/// - 网易云 YRC：`[start,duration](wordStart,wordDuration,0)字`
/// - WRC/逐字 LRC：`[00:01.000]字[00:01.200]词`
///
/// 返回值按 `start` 时间升序排列，每行的 `end` 设置为下一句不同时间戳的 `start`。
List<LyricLine> parseLrc(String lrcContent) {
  if (lrcContent.trim().isEmpty) {
    return const [];
  }

  final extractLinePattern = RegExp(
    r'^(?<timestamps>(?:\[.+?\])+)(?!\[)(?<content>.+)$',
    multiLine: true,
  );
  final lyricMap = <int, List<_ParsedLyricLine>>{};
  final plainLines = <_ParsedLyricLine>[];
  var currentSource = _LyricSource.main;
  var order = 0;

  for (final rawLine in lrcContent.trim().split('\n')) {
    final source = _sourceFromMarker(rawLine.trim());
    if (source != null) {
      currentSource = source;
      continue;
    }

    final match = extractLinePattern.firstMatch(rawLine.trim());
    if (match == null) {
      continue;
    }
    final timestamps = match.namedGroup('timestamps') ?? '';
    final content = match.namedGroup('content')?.trim() ?? '';
    if (content.isEmpty) {
      continue;
    }

    final yrcLine = _parseYrcLine(timestamps, content);
    if (yrcLine != null) {
      lyricMap
          .putIfAbsent(yrcLine.start, () => [])
          .add(
            _ParsedLyricLine(
              line: yrcLine,
              order: order++,
              source: currentSource,
            ),
          );
      continue;
    }

    final wrcLine = _parseWrcLine(timestamps, content);
    if (wrcLine != null) {
      lyricMap
          .putIfAbsent(wrcLine.start, () => [])
          .add(
            _ParsedLyricLine(
              line: wrcLine,
              order: order++,
              source: currentSource,
            ),
          );
      continue;
    }

    for (final start in _parseLrcTimestamps(timestamps)) {
      plainLines.add(
        _ParsedLyricLine(
          line: LyricLine(start: start, end: 0, text: content),
          order: order++,
          source: currentSource,
        ),
      );
    }
  }

  plainLines.sort((a, b) {
    final startCompare = a.line.start.compareTo(b.line.start);
    return startCompare == 0 ? a.order.compareTo(b.order) : startCompare;
  });
  for (var index = 0; index < plainLines.length; index++) {
    final current = plainLines[index];
    final line = LyricLine(
      start: current.line.start,
      end: _nextDistinctStart(plainLines, index) ?? current.line.start + 5000,
      text: current.line.text,
    );
    lyricMap
        .putIfAbsent(line.start, () => [])
        .add(
          _ParsedLyricLine(
            line: line,
            order: current.order,
            source: current.source,
          ),
        );
  }

  final result = <LyricLine>[];
  final entries = lyricMap.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  for (final entry in entries) {
    final lines = entry.value;
    if (lines.isEmpty) {
      continue;
    }

    result.add(_mergeSameTimestampLines(lines));
  }

  return result;
}

_LyricSource? _sourceFromMarker(String line) {
  if (!line.startsWith(lyricSourceMarkerPrefix)) {
    return null;
  }
  return switch (line.substring(lyricSourceMarkerPrefix.length).trim()) {
    lyricSourceMain => _LyricSource.main,
    lyricSourceTranslation => _LyricSource.translation,
    lyricSourceRomanization => _LyricSource.romanization,
    _ => null,
  };
}

LyricLine _mergeSameTimestampLines(List<_ParsedLyricLine> lines) {
  final main =
      _firstBySource(lines, _LyricSource.main) ?? _firstNonEmptyLine(lines);
  if (main == null) {
    return const LyricLine(start: 0, end: 0, text: '');
  }

  final translation = _firstTextBySource(lines, _LyricSource.translation);
  final romanization = _firstTextBySource(lines, _LyricSource.romanization);
  final inferredTranslation = translation ?? _inferTranslation(lines, main);

  return main.copyWith(
    translation: _differentText(inferredTranslation, main.text),
    romanization: _differentText(romanization, main.text),
  );
}

LyricLine? _firstBySource(List<_ParsedLyricLine> lines, _LyricSource source) {
  for (final item in lines) {
    if (item.source == source && item.line.text.isNotEmpty) {
      return item.line;
    }
  }
  return null;
}

LyricLine? _firstNonEmptyLine(List<_ParsedLyricLine> lines) {
  for (final item in lines) {
    if (item.line.text.isNotEmpty) {
      return item.line;
    }
  }
  return null;
}

String? _firstTextBySource(List<_ParsedLyricLine> lines, _LyricSource source) {
  return _firstBySource(lines, source)?.text;
}

String? _inferTranslation(List<_ParsedLyricLine> lines, LyricLine main) {
  final chinesePattern = RegExp(r'[\u4E00-\u9FFF]');
  String? fallback;
  for (final item in lines) {
    if (item.source != _LyricSource.main || item.line.text == main.text) {
      continue;
    }
    fallback ??= item.line.text;
    if (chinesePattern.hasMatch(item.line.text)) {
      return item.line.text;
    }
  }
  return fallback;
}

String? _differentText(String? value, String mainText) {
  if (value == null || value.isEmpty || value == mainText) {
    return null;
  }
  return value;
}

int? _nextDistinctStart(List<_ParsedLyricLine> lines, int index) {
  final currentStart = lines[index].line.start;
  for (var nextIndex = index + 1; nextIndex < lines.length; nextIndex++) {
    final nextStart = lines[nextIndex].line.start;
    if (nextStart != currentStart) {
      return nextStart;
    }
  }
  return null;
}

LyricLine? _parseYrcLine(String timestamps, String content) {
  if (!RegExp(r'\(\d+,\d+,\d+\)').hasMatch(content)) {
    return null;
  }

  final timeMatch = RegExp(r'\[(\d+),(\d+)\]').firstMatch(timestamps);
  if (timeMatch == null) {
    return null;
  }

  final start = int.parse(timeMatch.group(1)!);
  final duration = int.parse(timeMatch.group(2)!);
  final words = <LyricWord>[];
  final wordPattern = RegExp(r'\((\d+),(\d+),\d+\)([^(]+)');
  for (final wordMatch in wordPattern.allMatches(content)) {
    final wordStart = int.parse(wordMatch.group(1)!);
    final wordDuration = int.parse(wordMatch.group(2)!);
    words.add(
      LyricWord(
        text: wordMatch.group(3) ?? '',
        start: wordStart < 100 ? 100 : wordStart,
        end: wordStart + wordDuration,
      ),
    );
  }

  if (words.isEmpty) {
    return null;
  }

  return LyricLine(
    start: start,
    end: start + duration,
    text: words.map((word) => word.text).join(),
    words: words,
  );
}

LyricLine? _parseWrcLine(String timestamps, String content) {
  final line = '$timestamps$content';
  final wordPattern = RegExp(
    r'(\[\d{1,3}:\d{2}[.:]\d{1,3}\])([^[]*?)(?=(\[\d{1,3}:\d{2}[.:]\d{1,3}\]))',
  );
  final matches = wordPattern.allMatches(line).toList();
  if (matches.isEmpty) {
    return null;
  }

  final words = <LyricWord>[];
  for (final match in matches) {
    final start = _switchTime(match.group(1)!);
    final end = _switchTime(match.group(3)!);
    final text = match.group(2) ?? '';
    if (text.isEmpty) {
      continue;
    }
    words.add(LyricWord(text: text, start: start < 50 ? 50 : start, end: end));
  }

  if (words.isEmpty) {
    return null;
  }

  return LyricLine(
    start: words.first.start,
    end: words.last.end,
    text: words.map((word) => word.text).join(),
    words: words,
  );
}

List<int> _parseLrcTimestamps(String timestamps) {
  final pattern = RegExp(r'\[(\d{1,3}):(\d{2})(?:\.|:)?(\d{1,3})?\]');
  return [
    for (final match in pattern.allMatches(timestamps))
      _timestampToMs(
        minutes: match.group(1)!,
        seconds: match.group(2)!,
        fraction: match.group(3),
      ),
  ];
}

int _switchTime(String timestamp) {
  final match = RegExp(
    r'\[(\d{1,3}):(\d{2})(?:\.|:)?(\d{1,3})?\]',
  ).firstMatch(timestamp);
  if (match == null) {
    return 0;
  }
  return _timestampToMs(
    minutes: match.group(1)!,
    seconds: match.group(2)!,
    fraction: match.group(3),
  );
}

int _timestampToMs({
  required String minutes,
  required String seconds,
  String? fraction,
}) {
  final normalizedFraction = (fraction ?? '0').padRight(3, '0');
  return int.parse(minutes) * 60000 +
      int.parse(seconds) * 1000 +
      int.parse(normalizedFraction);
}
