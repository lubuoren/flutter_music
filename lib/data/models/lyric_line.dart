/// 单个字/词的时间片段，用于逐字歌词（LDDC 格式）。
class LyricWord {
  const LyricWord({required this.text, required this.start, required this.end});

  final String text;

  /// 起始时间（毫秒）。
  final int start;

  /// 结束时间（毫秒）。
  final int end;
}

/// 一行歌词，对应 VutronMusic 的 lyricLine 类型。
///
/// 同时支持普通 LRC（整行）与逐字歌词（words 非空）。
class LyricLine {
  const LyricLine({
    required this.start,
    required this.end,
    required this.text,
    this.translation,
    this.words = const [],
  });

  /// 起始时间（毫秒）。
  final int start;

  /// 结束时间（毫秒）。
  final int end;

  /// 整行歌词文本。
  final String text;

  /// 翻译文本。
  final String? translation;

  /// 逐字时间片段。为空时表示普通整行歌词。
  final List<LyricWord> words;

  bool get isWordByWord => words.isNotEmpty;
}
