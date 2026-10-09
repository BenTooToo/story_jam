# 背景音乐

都是 Mumu 自己写的曲子，从 B 站投稿视频里抽出来的音轨（AAC 转 mp3 192k）。

| 文件 | 来源 | 用在哪 |
| --- | --- | --- |
| 乐队之歌.mp3 | 《给乐队写了首歌，他们还不知道自己要演这个》 | 阶段一：互扔大战 |
| 番剧之歌.mp3 | 《试着做了一首二次元浓度极高的歌，这是属于哪部不存在的番剧？》 | 阶段三：电梯怪兽 |

## 以后再从 B 站视频抽音轨

B 站客户端下载的是 `~/Movies/bilibili/<编号>/` 下的两个 `.m4s`，
编号 `30280` 的是音轨（`30080` 等是画面）。文件开头多塞了 9 个 `0` 字符，
ffmpeg 读不了，先去掉再转：

```bash
tail -c +10 xxx-1-30280.m4s > song.m4a
ffmpeg -i song.m4a -c:a libmp3lame -b:a 192k song.mp3
```

哪个编号对应哪个视频看同目录的 `videoInfo.json` 里的 `title`。

## 试玩曲（非原创，带水印，不进正式流程）

| 文件 | 来源 | 用在哪 |
| --- | --- | --- |
| 不如跳舞.mp3 / .ogv | 陈慧琳《不如跳舞》B 站视频 | 数字键 9：跳舞阶段整首试玩，视频在电梯箱里的小屏幕上放 |
| 秒針を噛む.mp3 / .ogv | ずっと真夜中でいいのに。《秒針を噛む》B 站视频 | 字母 J |
| Levitating.mp3 / .ogv | Dua Lipa《Levitating》B 站视频 | 字母 L |

BPM / 起拍秒数 / 段落都登记在 `Stories/Phases/Dance/dance_phase.gd` 的 `SONGS` 里。

Godot 只认 Theora 的 `.ogv`，Homebrew 的 ffmpeg 9 没带 libtheora，
用 `pip install imageio-ffmpeg` 里自带的静态 ffmpeg 转：

```bash
# 游戏里是电梯内 96x54 的小屏，320x180 够用（窗口放大也不糊）
ffmpeg -i video.mp4 -an -vf scale=320:180 -c:v libtheora -q:v 6 out.ogv
```

音轨单独抽成 mp3 用 AudioStreamPlayer 放，视频静音只当画面，谱面时钟只跟音轨。
