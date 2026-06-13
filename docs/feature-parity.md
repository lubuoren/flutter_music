# 功能等价性检查清单（VutronMusic → Flutter 重构）

本文件用于保证 Flutter 重构版与原 VutronMusic（Electron + Vue3，v3.2.0）功能一一对应。
每一项标注：原项目实现位置 → Flutter 目标位置 → 状态。

状态图例：✅ 已实现 ｜ 🟡 骨架已建（UI/契约就绪，逻辑待接入）｜ ⬜ 待开始

更新规则：只在功能可从 UI 或 Repository 完整走通时标记 ✅；仅有页面、模型、接口或部分逻辑时标记 🟡。

## 近期焦点

1. Phase 3 UI 已基本完成：首页、本地音乐页、设置页、播放页、播放栏、队列页均已实现完整功能。
2. 剩余 Phase 3 工作：LRC 滚动歌词接入、本地歌单 CRUD、数据库迁移。
3. Phase 4 在线音乐接入前补单元测试覆盖。

## 1. 应用框架与导航

| 功能 | 原项目 | Flutter 目标 | 状态 |
|---|---|---|---|
| 路由表 | renderer/router/index.ts | core/routing/app_router.dart | ✅ |
| 主框架/侧边导航 | components/SideNav.vue, NavBar.vue | core/shell/app_shell.dart | ✅ |
| 响应式桌面/移动布局 | App.vue | core/shell/app_shell.dart | ✅ |
| MD3/MD3E 主题 | playerTheme.ts | core/theme/app_theme.dart | ✅ |
| Light/Dark/Black/动态取色 | settings.ts theme | core/theme + settings | ✅ |

## 2. 播放器核心

| 功能 | 原项目 | Flutter 目标 | 状态 |
|---|---|---|---|
| 播放/暂停/上一首/下一首 | store/player.ts | features/player + just_audio | ✅ |
| 播放队列 | store/player.ts, views/NextUp.vue | features/player/.../next_up_page.dart | ✅ |
| 下一首插播 | store/player.ts | features/player | ✅ |
| 随机/循环模式 | store/player.ts | features/player | ✅ |
| 进度/seek/媒体会话 | store/player.ts | audio_service | ✅ |
| 底部播放栏 | components/PlayerBar.vue | features/player/widgets/player_bar.dart | ✅ |
| 全屏播放页 | views/PlayPage.vue | features/player/.../player_page.dart | ✅ |
| 音量/淡入淡出 | store/player.ts | features/player + settings | ⬜ |
| 音质选择 | settings.ts general.musicQuality | features/settings | ⬜ |
| 自动缓存 | settings.ts autoCacheTrack | data/audio | ⬜ |
| 听歌打卡/scrobble | api/track.ts, player.ts | data/remote/netease | ⬜ |

## 3. 高级音频

| 功能 | 原项目 | Flutter 目标 | 状态 |
|---|---|---|---|
| 均衡器（10 段 biquad） | store/player.ts biquadParams | features/player/audio | ⬜ |
| 卷积混响 | utils/convolver.ts, ModalConvolver.vue | features/player/audio | ⬜ |
| 变调（pitch） | store/player.ts, ModalPitch.vue | features/player/audio | ⬜ |
| 变速（playbackRate） | store/player.ts, ModalPlayback.vue | features/player/audio | ⬜ |
| soundtouch worklet | utils/soundtouch-worklet.js | 平台音频实现 | ⬜ |

## 4. 歌词

| 功能 | 原项目 | Flutter 目标 | 状态 |
|---|---|---|---|
| 普通 LRC 解析与滚动 | components/LyricPage.vue | features/lyric | 🟡 |
| 逐字歌词（LDDC） | LyricLine.vue, types/music | data/models/lyric_line.dart | 🟡 |
| 翻译歌词 | store/player.ts | data/models/lyric_line.dart | 🟡 |
| 歌词偏移 | player.ts lyricOffset | features/player | ⬜ |
| 桌面歌词/OSD | views/OSDLyric.vue, store/osdLyric.ts | features/lyric + window_manager | ⬜ |

## 5. 本地音乐

| 功能 | 原项目 | Flutter 目标 | 状态 |
|---|---|---|---|
| 扫描目录 | main/workers/scanMusic.ts | data/local + file_picker | ✅ |
| ID3 标签读取 | music-metadata, taglib-wasm | data/local | ✅ |
| 内嵌封面 | main/workers/writeCover.ts | data/local | ✅ |
| 内嵌/外挂 LRC | store/localMusic.ts | data/local | ✅ |
| LRC 解析与滚动展示 | components/LyricPage.vue | features/lyric + player_page.dart | ⬜ |
| 在线信息匹配 | api/other searchMatch | data/remote/netease | ⬜ |
| 本地歌单 | store/localMusic.ts | features/playlist | ✅ |

## 6. 网易云在线

| 功能 | 原项目 | Flutter 目标 | 状态 |
|---|---|---|---|
| 登录（二维码/手机/邮箱） | api/auth.ts, views/LoginAccount.vue | features/login | ⬜ |
| 搜索 | api/other.ts, views/SearchPage.vue | features/search | ⬜ |
| 歌单 | api/playlist.ts, views/PlaylistPage.vue | features/playlist | ⬜ |
| 专辑 | api/album.ts, views/AlbumPage.vue | features/album | ⬜ |
| 艺术家 | api/artist.ts, views/ArtistPage.vue | features/artist | ⬜ |
| 评论 | api/comment.ts, components/CommentPage.vue | features/comments | ⬜ |
| MV | api/mv.ts, views/MvPage.vue | features/mv | ⬜ |
| 每日推荐 | api/playlist.ts, views/DailyTracks.vue | features/playlist | ⬜ |
| 私人 FM | api/other personalFM, components/FMCard.vue | features/player | ⬜ |
| 云盘 | api/user cloudDisk | features/library | ⬜ |
| 喜欢列表 | api/user, store/data.ts | features/library | ⬜ |
| Unblock 音源 | settings unblockNeteaseMusic | data/remote | ⬜ |

## 7. 流媒体

| 功能 | 原项目 | Flutter 目标 | 状态 |
|---|---|---|---|
| 统一抽象 | main/streaming/* | features/stream/domain/streaming_music_provider.dart | ⬜ |
| Navidrome | main/streaming/navidrome.ts | features/stream/providers | ⬜ |
| Jellyfin | main/streaming/jellyfin.ts | features/stream/providers | ⬜ |
| Emby | main/streaming/emby.ts | features/stream/providers | ⬜ |
| 账号保存 | store/streamingMusic.ts | features/stream | ⬜ |
| 流媒体歌词/封面 | store/streamingMusic.ts | features/stream | ⬜ |

## 8. 桌面增强

| 功能 | 原项目 | Flutter 目标 | 状态 |
|---|---|---|---|
| 系统托盘 | main/tray.ts | tray_manager | ⬜ |
| Linux MPRIS | main/mpris.ts, dbus*.ts | 平台通道 | ⬜ |
| macOS TouchBar | main/touchBar.ts | 平台通道 | ⬜ |
| Windows 任务栏按钮 | main/thumBar.ts | 平台通道 | ⬜ |
| 全局快捷键 | main/globalShortcut.ts | 平台通道 | ⬜ |
| 自动更新 | main/checkUpdate.ts | 平台/CI | ⬜ |
| Discord RPC | settings misc | 可选 | ⬜ |
| Last.fm | main/utils/lastfm.ts | 可选 | ⬜ |

## 9. 数据持久化

| 功能 | 原项目 | Flutter 目标 | 状态 |
|---|---|---|---|
| 本地数据库 | main/db.ts, public/migrations/* | data/local/database | ✅ |
| 设置持久化 | pinia-plugin-persistedstate | shared_preferences | ✅ |
| 数据库迁移 | public/migrations/*.sql | data/local/database/migrations | ✅ |

数据库表结构与迁移脚本说明见 docs/data-model.md。
