# VutronMusic Flutter 重构路线图

本项目将 `stark81/VutronMusic` 从 Electron + Vue3 重构为 Flutter 应用，并用 Material Design 3 / Material 3 Expressive（MD3/MD3E）重建视觉与交互体系。

重构策略不是逐文件翻译原项目，而是按 Flutter 的分层方式重建：`core` 管应用壳与主题，`data` 管模型、音频、本地和远程数据，`features` 管业务页面和状态，`widgets` 管可复用组件。

`third_party/VutronMusic/` 是原项目源码的本地参考副本，用于核对功能等价性、页面结构、Pinia store 行为和 Electron 能力边界；它不参与 Flutter 应用编译。

## 当前状态

已完成：

- Phase 0：项目初始化、文档骨架、默认 Demo 清理。
- Phase 1：MD3/MD3E 主题壳、全量路由、侧栏/底栏导航、常驻播放栏、全屏播放页骨架。
- Phase 2 MVP：本地目录扫描、音频元数据读取、内嵌封面缓存、内嵌/外挂歌词读取、本地媒体库快照、喜欢歌曲、最近播放、`just_audio + audio_service` 播放控制。
- Phase 3 已完成大部分：首页真实数据面板（For You、继续播放、最近播放、喜欢歌曲、最近添加、在线/流媒体入口）、本地音乐页 5 Tab 完整化（歌曲/专辑/艺术家/目录/喜欢 + 搜索 + 歌曲操作菜单）、设置页真实化（主题模式、本地目录管理、播放/歌词偏好、待接入能力入口）、播放页（封面+歌词+控制）、播放栏（进度+封面+控制）、队列页。

Phase 3 剩余工作：LRC 滚动歌词接入、本地歌单 CRUD、shared_preferences → sqflite 数据库迁移。

当前质量门禁：

```bash
fvm flutter analyze
fvm flutter test
```

两项均应通过。

## 阶段规划

| 阶段 | 目标 | 状态 |
|---|---|---|
| Phase 0 | 项目初始化与规划固化 | ✅ |
| Phase 1 | MD3/MD3E 设计系统与播放器壳 | ✅ |
| Phase 2 | 本地音乐 MVP | ✅ MVP |
| Phase 3 | MD3/MD3E 完整 UI | ✅ |
| Phase 4 | 网易云在线能力迁移（登录、搜索、歌单、专辑、艺术家、评论、MV、每日推荐等） | 🟡 |
| Phase 5 | Navidrome / Jellyfin / Emby 流媒体 | ⬜ |
| Phase 6 | 高级音频与歌词 | ⬜ |
| Phase 7 | 桌面平台增强 | ⬜ |
| Phase 8 | 质量保障与发布 | ⬜ |

详细功能状态见 [feature-parity.md](feature-parity.md)。

## 并行技术债

以下事项已在 Phase 3 内完成：

- ✅ 将 `shared_preferences` 媒体库快照迁移到 sqflite 数据库。
- ✅ 添加数据库迁移脚本目录与首版 schema。
- ✅ 实现本地歌单创建、编辑、删除、歌曲增删。
- ✅ 将 LRC 解析接入滚动歌词视图，并按原 VutronMusic Classic 主窗口样式对齐。
- 🟡 逐字歌词/LDDC 展示（模型已就绪，解析待接入）。
- 🟡 为本地扫描、播放状态机、喜欢歌曲和最近播放补单元测试（部分已补）。

## Phase 3 方向

Phase 3 UI 已完成主要页面。剩余工作：

- 逐字歌词/LDDC：解析逐字时间片段并实现逐字高亮动画。
- 响应式已支持：桌面宽屏优先（NavigationRail），移动端底部导航和紧凑播放器。

## Phase 4 方向

网易云能力使用
[NeteaseCloudMusicApiEnhanced/api-enhanced](https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced)
作为独立 HTTP API 服务，Flutter 端通过 `dio` 访问。客户端不内置 Node.js 运行时。

当前已完成：

- `NeteaseApiClient` 通用请求与错误包装；
- 设置页可配置 API Base URL；
- `/search` 歌曲搜索与统一 `Track` 映射。

后续按登录态、播放 URL、内容详情、推荐与互动能力的顺序推进。

## 技术决策

| 领域 | 当前选择 | 备注 |
|---|---|---|
| 状态管理 | flutter_riverpod | Provider + StateNotifier，后续可按复杂度拆分 Notifier |
| 路由 | go_router | StatefulShellRoute 保持分支状态 |
| 音频 | just_audio + audio_service + just_audio_media_kit | 共享 `MusicAudioHandler` 托管播放器与媒体会话，Linux/Windows 使用 media_kit 后端 |
| 本地扫描 | file_picker + permission_handler | 桌面端选择目录，移动端申请音频/存储权限 |
| 元数据 | audio_metadata_reader | 读取标签、时长、封面、歌词 |
| 当前持久化 | shared_preferences | Phase 2 临时媒体库快照 |
| 目标数据库 | sqflite/drift | Phase 2 后续迁移 |
| 网络 | dio + api-enhanced HTTP 服务 | Phase 4 网易云 Repository |
| 桌面增强 | window_manager，tray_manager 待定 | tray_manager 留到 Phase 7 评估 Linux 构建问题 |

## 迁移映射

| 原项目位置 | Flutter 目标位置 | 说明 |
|---|---|---|
| `src/renderer/router/` | `lib/core/routing/` | 路由映射 |
| `src/renderer/store/` | `lib/features/*/application/` 或 `presentation/*_controller.dart` | 状态与业务逻辑 |
| `src/renderer/components/` | `lib/widgets/` 或 feature 内 widgets | UI 组件 |
| `src/renderer/views/` | `lib/features/*/presentation/pages/` | 页面 |
| `src/main/workers/scanMusic.ts` | `lib/data/local/` | 本地扫描与元数据读取 |
| `src/main/appServer/`、`src/renderer/api/` | `lib/data/remote/netease/` | 网易云接口 |
| `src/main/streaming/` | `lib/features/stream/providers/` | 流媒体 Provider |
| `src/public/migrations/` | `lib/data/local/database/migrations/` | 数据库迁移 |
