# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 常用命令

本项目使用 FVM 管理 Flutter SDK 版本，所有 `flutter` 命令需通过 `fvm` 调用：

```bash
# 静态分析
fvm flutter analyze

# 运行测试
fvm flutter test

# 运行单个测试文件
fvm flutter test test/widget_test.dart

# 桌面端运行（Linux）
fvm flutter run -d linux
```

项目使用 `flutter_lints` 标准规则集。

## 技术栈

| 领域 | 选型 |
|---|---|
| 状态管理 | flutter_riverpod (StateNotifier + Provider) |
| 路由 | go_router (StatefulShellRoute 保持分支状态) |
| 音频播放 | just_audio + just_audio_media_kit (Linux/Windows 后端) |
| 媒体会话 | audio_service |
| 主题 | Flutter Material 3 + m3e_design + material_new_shapes |
| 本地扫描 | file_picker + permission_handler + audio_metadata_reader |
| 持久化 | shared_preferences (临时, 后续迁移到 sqflite/drift) |
| 网络 | dio |
| 桌面 | window_manager |

## 架构概览

项目目标：将 VutronMusic（Electron + Vue3）重构为 Flutter + MD3/MD3E。`third_party/VutronMusic/` 是原项目源码的只读参考副本，不参与编译。当前 Phase 3 已完成（MD3/MD3E 完整 UI），Phase 4 进行中（网易云在线能力迁移）。

### 目录分层

```text
lib/
  main.dart                    初始化 AudioService + ProviderScope
  app.dart                     MaterialApp.router + 主题装配
  core/                        路由、主题、应用壳（平台入口层）
  data/                        领域模型、本地扫描、持久化、音频 handler
    audio/music_audio_handler.dart   唯一持有 AudioPlayer 的对象
    local/                           本地音乐仓库与状态
    models/                          Track / Playlist / LyricLine
  features/                    各功能模块（页面 + 业务状态 + 业务动作）
    player/application/              播放器 controller + state
    settings/application/            设置 controller + state
  widgets/md3/                 跨功能复用的 MD3 组件
```

### 核心设计原则

- **页面不直接操作播放器或文件系统**，通过 Riverpod provider 调用 controller/repository。
- **`MusicAudioHandler`** 是唯一持有 `AudioPlayer` 的对象，UI 只通过 `MusicPlayerController` 操作播放。
- 新功能放到 `features/<name>/` 下，跨功能共享的数据模型放 `data/models/`。

### 音频数据流

```
main.dart 初始化 MusicAudioHandler → 注入 Riverpod
  → MusicPlayerController 监听 AudioPlayer 流
    → 向外暴露 MusicPlayerState
      → UI 调用 controller 方法（play/pause/seek/skip/shuffle/loop）
```

### 路由结构

`StatefulShellRoute.indexedStack` 管理 5 个顶层 tab：首页 `/`、探索 `/explore`、音乐库 `/library`、本地音乐 `/localMusic`、设置 `/settings`。其他页面（播放页、歌单、专辑、艺术家、搜索等）作为顶级路由叠加。

### 响应式布局

- `AppShell`：宽度 ≥ 900px 时使用 `NavigationRail`（侧栏），否则使用底部 `NavigationBar`。
- `PlayerBar` 始终固定在内容区底部。

### 主题系统

`AppTheme` 提供三种主题：`lightTheme`、`darkTheme`、`blackTheme`。使用 `ColorScheme.fromSeed(seedColor: 0xFF335EEA).toM3EThemeData()` 生成 MD3E token。`AppSettingsController` 管理 themeMode、歌词/播放偏好，通过 `shared_preferences` 持久化。

## 当前阶段与关键约束

- **Phase 3 已完成**：MD3/MD3E 完整 UI（首页、本地音乐页、设置页、播放页、播放栏、队列页、LRC 滚动歌词、本地歌单 CRUD、shared_preferences → sqflite 数据库迁移）。
- **下一阶段**：Phase 4 — 网易云在线音乐能力迁移（登录、搜索、歌单、专辑、艺术家、评论、MV、每日推荐等）。
- **待补项**：逐字歌词（LDDC）展示、更多单元测试覆盖。
- **暂缓接入**：`tray_manager`（其 Linux 原生实现使用已弃用的 `app_indicator_new`，在 `-Werror` 下会导致构建失败），留待 Phase 7。
- 路由映射和迁移路径以 `docs/architecture.md` 和 `docs/project-plan.md` 为准。

## 参考文档

- `README.md` — 项目概述与阶段状态
- `docs/project-plan.md` — 详细路线图与迁移映射
- `docs/architecture.md` — 分层、音频架构、Electron 能力映射
- `docs/feature-parity.md` — 功能等价性检查清单
- `docs/data-model.md` — 数据模型与数据库迁移计划
- `docs/netease-api-reference.md` — 网易云 API 参考
- `third_party/VutronMusic/` — 原项目源码参考
