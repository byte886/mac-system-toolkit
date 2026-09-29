#!/usr/bin/env bash
# cdp_consent_guard.sh — 全局单例「Chrome 远程调试授权」兜底守护（技能通用版）
#
# 适用：整个自动化/下载周期内，授权 sheet 可能晚到、点一次没关掉、或连接进程退出后残留。
#       connect_browser.js 的 startPressLoop 只覆盖握手窗口，本守护覆盖「整个运行周期」。
#
# 行为：
#   - 全局单例（pidfile 放 TMPDIR），重复启动安全退出；
#   - 每 1s 用一条轻量 AppleEvent 同时取「当前前台 App + Chrome 授权 sheet 数」，
#     只数 sheet、绝不遍历网页 AXWebArea（毫秒级，见 press_allow.applescript 注释）；
#   - 记住最近一个非 Chrome 前台 App；发现 sheet 即跨进程锁代点「允许」，
#     没掉掉下一秒继续，并把焦点还原；无 sheet 零动作。
#
# 用法：bash cdp_consent_guard.sh        前台运行（Ctrl-C 结束）
#       nohup bash cdp_consent_guard.sh & 后台运行；结束：kill $(cat "${TMPDIR:-/tmp}/cdp_consent_guard.pid")
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDFILE="${TMPDIR:-/tmp}/cdp_consent_guard.pid"
LOCKED_PRESS="$SCRIPT_DIR/press_allow_locked.sh"

if [ -f "$PIDFILE" ]; then
  old="$(cat "$PIDFILE" 2>/dev/null)"
  if [ -n "$old" ] && kill -0 "$old" 2>/dev/null; then
    exit 0
  fi
fi
echo $$ > "$PIDFILE"
cleanup() { rm -f "$PIDFILE" 2>/dev/null; exit 0; }
trap cleanup EXIT INT TERM

if command -v caffeinate >/dev/null 2>&1; then
  caffeinate -i -w $$ &
fi

last_human=""
READ_SCRIPT='tell application "System Events"
set f to name of first process whose frontmost is true
set n to 0
if exists process "Google Chrome" then
tell process "Google Chrome" to set n to (count of sheets of windows)
end if
return f & linefeed & (n as string)
end tell'

while true; do
  read -r front n_sheet <<EOF
$(osascript -e "$READ_SCRIPT" 2>/dev/null | grep -v ApplePersistence | tr -d '\r')
EOF

  if [ -n "${front:-}" ] && [ "$front" != "Google Chrome" ]; then
    last_human="$front"
  fi

  if [ -n "${n_sheet:-}" ] && [ "$n_sheet" != "0" ]; then
    bash "$LOCKED_PRESS" "$last_human" >/dev/null 2>&1
  fi

  sleep 1
done
