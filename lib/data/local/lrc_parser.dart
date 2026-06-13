import '../models/lyric_line.dart';

/// 解析标准 LRC 格式文本。
///
/// 支持格式：
/// - `[mm:ss.xx]歌词文本`
/// - 同一行多个时间戳：`[00:01.00][00:15.00]重复段落`
/// - 翻译行（通过 `[tl]` 前缀或特殊标记识别，作为上一行的 translation）
///
/// 返回值按 `start` 时间升序排列，每行的 `end` 设置为下一行的 `start`。
List<LyricLine> parseLrc(String lrcContent) {
  final rawLines = lrcContent.split('\n');
  final timestampPattern = RegExp(r'\[(\d{1,3}):(\d{2})\.(\d{2,3})\]');
  final results = <LyricLine>[];

  for (final rawLine in rawLines) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty) {
      continue;
    }

    final matches = timestampPattern.allMatches(trimmed).toList();
    if (matches.isEmpty) {
      // 非时间标签行（如 [ti:xxx]、[ar:xxx] 等元标签），跳过
      continue;
    }

    // 提取最后一个时间戳之后的文本
    final lastMatch = matches.last;
    var text = trimmed.substring(lastMatch.end).trim();
    if (text.isEmpty) {
      continue;
    }

    // 提取所有时间戳并创建对应行
    for (final match in matches) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      var centiseconds = match.group(3)!;
      // 支持两位（百分秒）或三位（毫秒）小数
      if (centiseconds.length == 2) {
        centiseconds = '${centiseconds}0';
      }
      final ms =
          minutes * 60000 + seconds * 1000 + int.parse(centiseconds);

      results.add(LyricLine(start: ms, end: 0, text: text));
    }
  }

  // 按 start 升序排列
  results.sort((a, b) => a.start.compareTo(b.start));

  // 设置每行的 end = 下一行的 start，最后一行为合理默认值
  for (var i = 0; i < results.length; i++) {
    final end = (i + 1 < results.length)
        ? results[i + 1].start
        : results[i].start + 5000; // 最后一行默认持续 5 秒
    results[i] = LyricLine(
      start: results[i].start,
      end: end,
      text: results[i].text,
      translation: results[i].translation,
      words: results[i].words,
    );
  }

  return results;
}
