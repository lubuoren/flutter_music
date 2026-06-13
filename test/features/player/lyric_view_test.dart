import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/data/models/lyric_line.dart';
import 'package:flutter_music/features/player/widgets/lyric_view.dart';

void main() {
  testWidgets('LyricView highlights current line and handles line tap', (
    tester,
  ) async {
    const lines = [
      LyricLine(start: 0, end: 1000, text: 'first line'),
      LyricLine(start: 1000, end: 2000, text: 'current line'),
    ];
    LyricLine? tappedLine;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: LyricView(
              lines: lines,
              currentIndex: 1,
              onLineTap: (line) => tappedLine = line,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final currentStyle = tester
        .widgetList<AnimatedDefaultTextStyle>(
          find.ancestor(
            of: find.text('current line'),
            matching: find.byType(AnimatedDefaultTextStyle),
          ),
        )
        .firstWhere((style) => style.style.fontWeight == FontWeight.w600)
        .style;

    expect(currentStyle.fontWeight, FontWeight.w600);
    expect(currentStyle.color?.a, 1);

    await tester.tap(find.text('current line'));
    expect(tappedLine, lines[1]);
  });

  testWidgets('LyricView highlights played words for word-by-word lyric', (
    tester,
  ) async {
    const lines = [
      LyricLine(
        start: 1000,
        end: 2000,
        text: '你好',
        words: [
          LyricWord(text: '你', start: 1000, end: 1500),
          LyricWord(text: '好', start: 1500, end: 2000),
        ],
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: LyricView(
              lines: lines,
              currentIndex: 0,
              position: Duration(milliseconds: 1200),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byType(LyricView),
        matching: find.byType(RichText),
      ),
    );
    final span = richText.text as TextSpan;
    final firstWord = span.children![0] as TextSpan;
    final secondWord = span.children![1] as TextSpan;

    expect(firstWord.style?.color?.a, 1);
    expect(secondWord.style?.color?.a, lessThan(1));
  });
}
