import '../models/lyric_line.dart';

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
  final chinesePattern = RegExp(r'[\u4E00-\u9FFF]');
  final lyricMap = <int, List<LyricLine>>{};
  final plainLines = <LyricLine>[];

  for (final match in extractLinePattern.allMatches(lrcContent.trim())) {
    final timestamps = match.namedGroup('timestamps') ?? '';
    final content = match.namedGroup('content')?.trim() ?? '';
    if (content.isEmpty) {
      continue;
    }

    final yrcLine = _parseYrcLine(timestamps, content);
    if (yrcLine != null) {
      lyricMap.putIfAbsent(yrcLine.start, () => []).add(yrcLine);
      continue;
    }

    final wrcLine = _parseWrcLine(timestamps, content);
    if (wrcLine != null) {
      lyricMap.putIfAbsent(wrcLine.start, () => []).add(wrcLine);
      continue;
    }

    for (final start in _parseLrcTimestamps(timestamps)) {
      plainLines.add(LyricLine(start: start, end: 0, text: content));
    }
  }

  plainLines.sort((a, b) => a.start.compareTo(b.start));
  for (var index = 0; index < plainLines.length; index++) {
    final current = plainLines[index];
    final line = LyricLine(
      start: current.start,
      end: _nextDistinctStart(plainLines, index) ?? current.start + 5000,
      text: current.text,
    );
    lyricMap.putIfAbsent(line.start, () => []).add(line);
  }

  final result = <LyricLine>[];
  final entries = lyricMap.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  for (final entry in entries) {
    final lines = entry.value;
    if (lines.isEmpty) {
      continue;
    }

    var base = lines.first;
    for (final candidate in lines.skip(1)) {
      if (candidate.text.isNotEmpty &&
          candidate.text != base.text &&
          (base.translation == null ||
              chinesePattern.hasMatch(candidate.text))) {
        base = _copyWithTranslation(base, candidate.text);
      }
    }
    result.add(base);
  }

  return result;
}

int? _nextDistinctStart(List<LyricLine> lines, int index) {
  final currentStart = lines[index].start;
  for (var nextIndex = index + 1; nextIndex < lines.length; nextIndex++) {
    final nextStart = lines[nextIndex].start;
    if (nextStart != currentStart) {
      return nextStart;
    }
  }
  return null;
}

LyricLine _copyWithTranslation(LyricLine line, String translation) {
  return LyricLine(
    start: line.start,
    end: line.end,
    text: line.text,
    translation: translation,
    words: line.words,
  );
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
