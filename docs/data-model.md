# 数据模型与持久化

原 VutronMusic 使用 better-sqlite3 + electron-store。数据库大量采用 `id + json` 的宽松结构，便于缓存不同来源的歌曲、专辑、歌单和账号数据。

Flutter 端当前已完成 `shared_preferences` → sqflite 迁移：本地媒体库、歌单、喜欢歌曲和播放历史使用 sqflite 保存，Web 客户端通过 `sqflite_common_ffi_web` 使用 IndexedDB 持久化 SQLite 数据，旧 `shared_preferences` 快照仅作为一次性迁移来源。数据库仍保留与原项目相近的 `id + json` 思路。

原项目源码参考位于 `third_party/VutronMusic/`，其中 `src/public/migrations/`、`src/main/db.ts` 和 `src/renderer/store/` 是数据迁移的主要对照来源。

## 当前实现

### Track

文件：`lib/data/models/track.dart`

| 字段 | 说明 |
|---|---|
| `id` | 歌曲唯一 id；本地歌曲使用文件路径 sha1 |
| `title` | 标题 |
| `artists` | 艺术家列表 |
| `album` | 专辑 |
| `durationMs` | 时长，毫秒 |
| `type` | `local` / `online` / `stream` |
| `source` | 具体来源，如 `localTrack`、`netease`、`navidrome` |
| `filePath` | 本地文件路径 |
| `coverUrl` | 封面路径或 URL；网易云在线播放前通过 `/song/detail` 补齐云端封面 |
| `url` | 播放 URL；本地歌曲为 file URI |
| `lyrics` | 内嵌歌词、同名 `.lrc` 内容，或网易云 `/lyric/new` 云端歌词 |
| `matched` | 是否已匹配在线信息 |
| `cache` | 是否命中缓存 |
| `offset` | 歌词偏移；本地歌曲同步进 `tracks`，云端歌曲通过 `shared_preferences.lyric_offsets.v1.*` 轻量持久化 |
| `md5` | 当前用于保存歌词内容 sha1；后续可调整为音频文件 hash |
| `playCount` | 播放次数 |
| `isLiked` | 是否喜欢 |
| `lastPlayedAt` | 最近播放时间 |
| `addedAt` | 加入媒体库时间 |

### Playlist

文件：`lib/data/models/playlist.dart`

当前为统一歌单模型，覆盖本地、网易云、流媒体三类来源。本地歌单 CRUD 已接入 sqflite，旧 `shared_preferences` 歌单会在加载时幂等合并回数据库。网易云歌单会额外携带 `creatorUserId`、`creatorName` 和 `subscribed`，用于音乐库页区分创建/收藏歌单与详情页展示作者信息。

### LyricLine

文件：`lib/data/models/lyric_line.dart`

已保留普通歌词与逐字歌词模型。当前播放页已接入 LRC 滚动歌词；逐字歌词/LDDC 解析和逐字高亮仍待接入。

## 当前持久化

文件：

- `lib/data/local/database/app_database.dart`
- `lib/data/local/local_music_repository.dart`
- `lib/features/playlist/application/local_playlist_repository.dart`

| 表/Key | 内容 |
|---|---|
| `tracks` | `Track.toJson()` 宽表快照 |
| `playlists` / `playlist_tracks` | 本地歌单与歌曲顺序 |
| `liked_tracks` | 喜欢歌曲索引 |
| `play_history` | 最近播放记录 |
| `app_data.local_music.directories.v1` | 已扫描目录列表 |
| `app_data.local_music.last_scanned_at.v1` | 最近扫描时间 |
| `shared_preferences.netease.auth.cookie.v1` | 网易云登录 Cookie |
| `shared_preferences.netease.auth.profile.v1` | 网易云账号资料快照 |
| `shared_preferences.lyric_offsets.v1.<source>.<trackId>` | 歌词偏移，覆盖云端歌曲和队列内即时调整 |

旧 `shared_preferences` keys（`local_music.tracks.v1`、`local_music.directories.v1`、`local_music.last_scanned_at.v1`、`local_playlists.v1`）仍会被读取用于一次性或幂等迁移，运行时主数据以 sqflite 为准。

## 原始表结构参考

原项目 `src/public/migrations/init.sql` 中的核心表：

| 表 | 关键字段 | 用途 |
|---|---|---|
| `AccountData` | `id`, `json`, `updatedAt` | 账号数据 |
| `AppData` | `id`, `value` | 应用键值 |
| `Track` | `id`, `filePath`, `isLocal`, `deleted`, `json`, `updatedAt` | 歌曲快照 |
| `Album` | `id`, `matched`, `json` | 专辑缓存 |
| `LocalAlbumCover` | `id`, `json` | 本地专辑封面 |
| `Unblock` | `id`, `json` | Unblock 音源缓存 |
| `Artist` | `id`, `matched`, `json` | 艺术家缓存 |
| `ArtistAlbum` | `id`, `hotAlbums` | 艺术家专辑 |
| `Playlist` | `id`, `isLocal`, `json` | 歌单 |
| `Audio` | `id`, `bitRate`, `format`, `source`, `queriedAt` | 音频地址缓存 |
| `Lyrics` | `id`, `json` | 歌词缓存 |
| `AppleMusicAlbum` / `AppleMusicArtist` | `id`, `json` | Apple Music 元数据 |

重要迁移历史：

- 1.5.0：`Track` 重构为 `id + type + json`，增加 type 索引。
- 2.4.0：未匹配歌曲/专辑封面改为 `/local-asset/pic?id=`。
- 2.5.0：本地资源 URL 改为 `atom://local-asset?type=pic`。

## 当前数据库

目标位置：

```text
lib/data/local/database/
  app_database.dart
  migrations/
```

当前已建表（schema 内联在 `app_database.dart` 的 `_onCreate`，数据库 version 1）：

```text
tracks(id, type, source, file_path, json, updated_at)
playlists(id, name, is_local, source, json, created_at, updated_at)
playlist_tracks(playlist_id, track_id, position, added_at)
liked_tracks(track_id, source, created_at)
play_history(id, track_id, played_at, duration_ms, source)
app_data(id, value)
```

规划中（尚未建表）：`albums`、`artists`、`lyrics`、`audio_cache`、`account_data`。

> `migrations/001_initial_schema.sql` 是与 `_onCreate` 等价的 schema 快照，当前**未在运行时加载**；
> 尚未接入 `onUpgrade` 版本化迁移（version 恒为 1）。后续若需改表，需补 `onUpgrade`
> 或改为运行时按版本读取 `migrations/*.sql`（参考原项目 `src/main/db.ts`）。

## 本地资源映射

原项目通过 Electron 自定义协议 `atom://local-asset` 提供本地封面和音频流。

Flutter 端映射为：

- 本地歌曲：`just_audio` 播放 file URI。
- 内嵌封面：扫描时写入应用支持目录的 `covers/` 子目录。
- 目录封面：直接保存本地图片路径。
- 在线歌曲：HTTP(S) 直链或后续代理直链。
- 歌词：当前保存在 `Track.lyrics`，本地歌词来自内嵌/外挂 LRC，网易云在线歌词来自 `/lyric/new`；后续可迁移到 `lyrics` 表做缓存。

## 数据迁移状态

1. ✅ 引入 sqflite 和数据库初始化。
2. ✅ 建立首版 schema（version 1，`_onCreate` 内联建表）。
3. ✅ 启动时读取 `shared_preferences` 中的 Phase 2 快照并导入数据库。
4. ✅ 本地扫描写入数据库，不再写回旧媒体库 JSON 列表。
5. ✅ 播放历史、喜欢歌曲、本地歌单改为数据库写入。
6. 🟡 旧 key 保留只读兼容，后续可在确认迁移稳定后清理。
