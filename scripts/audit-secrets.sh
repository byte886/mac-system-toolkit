#!/usr/bin/env bash
# =============================================================================
# audit-secrets.sh — 多仓明文密钥巡检（不写死目录，也不内置任何真实密码）
#
# 递归发现「起始目录」下的所有 git 仓库，对每个仓库的 HEAD 快照（已提交的最新
# 版本）扫描四类风险；可选同时扫工作区未提交内容。
#   1) 高置信：通用密钥/私钥指纹（GitHub PAT、AWS/Google/Slack token、私钥块、sk- 等）
#   2) 中置信：password/secret/token 等变量被赋了字面量值（自动过滤变量引用/占位/示例）
#   3) 敏感文件被入库（.env、*.pem、*.key、id_rsa、credentials.json 等）
#   4) .secrets 目录里混入非 .enc 的明文
#
# 用法：
#   audit-secrets.sh [起始目录]                 默认取 $AUDIT_ROOT，再否则当前目录
#   audit-secrets.sh [目录] -p '自定义可疑正则'   追加高置信模式，可重复传
#                                              （例如 -p 'someSecret123'；不要把真实密码写进本脚本）
#   audit-secrets.sh [目录] -w / --worktree     额外扫描工作区（含未提交改动）
#   audit-secrets.sh -h
#
# 退出码：发现高置信命中=2；仅中置信/文件名提示=1；全部干净=0；用法错误=64
# 兼容 macOS 自带 bash 3.2（未用 mapfile/关联数组）。
# =============================================================================
set -uo pipefail

ROOT=""
SCAN_WORKTREE=0
EXTRA_PATTERNS=()

while [ $# -gt 0 ]; do
  case "$1" in
    -w|--worktree) SCAN_WORKTREE=1; shift ;;
    -p|--pattern)  [ $# -ge 2 ] || { echo "缺少 -p 的参数" >&2; exit 64; }; EXTRA_PATTERNS+=("$2"); shift 2 ;;
    -h|--help)
      sed -n '2,21p' "$0"; exit 0 ;;
    --) shift; ROOT="${1:-}"; shift ;;
    *) ROOT="$1"; shift ;;
  esac
done
ROOT="${ROOT:-${AUDIT_ROOT:-$PWD}}"
[ -d "$ROOT" ] || { echo "起始目录不存在: $ROOT" >&2; exit 64; }

# --- 通用密钥指纹（高置信）。绝不把真实主密码写进这里；自定义词用 -p 传 ---
HI='ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_\-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9]{24,}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
# --- 密码/密钥变量被赋字面量（中置信）---
MID='(password|passwd|pwd|secret|token|api[_-]?key|app[_-]?key|secret[_-]?key|access[_-]?token|refresh[_-]?token|credential)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}["'"'"']'
MID_FILTER='\$\{?[A-Za-z_]|<|>|example|your[_-]|xxx|changeme|getenv|environ|getpass|placeholder|dummy|sample|replace|\*\*\*|foo|bar'
# --- 不应入库的敏感文件名 ---
SENS_FILE='(^|/)(id_rsa|id_ed25519|\.env(\..*)?|.*\.pem|.*\.key|.*\.p12|.*\.pfx|credentials.*\.(json|txt|ya?ml)|.*secret.*\.(json|txt)|\.netrc|htpasswd)$'

hi_n=0; mid_n=0; file_n=0; repo_n=0

# 纯 bash 计算相对 ROOT 的展示名（不依赖 GNU realpath，兼容 macOS bash 3.2）
relname() { case "$1" in "$2"/*) echo "${1#$2/}" ;; *) basename "$1" ;; esac; }

scan_tree() { # $1=repo  $2=tree-ish(HEAD)或空(工作区)  $3=标签
  local repo="$1" tree="${2:-}" label="$3" where
  if [ -n "$tree" ]; then where="$tree"; else where="工作区"; fi
  # 高置信（内置 + 自定义）
  local out
  out="$(git -C "$repo" grep -nE "$HI" $tree -- . 2>/dev/null || true)"
  local p; for p in "${EXTRA_PATTERNS[@]:-}"; do [ -n "$p" ] && out="$out
$(git -C "$repo" grep -nE "$p" $tree -- . 2>/dev/null || true)"; done
  if [ -n "$(echo "$out" | sed '/^$/d')" ]; then
    echo "  [$label/$where][高置信] 疑似密钥/私钥："; echo "$out" | sed 's/^/    /'; hi_n=$((hi_n+1))
  fi
  # 中置信
  local m; m="$(git -C "$repo" grep -niE "$MID" $tree -- . 2>/dev/null | grep -viE "$MID_FILTER" || true)"
  if [ -n "$m" ]; then
    echo "  [$label/$where][待确认] 密码变量疑似字面量："; echo "$m" | sed 's/^/    /'; mid_n=$((mid_n+1))
  fi
}

echo "🔎 明文密钥巡检（根目录：${ROOT}；扫描 HEAD 快照$([ "$SCAN_WORKTREE" = 1 ] && echo ' + 工作区')）"
while IFS= read -r repo; do
  [ -z "$repo" ] && continue
  repo_n=$((repo_n+1))
  name="$(relname "$repo" "$ROOT")"
  [ "$name" = "." ] && name="$(basename "$repo")"
  hits_before=$((hi_n+mid_n+file_n))
  echo "─ $name"
  scan_tree "$repo" "HEAD" "HEAD"
  [ "$SCAN_WORKTREE" = 1 ] && scan_tree "$repo" "" "WT"
  # 敏感文件名（HEAD 跟踪文件）
  local_files="$(git -C "$repo" ls-files 2>/dev/null | grep -iE "$SENS_FILE" || true)"
  if [ -n "$local_files" ]; then
    echo "  [文件名][待确认] 敏感文件被入库："; echo "$local_files" | sed 's/^/    /'; file_n=$((file_n+1))
  fi
  # .secrets 内非 .enc
  plain="$(git -C "$repo" ls-files 2>/dev/null | grep -E '(^|/)\.secrets/' | grep -vE '\.enc$' || true)"
  if [ -n "$plain" ]; then
    echo "  [.secrets][高置信] 存在非 .enc 明文："; echo "$plain" | sed 's/^/    /'; hi_n=$((hi_n+1))
  fi
done < <(
  find "$ROOT" \( -name venv -o -name node_modules -o -name .trash \) -prune -o \
       -name .git \( -type f -o -type d \) -print 2>/dev/null \
    | grep -v '/.git/modules/' | while IFS= read -r g; do dirname "$g"; done | sort -u
)

echo
echo "════ 汇总：扫描 $repo_n 个仓库 | 高置信 $hi_n | 待确认(字面量) $mid_n | 敏感文件 $file_n ════"
if [ "$hi_n" -gt 0 ]; then exit 2
elif [ $((mid_n+file_n)) -gt 0 ]; then exit 1
else echo "✅ 未发现明文密钥"; exit 0; fi
