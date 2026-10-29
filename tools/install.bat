@echo off
setlocal
set PKG=com.gathin.tvhome
set DIR=/sdcard/Android/data/%PKG%/files

if "%TV_HOST%"=="" (
  echo 用法: 先设置电视IP，例如:
  echo   set TV_HOST=192.168.1.50
  echo   然后运行 tools\install.bat
  exit /b 1
)

rem 仓库根目录（脚本在 tools\ 下，上溯一层并规范化为绝对路径）
set ROOT=%~dp0..
for %%I in ("%ROOT%") do set ROOT=%%~fI
set APK=%ROOT%\app-release.apk
set THEME=%ROOT%\themes\glass

echo 连接电视 %TV_HOST%
adb connect %TV_HOST%:5555

echo 安装 APK
adb install -r "%APK%"

echo 推送玻璃主题
adb push "%THEME%\config.json" /data/local/tmp/cyt-config.json
adb shell "cat /data/local/tmp/cyt-config.json | content write --uri content://%PKG%.theme/config.json" || adb shell "cp /data/local/tmp/cyt-config.json %DIR%/config.json"
adb push "%THEME%\wallpaper.jpg" /data/local/tmp/cyt-wp.jpg
adb shell "cat /data/local/tmp/cyt-wp.jpg | content write --uri content://%PKG%.theme/wallpaper.jpg" || adb shell "cp /data/local/tmp/cyt-wp.jpg %DIR%/wallpaper.jpg"

echo 重启电视以刷新网络权限（天气需要）
adb reboot

echo 完成。电视重启后请在电视上重新授权 USB 调试，并把 CleanYourTV 设为默认桌面；
echo 主界面顶部会自动显示本地天气（温度° 天气 · PM2.5 数值）。
endlocal
