# 架构说明

本项目采用 Flutter 分层架构：应用入口与壳层保持轻薄，数据、音频和业务状态放在可测试的 provider/controller 中，页面只负责消费状态和触发意图。

`third_party/VutronMusic/` 存放原 Electron + Vue3 项目源码，仅作为架构、交互和功能迁移参考；当前 Flutter 运行时代码集中在 `lib/`。

## 技术栈

| 领域 | 选型 |
|---|---|
| 状态管理 | flutter_riverpod |
| 路由 | go_router |
| 音频播放 | just_audio |
| 桌面音频后端 | just_audio_media_kit + media_kit_libs_linux / media_kit_libs_windows_audio |
| 媒体会话 | audio_service |
| 进度条 | audio_video_progress_bar |
| 本地目录 | file_picker |
| 权限 | permission_handler |
| 元数据 | audio_metadata_reader |
| 当前持久化 | sqflite + sqflite_common_ffi_web + shared_preferences 设置/旧快照迁移 |
| 网络 | dio |
| 主题 | Flutter Material 3 + m3e_design + material_new_shapes |
| 桌面基础 | window_manager |

## 当前目录

```text
lib/
  main.dart                         初始化 AudioService + ProviderScope
  app.dart                          MaterialApp.router + 主题装配

  core/
    platform/                      封面、播放可用性等跨平台适配
    routing/app_router.dart         全量路由
    shell/app_shell.dart            侧栏/底栏 + 常驻播放栏
    theme/app_theme.dart            Light/Dark/Black + MD3E

  data/
    audio/music_audio_handler.dart  just_audio + audio_service 共享播放实例
    local/local_music_repository.dart
                                    本地音乐状态、迁移与持久化
    local/local_music_platform*.dart
                                    原生目录选择、权限、扫描、元数据读取；Web 端明确降级
    local/local_music_state.dart    本地媒体库状态
    remote/netease/                 api-enhanced Client、认证、音乐 Repository
    models/                         Track / Playlist / LyricLine

  features/
    home/                           首页与最近播放入口
    login/                          网易云二维码/Cookie 登录态
    local_music/                    本地音乐扫描和歌曲列表
    player/
      application/                  播放器状态与控制器
      presentation/pages/           全屏播放页、队列页
      widgets/player_bar.dart       常驻播放栏
    stream/domain/                  StreamingMusicProvider 抽象
    */presentation/pages/           其他功能占位页面

  widgets/md3/                      可复用 MD3 组件
```

## 分层职责

| 层级 | 职责 |
|---|---|
| `core` | 路由、主题、应用壳、平台入口 |
| `data` | 领域模型、本地扫描、持久化、远程 API、音频 handler |
| `features` | 页面、业务状态、业务动作 |
| `widgets` | 跨功能复用 UI 组件 |

页面不直接操作播放器实例或本地文件系统；它们通过 Riverpod provider 调用 controller/repository。

## 音频架构

`MusicAudioHandler` 是唯一持有 `AudioPlayer` 的对象：

- `main.dart` 初始化 `AudioService.init`，失败时退回普通 `MusicAudioHandler`，保证开发和测试环境可启动。
- `main.dart` 在创建播放器前调用 `JustAudioMediaKit.ensureInitialized()`，为 Linux/Windows 注册 just_audio 后端。
- `musicAudioHandlerProvider` 将 handler 注入 Riverpod。
- `MusicPlayerController` 监听 handler 内部的 `AudioPlayer` 流，并对外暴露 `MusicPlayerState`。
- UI 只调用 `MusicPlayerController` 的播放、暂停、seek、队列、循环和随机方法。

这样可以让应用内 UI、系统媒体会话和后续桌面媒体键共享同一个播放状态。

## 本地音乐数据流

```text
LocalMusicPage
  -> LocalMusicController
    -> LocalMusicRepository
      -> LocalMusicPlatform
        -> file_picker / permission_handler
        -> audio_metadata_reader
      -> sqflite(AppDatabase)
      -> shared_preferences(旧快照只读迁移)
```

扫描流程：

1. 用户选择目录。
2. 移动端申请音频/存储权限；桌面端使用目录选择器授权。
3. 递归查找 `audio_metadata_reader.supportedFileExtensions` 支持的音频文件。
4. 读取标题、艺术家、专辑、时长、内嵌封面、内嵌歌词。
5. 查找同名 `.lrc` 和目录下常见封面文件。
6. 将媒体库、喜欢状态和播放历史保存到 sqflite，旧 `shared_preferences` 快照只作为迁移来源读取。

当前持久化已完成 Phase 3 数据库迁移；表结构见 [data-model.md](data-model.md)。

Web 客户端使用 `sqflite_common_ffi_web`，运行时需要 `web/sqflite_sw.js` 和
`web/sqlite3.wasm`。浏览器端当前优先支持网易云云端搜索、播放、歌词和封面；
本地目录扫描仍限定在桌面/移动原生端。

## 路由映射

已保留原 VutronMusic 的主要入口：

```text
/
/explore
/library
/library/liked-songs
/localMusic
/localPlaylist/:id
/playlist/:id
/daily/songs
/login/account
/album/:id
/artist/:id
/artist/:id/mv
/search
/user/:id
/mv/:id
/next
/settings
/stream
/streamLogin/:service
/streamPlaylist/:service/:id
/stream-liked-songs/:service
```

Flutter 新增：

```text
/player
/comments/:resourceType/:id
```

## Electron 能力映射

| Electron 能力 | Flutter 方案 |
|---|---|
| main 进程 IPC | Riverpod provider + 平台通道 |
| Fastify 本地服务 + NeteaseCloudMusicApi | Dart HTTP client（dio）+ Repository，连接独立部署的 api-enhanced |
| better-sqlite3 | sqflite/drift |
| electron-store | shared_preferences 用于轻量设置；媒体库与歌单已迁移到 sqflite |
| atom:// 自定义协议 | 文件路径、字节流、HTTP(S) URL |
| Web Audio 音效 | just_audio + 平台音效实现 |
| tray / mpris / touchBar / thumbar | tray_manager / window_manager / 平台通道 |

## 开发约定

- 新功能优先放在对应 `features/<name>/` 下。
- 跨功能共享的数据模型放在 `data/models/`。
- 平台或插件封装放在 `data/` 或 `core/platform/`，页面不直接依赖底层插件。
- 文档状态以 [feature-parity.md](feature-parity.md) 为准；路线安排以 [project-plan.md](project-plan.md) 为准。
