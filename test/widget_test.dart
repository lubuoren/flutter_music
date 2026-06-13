import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_music/app.dart';
import 'package:flutter_music/data/audio/music_audio_handler.dart';
import 'package:flutter_music/features/player/application/player_controller.dart';
import 'package:flutter_music/features/player/widgets/player_bar.dart';

void main() {
  testWidgets('App 启动并渲染首页标题', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final audioHandler = MusicAudioHandler();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [musicAudioHandlerProvider.overrideWithValue(audioHandler)],
        child: const VutronMusicApp(),
      ),
    );
    await tester.pump();

    expect(find.text('VutronMusic'), findsWidgets);
    expect(find.byType(PlayerBar), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    audioHandler.destroy();
  });
}
