#!/usr/bin/env bash
# 一键安装 CleanYourTV 玻璃主题定制版到电视。
# 用法:
#   TV_HOST=192.168.1.50 bash tools/install.sh
# 也可编辑下方的 DEFAULT_HOST 后直接运行。
set -euo pipefail

PKG=com.gathin.tvhome
DIR=/sdcard/Android/data/$PKG/files
DEFAULT_HOST=""

TV_HOST="${TV_HOST:-$DEFAULT_HOST}"
if [ -z "$TV_HOST" ]; then
  echo "用法: TV_HOST=电视IP bash tools/install.sh" >&2
  exit 1
fi

# 仓库根目录（脚本在 tools/ 下，上溯一层）；Git Bash 用 pwd -W 取 Windows 格式路径，adb.exe 才能识别
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && { pwd -W 2>/dev/null || pwd; })"
APK="$ROOT/app-release.apk"
THEME="$ROOT/themes/glass"

# 防止 Git Bash 把设备端 /data/... 路径改写成 Windows 路径
export MSYS_NO_PATHCONV=1

echo ">>> 连接电视 $TV_HOST"
adb connect "$TV_HOST:5555"

echo ">>> 安装 APK"
adb install -r "$APK"

echo ">>> 推送玻璃主题"
adb push "$THEME/config.json" /data/local/tmp/cyt-config.json
adb shell "cat /data/local/tmp/cyt-config.json | content write --uri content://$PKG.theme/config.json" || \
  adb shell "cp /data/local/tmp/cyt-config.json $DIR/config.json"
adb push "$THEME/wallpaper.jpg" /data/local/tmp/cyt-wp.jpg
adb shell "cat /data/local/tmp/cyt-wp.jpg | content write --uri content://$PKG.theme/wallpaper.jpg" || \
  adb shell "cp /data/local/tmp/cyt-wp.jpg $DIR/wallpaper.jpg"

echo ">>> 重启电视以刷新网络权限（天气需要）"
adb reboot

echo "完成。电视重启后请在电视上重新授权 USB 调试，并把 CleanYourTV 设为默认桌面；"
echo "主界面顶部会自动显示本地天气（温度° 天气 · PM2.5 数值）。"
