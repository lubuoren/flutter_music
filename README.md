# flutter_music

VutronMusic 的 Flutter + MD3/MD3E 重构项目。

本项目目标是对 `https://github.com/stark81/VutronMusic` 进行 Flutter 重构，并用 Material Design 3 / Material 3 Expressive（MD3/MD3E）替换原有 Electron + Vue 的设计语言。

`third_party/VutronMusic/` 是原 VutronMusic Electron + Vue3 项目源码的本地参考副本，用于对照功能、交互和迁移路径；Flutter 应用运行时代码位于 `lib/`，不会直接依赖该目录。

> Phase 0 / Phase 1 已完成。Phase 2 本地音乐 MVP 已完成。
> Phase 3 MD3/MD3E 完整 UI 已完成：首页、本地音乐页、播放页、设置页、
> LRC 滚动歌词、本地歌单 CRUD、shared_preferences → sqflite 数据库迁移均已实现。
> Phase 4 正在推进，网易云在线音乐能力基于
> [NeteaseCloudMusicApiEnhanced/api-enhanced](https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced)
> 自建 HTTP API 服务接入；浏览器 Web 客户端已可构建，当前主打云端搜索/播放/歌词/封面。

## 文档

- [docs/project-plan.md](docs/project-plan.md) — 总体规划
- [docs/architecture.md](docs/architecture.md) — 架构与目录、Electron→Flutter 能力映射
- [docs/feature-parity.md](docs/feature-parity.md) — 功能等价性检查清单
- [docs/netease-api-reference.md](docs/netease-api-reference.md) — 网易云 API 参考
- [docs/data-model.md](docs/data-model.md) — 数据模型与数据库

## 当前目标

1. 用 Flutter 重新实现 VutronMusic 的核心播放器能力；
2. 使用 MD3/MD3E 作为新的设计语言；
3. 先完成本地音乐 MVP；
4. 再迁移在线音乐、流媒体、桌面增强能力。

## MD3/MD3E 调研结论

已验证以下 Flutter 包可安装并通过 `flutter analyze`：

```yaml
dependencies:
  m3e_design: ^0.2.1
  m3e_collection: ^0.3.7
  material_new_shapes: ^1.0.0
  expressive_refresh: ^0.1.2
```

推荐采用：

```text
Flutter 原生 Material 3 组件
+ m3e_design 设计 token
+ 自建播放器关键组件
```

主题示例：

```dart
import 'package:m3e_design/m3e_design.dart';

theme: ColorScheme.fromSeed(seedColor: Colors.teal).toM3EThemeData(),
darkTheme: ColorScheme.fromSeed(
  seedColor: Colors.teal,
  brightness: Brightness.dark,
).toM3EThemeData(),
```

## 阶段规划

| 阶段 | 目标 |
|---|---|
| Phase 0 | 项目初始化与规划固化 |
| Phase 1 | MD3/MD3E 设计系统与播放器壳 |
| Phase 2 | 本地音乐 MVP | ✅ |
| Phase 3 | MD3/MD3E 完整 UI | ✅ |
| Phase 4 | 在线音乐迁移 | 🟡 |
| Phase 5 | 流媒体服务支持 | ⬜ |
| Phase 6 | 高级音频与歌词 | ⬜ |
| Phase 7 | 桌面平台增强 | ⬜ |
| Phase 8 | 质量保障与发布 | ⬜ |

## Phase 2 已接入

- 申请文件权限、扫描本地目录、读取 ID3 标签与内嵌封面/歌词；
- 接入 just_audio + audio_service，实现播放、队列、上一首/下一首、随机/循环、进度 seek；
- 数据库持久化：local_music_repository 已从 shared_preferences 迁移到 sqflite。

## Phase 3 已完成

- ✅ 首页真实数据面板：本地库概览、继续播放、最近播放、喜欢歌曲、最近添加、在线/流媒体入口卡片；
- ✅ 本地音乐页完整化：歌曲、专辑、艺术家、目录、喜欢 Tab，搜索与歌曲操作菜单；
- ✅ 设置页真实化：主题模式（跟随/浅色/深色/纯黑）、本地目录管理、播放/歌词偏好；
- ✅ 全屏播放页：封面展示、LRC 滚动歌词同步高亮、进度控制、喜欢/循环/队列入口；
- ✅ 常驻播放栏：进度条、封面、曲目信息、播放控制、随机/循环；
- ✅ 播放队列页：队列列表、随机、移除歌曲；
- ✅ 本地歌单 CRUD：创建、重命名、删除歌单，歌曲添加/移除；
- ✅ 数据库迁移：shared_preferences → sqflite，含 tracks/playlists/liked_tracks/play_history 表；
- 🟡 逐字歌词（LDDC）：模型就绪，解析待接入。

## Phase 4 进行中

- ✅ 网易云 API 接入层打底：新增 `lib/data/remote/netease/`，使用 `dio` 调用 `api-enhanced` HTTP 服务；
- ✅ 设置页新增 Netease API Base URL，默认 `https://12900hx-es.tail8bbb9b.ts.net:3000/`；
- ✅ 搜索页接入网易云歌曲搜索并映射为统一 `Track` 模型，搜索结果会批量请求 `/song/detail` 补齐封面；
- ✅ 搜索结果可通过 `/song/url` 解析播放地址并加入播放器播放；
- ✅ 二维码登录、Cookie 导入、登录态校验与退出登录基础闭环；
- ✅ 在线歌曲播放前补齐 `/song/detail` 云端封面与 `/lyric/new` 云端歌词；
- ✅ 云端歌曲歌词 offset 可在播放器内调整并持久化；
- ✅ Web 客户端基础支持：Web SQLite 资产、平台封面/播放适配、浏览器端云端播放入口；
- ✅ 每日推荐：`/recommend/songs` 歌曲列表（首页入口 → `/daily/songs`），复用歌单播放链路；
- 🟡 待接入：手机号/邮箱登录、专辑/艺术家、评论写操作、MV、推荐歌单。

网易云服务准备：

```text
api-enhanced 仓库：https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced
Flutter 默认连接：https://12900hx-es.tail8bbb9b.ts.net:3000/
```

Flutter 客户端不内置 Node.js 服务，开发和自用时请独立运行或部署 `api-enhanced`，再在设置页填写服务地址。

## 并行技术债

- 🟡 逐字歌词/LDDC 展示
- 🟡 更多单元测试（扫描、播放控制、歌单 CRUD 覆盖率提升）
