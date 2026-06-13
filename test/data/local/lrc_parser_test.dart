import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/data/local/lrc_parser.dart';

void main() {
  group('parseLrc', () {
    test('解析标准 LRC 格式', () {
      const lrc = '[00:01.00]第一行\n[00:05.50]第二行\n[00:10.00]第三行';
      final lines = parseLrc(lrc);

      expect(lines.length, 3);
      expect(lines[0].text, '第一行');
      expect(lines[0].start, 1000);
      expect(lines[0].end, 5500);
      expect(lines[1].text, '第二行');
      expect(lines[1].start, 5500);
      expect(lines[1].end, 10000);
      expect(lines[2].text, '第三行');
      expect(lines[2].start, 10000);
    });

    test('解析多时间戳行', () {
      const lrc = '[00:01.00][00:15.00]重复段落';
      final lines = parseLrc(lrc);

      expect(lines.length, 2);
      expect(lines[0].start, 1000);
      expect(lines[0].text, '重复段落');
      expect(lines[1].start, 15000);
      expect(lines[1].text, '重复段落');
    });

    test('空输入返回空列表', () {
      expect(parseLrc(''), isEmpty);
      expect(parseLrc('   \n  '), isEmpty);
    });

    test('跳过元标签行', () {
      const lrc = '[ti:Title]\n[ar:Artist]\n[00:01.00]歌词';
      final lines = parseLrc(lrc);

      expect(lines.length, 1);
      expect(lines[0].text, '歌词');
    });

    test('跳过无文本时间标签', () {
      const lrc = '[00:01.00]\n[00:05.00]第二行';
      final lines = parseLrc(lrc);

      expect(lines.length, 1);
      expect(lines[0].text, '第二行');
    });

    test('按 start 时间升序排列', () {
      const lrc = '[00:10.00]第三行\n[00:01.00]第一行\n[00:05.00]第二行';
      final lines = parseLrc(lrc);

      expect(lines.length, 3);
      expect(lines[0].start, 1000);
      expect(lines[1].start, 5000);
      expect(lines[2].start, 10000);
    });

    test('最后一行 end 为 start + 5000', () {
      const lrc = '[00:01.00]单行';
      final lines = parseLrc(lrc);

      expect(lines.length, 1);
      expect(lines[0].end, 6000);
    });

    test('三位毫秒时间戳', () {
      const lrc = '[01:23.456]测试';
      final lines = parseLrc(lrc);

      expect(lines.length, 1);
      expect(lines[0].start, 83456);
    });

    test('解析网易云 YRC 逐字歌词', () {
      const yrc = '[1000,2000](1000,500,0)你(1500,500,0)好';
      final lines = parseLrc(yrc);

      expect(lines, hasLength(1));
      expect(lines.single.start, 1000);
      expect(lines.single.end, 3000);
      expect(lines.single.text, '你好');
      expect(lines.single.isWordByWord, isTrue);
      expect(lines.single.words.first.text, '你');
      expect(lines.single.words.first.start, 1000);
      expect(lines.single.words.first.end, 1500);
    });

    test('解析 WRC 逐字歌词', () {
      const wrc = '[00:01.000]你[00:01.500]好[00:02.000]';
      final lines = parseLrc(wrc);

      expect(lines, hasLength(1));
      expect(lines.single.start, 1000);
      expect(lines.single.end, 2000);
      expect(lines.single.text, '你好');
      expect(lines.single.words.map((word) => word.text), ['你', '好']);
    });
  });
}
