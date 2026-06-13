import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'app.dart';
import 'data/audio/music_audio_handler.dart';
import 'data/local/database/app_database.dart';
import 'features/player/application/player_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.title = 'VutronMusic';
  JustAudioMediaKit.ensureInitialized();

  // 初始化数据库（首次启动自动建表）
  await AppDatabase.instance.database;

  final audioHandler = await _initAudioHandler();

  runApp(
    ProviderScope(
      overrides: [musicAudioHandlerProvider.overrideWithValue(audioHandler)],
      child: const VutronMusicApp(),
    ),
  );
}

Future<MusicAudioHandler> _initAudioHandler() async {
  try {
    return await AudioService.init(
      builder: MusicAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.vutronmusic.flutter.playback',
        androidNotificationChannelName: 'VutronMusic 播放控制',
        androidNotificationOngoing: true,
      ),
    );
  } on Object {
    return MusicAudioHandler();
  }
}
