const lyricSourceMarkerPrefix = '# flutter_music lyric-source:';
const lyricSourceMain = 'main';
const lyricSourceTranslation = 'translation';
const lyricSourceRomanization = 'romanization';

String markLyricSource(String source) {
  return '$lyricSourceMarkerPrefix$source';
}
