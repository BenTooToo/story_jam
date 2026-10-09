#!/bin/bash
# 导出 B 站（Toy）网页版并打包。
#
#   bash bilibili/export_web.sh
#
# 生成 ../story_jam_web/（和本工程同级）和 ../story_jam_web.zip（上传 Toy 用这个 zip）。
# 用 "Web" 导出预设：无线程、壳是 bilibili/shell.html。然后把引擎 gzip 成 index.wasm.gz.bin，
# shell.html 会优先下载它、在浏览器里边下边解压（Toy 的 CDN 对 .wasm 不压缩，39MB → 10MB）；
# 原文件也留着，给不支持解压的老浏览器兜底。资源包不压：里面几乎全是 mp3 / ogv，gzip 只省 4%。
# 每次发版先改 bilibili/VERSION。
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
OUT="../story_jam_web"
rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --export-release "Web" "$OUT/index.html"
# 加载画面左上角、选线界面左上角的版本号：VERSION + 导出时间（北京时间，玩家看到的就是这个）
VERSION="v$(tr -d '[:space:]' < bilibili/VERSION) · $(TZ=Asia/Shanghai date '+%m.%d %H:%M')"
sed -i '' "s/__GAME_VERSION__/$VERSION/" "$OUT/index.html"
# 加载画面用的标题画面
cp bilibili/splash.png "$OUT/splash.png"
gzip -9 -c "$OUT/index.wasm" > "$OUT/index.wasm.gz.bin"
rm -f ../story_jam_web.zip
(cd "$OUT" && zip -q -r ../story_jam_web.zip . -x '.DS_Store')
ls -la "$OUT" ../story_jam_web.zip
