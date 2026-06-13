# 数据模型与持久化

原 VutronMusic 使用 better-sqlite3 + electron-store。数据库大量采用 `id + json` 的宽松结构，便于缓存不同来源的歌曲、专辑、歌单和账号数据。

Flutter 端当前处于 Phase 2 MVP：本地媒体库暂存于 `shared_preferences`。后续将迁移到 sqflite/drift，并保留与原项目相近的 `id + json` 思路。

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
| `coverUrl` | 封面路径或 URL |
| `url` | 播放 URL；本地歌曲为 file URI |
| `lyrics` | 内嵌歌词或同名 `.lrc` 内容 |
| `matched` | 是否已匹配在线信息 |
| `cache` | 是否命中缓存 |
| `offset` | 歌词偏移 |
| `md5` | 当前用于保存歌词内容 sha1；后续可调整为音频文件 hash |
| `playCount` | 播放次数 |
| `isLiked` | 是否喜欢 |
| `lastPlayedAt` | 最近播放时间 |
| `addedAt` | 加入媒体库时间 |

### Playlist

文件：`lib/data/models/playlist.dart`

当前为统一歌单模型，覆盖本地、网易云、流媒体三类来源。Phase 2 尚未实现本地歌单增删改。

### LyricLine

文件：`lib/data/models/lyric_line.dart`

已保留普通歌词与逐字歌词模型。当前播放页展示原始歌词文本，后续需要接 LRC/LDDC 解析与滚动同步。

## 当前持久化

文件：`lib/data/local/local_music_repository.dart`

| Key | 内容 |
|---|---|
| `local_music.tracks.v1` | `Track.toJson()` 列表 |
| `local_music.directories.v1` | 已扫描目录列表 |
| `local_music.last_scanned_at.v1` | 最近扫描时间 |

当前实现适合 MVP 和小规模媒体库。迁移数据库时需要提供一次性导入逻辑，将这些 key 中的数据写入 `tracks`、`play_history`、`liked_tracks` 等表。

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

## 目标数据库

目标位置：

```text
lib/data/local/database/
  app_database.dart
  migrations/
```

建议首版表：

```text
tracks(id, type, source, file_path, json, updated_at)
albums(id, matched, json, updated_at)
artists(id, matched, json, updated_at)
playlists(id, is_local, source, json, updated_at)
playlist_tracks(playlist_id, track_id, position, added_at)
liked_tracks(track_id, source, created_at)
play_history(track_id, played_at, duration_ms, source)
lyrics(track_id, source, json, updated_at)
audio_cache(id, bit_rate, format, source, url, queried_at)
account_data(id, source, json, updated_at)
app_data(id, value)
```

## 本地资源映射

原项目通过 Electron 自定义协议 `atom://local-asset` 提供本地封面和音频流。

Flutter 端映射为：

- 本地歌曲：`just_audio` 播放 file URI。
- 内嵌封面：扫描时写入应用支持目录的 `covers/` 子目录。
- 目录封面：直接保存本地图片路径。
- 在线歌曲：HTTP(S) 直链或后续代理直链。
- 歌词：当前保存在 `Track.lyrics`，后续迁移到 `lyrics` 表。

## 数据迁移顺序

1. 引入 sqflite/drift 和数据库初始化。
2. 建立首版 schema 与迁移脚本目录。
3. 启动时读取 `shared_preferences` 中的 Phase 2 快照并导入数据库。
4. 本地扫描写入数据库，不再覆盖整份 JSON 列表。
5. 播放历史、喜欢歌曲、本地歌单改为增量写入。
6. 移除或保留只读兼容的旧 key。
