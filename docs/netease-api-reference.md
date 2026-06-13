# 网易云 API 参考（迁移自 VutronMusic）

本文件整理 VutronMusic `src/renderer/api/*.ts` 中调用的网易云接口，作为 Flutter 端
`lib/data/remote/netease/` Repository 的契约清单。

当前状态：Phase 4 已开始。Flutter 端已建立 `data/remote/netease` 接入层，并完成歌曲搜索的首个闭环；其余接口仍按本文件逐步迁移。

## API 服务选型

网易云相关能力准备使用
[NeteaseCloudMusicApiEnhanced/api-enhanced](https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced)。
该项目提供 Node.js 网易云音乐 HTTP API 服务，Flutter 客户端通过 `dio` 访问，不在应用内嵌 Node.js 运行时。

接入约定：

- 开发默认 Base URL：`http://127.0.0.1:3000`。
- Base URL 可在应用设置页修改并持久化。
- 桌面端可访问本机服务；Android 模拟器访问宿主机时通常需要改为 `http://10.0.2.2:3000`。
- 真机需填写局域网或已部署的 HTTPS 地址，生产环境不依赖公开演示服务。
- `api-enhanced` 作为独立服务运行或部署，Flutter 仓库不 vendoring 其源码。
- 上游接口可能随网易云策略变化，所有响应解析集中在 Repository 层，页面不直接依赖原始 JSON。

通用约定：

- 原项目经由本地代理 `/netease` 前缀转发；Flutter 新实现直接请求配置的 `api-enhanced` Base URL。
- Flutter 端目标是封装 `NeteaseApiClient`，底层使用 `dio`。
- Cookie、代理参数 `proxy`、真实 IP 参数 `realIP` 来自设置模块。
- 响应 `code == 301` 且 message 为未登录时，应清理登录态并提示重新登录。
- 返回模型优先在 Repository 层转换为统一 `Track` / `Playlist` / `LyricLine`。

目标目录：

```text
lib/data/remote/netease/
  netease_api_client.dart
  netease_auth_repository.dart
  netease_music_repository.dart
  netease_playlist_repository.dart
  netease_comment_repository.dart
```

当前已实现：

- `NeteaseApiClient`：Base URL、超时、Cookie/代理/realIP 通用参数、错误包装。
- `NeteaseMusicRepository.searchTracks`：调用 `/search` 并映射统一 `Track`。

下一步顺序：

1. 二维码登录、Cookie 持久化、登录态校验；
2. `/song/url` 或对应增强接口解析在线歌曲播放 URL；
3. 歌单、专辑、艺术家详情；
4. 每日推荐、私人 FM、评论和 MV。

## auth.ts 登录与账号

| 函数 | 方法 | 路径 | 说明 |
|---|---|---|---|
| userPlaylist | GET | /user/playlist | 用户歌单 |
| loginWithPhone | POST | /login/cellphone | 手机号登录 |
| loginWithEmail | POST | /login | 邮箱登录 |
| loginQrCodeKey | GET | /login/qr/key | 获取二维码 key |
| loginQrCodeCheck | GET | /login/qr/check | 轮询扫码状态 |
| refreshCookie | GET | /login/refresh | 刷新 Cookie |
| userAccount | GET | /user/account | 账号信息 |
| getQrImg | GET | /login/qr/create | 二维码图片 |
| getLoginStatus | GET | /login/status | 登录状态 |
| logout | GET | /logout | 退出登录 |

## track.ts 歌曲

| 函数 | 方法 | 路径 | 说明 |
|---|---|---|---|
| getLyric | GET | /lyric/new | 歌词（含逐字） |
| likeTrack | GET | /like | 喜欢/取消喜欢 |
| getTrackDetail | GET | /song/detail | 歌曲详情（多 id） |
| scrobble | GET | /scrobble | 听歌打卡 |
| topSong | GET | /top/song | 新歌速递 |
| topAlbum | GET | /top/album | 新碟上架 |

## album.ts 专辑

| 函数 | 方法 | 路径 | 说明 |
|---|---|---|---|
| getAlbum | GET | /album | 专辑内容 |
| newAlbums | GET | /album/new | 全部新碟 |
| albumDynamicDetail | GET | /album/detail/dynamic | 专辑动态信息 |
| likeAAlbum | POST | /album/sub | 收藏/取消收藏专辑 |

## artist.ts 艺术家

| 函数 | 方法 | 路径 | 说明 |
|---|---|---|---|
| getArtist | GET | /artists | 艺术家详情+热门歌曲 |
| getArtistAlbum | GET | /artist/album | 艺术家专辑 |
| toplistOfArtists | GET | /toplist/artist | 艺术家榜 |
| artistMv | GET | /artist/mv | 艺术家 MV |
| similarArtists | GET | /simi/artist | 相似艺术家 |
| followAnArtist | POST | /artist/sub | 关注/取消关注 |
| getArtistList | GET | /artist/list | 歌手分类列表 |

## playlist.ts 歌单

| 函数 | 方法 | 路径 | 说明 |
|---|---|---|---|
| recommendPlaylist | GET | /personalized | 推荐歌单 |
| dailyRecommendPlaylist | GET | /recommend/resource | 每日推荐歌单 |
| getPlaylistDetail | GET | /playlist/detail | 歌单详情 |
| dailyRecommendTracks | GET | /recommend/songs | 每日推荐歌曲 |
| highQualityPlaylist | GET | /top/playlist/highquality | 精品歌单 |
| deletePlaylist | POST | /playlist/delete | 删除歌单 |
| createPlaylist | GET | /playlist/create | 新建歌单 |
| topPlaylist | GET | /top/playlist | 网友精选碟 |
| subscribePlaylist | POST | /playlist/subscribe | 收藏/取消收藏 |
| toplists | GET | /toplist | 所有榜单 |
| toplistDetail | GET | /toplist/detail | 榜单摘要 |
| addOrRemoveTrackFromPlaylist | POST | /playlist/tracks | 歌单增删歌曲 |
| intelligencePlaylist | GET | /playmode/intelligence/list | 心动模式 |
| updatePlaylist | POST | /playlist/update | 更新歌单信息 |

## comment.ts 评论

| 函数 | 方法 | 路径 | 说明 |
|---|---|---|---|
| getComment | GET | /comment/* | 评论列表 |
| likeComment | GET | /comment/like | 点赞评论 |
| getFloorComment | GET | /comment/floor | 楼层评论 |
| submitComment | POST | /comment | 发表/回复评论 |

## mv.ts MV

| 函数 | 方法 | 路径 | 说明 |
|---|---|---|---|
| mvDetail | GET | /mv/detail | MV 详情 |
| mvDetailInfo | GET | /mv/detail/info | MV 动态信息 |
| mvUrl | GET | /mv/url | MV 播放地址 |
| simiMv | GET | /simi/mv | 相似 MV |
| subAMV | POST | /mv/sub | 收藏/取消收藏 MV |
| likeAMV | GET | /comment/like | 点赞 MV |

## user.ts 用户

| 函数 | 方法 | 路径 | 说明 |
|---|---|---|---|
| userLikedSongsIDs | GET | /likelist | 喜欢歌曲 id 列表 |
| dailySignin | POST | /daily_signin | 每日签到 |
| likedAlbums | GET | /album/sublist | 收藏的专辑 |
| likedArtists | GET | /artist/sublist | 收藏的艺术家 |
| likedMVs | GET | /mv/sublist | 收藏的 MV |
| cloudDisk | GET | /user/cloud | 云盘列表 |
| cloudDiskTrackDetail | GET | /user/cloud/detail | 云盘歌曲详情 |
| userPlayHistory | GET | /user/record | 听歌历史 |
| userDetail | GET | /user/detail | 用户详情 |

## other.ts 其他

| 函数 | 方法 | 路径 | 说明 |
|---|---|---|---|
| searchMatch | GET | /search/match | 本地音乐在线匹配 |
| search | GET | /search | 搜索 |
| getBanner | GET | /banner | 首页 Banner |
| personalFM | GET | /personal/fm | 私人 FM |
| fmTrash | POST | /fm_trash | FM 垃圾桶 |
| songChorus | GET | /song/chorus | 副歌时间 |
