#!/usr/bin/env bash
# =============================================================================
# setup-git-submodule-global.sh
# 作用：在【新机器】上一键配置 git submodule 友好的全局默认项（幂等，可重复执行）
# 对应规范：references/git-submodule-workflow.md §2.3
# 只改当前用户的 ~/.gitconfig 全局配置，不动任何仓库内容；重复运行结果一致。
# 用法： bash scripts/setup-git-submodule-global.sh          # 配置并回显
#        bash scripts/setup-git-submodule-global.sh --unset  # 可选：移除这 4 条配置
# =============================================================================
set -euo pipefail

# key -> 推荐值
KEYS=(
  "diff.submodule|log"
  "status.submoduleSummary|true"
  "push.recurseSubmodules|on-demand"
  "submodule.recurse|true"
)

print_current() {
  echo "当前全局 submodule 相关配置："
  local any=0
  for kv in "${KEYS[@]}"; do
    local k="${kv%%|*}"
    local v
    if v="$(git config --global --get "$k" 2>/dev/null)" && [ -n "$v" ]; then
      printf '  %-28s = %s\n' "$k" "$v"; any=1
    else
      printf '  %-28s = (未设置)\n' "$k"; any=1
    fi
  done
  [ "$any" -eq 1 ]
}

case "${1:-}" in
  --unset|-u)
    echo "移除这 4 条全局配置..."
    for kv in "${KEYS[@]}"; do
      k="${kv%%|*}"
      git config --global --unset-all "$k" 2>/dev/null || true
      echo "  unset $k"
    done
    echo "完成。"
    print_current || true
    exit 0
    ;;
  "") ;;
  *) echo "未知参数：$1（仅支持 --unset）" >&2; exit 2;;
esac

command -v git >/dev/null 2>&1 || { echo "未找到 git，请先安装 git。" >&2; exit 1; }

echo "配置 submodule 友好的全局默认项（写入 ~/.gitconfig）..."
for kv in "${KEYS[@]}"; do
  k="${kv%%|*}"; val="${kv##*|}"
  git config --global "$k" "$val"
  printf '  set %-28s = %s\n' "$k" "$val"
done

echo
echo "说明："
echo "  diff.submodule=log              diff 时直接显示子模块新增提交"
echo "  status.submoduleSummary=true    status 时显示子模块变化摘要"
echo "  push.recurseSubmodules=on-demand 父仓 push 时自动先推有提交的子模块"
echo "  submodule.recurse=true          pull/fetch/checkout 默认递归（clone 仍需 --recurse-submodules）"
echo
print_current
echo

# 可选：若已安装 gita（多仓库总览工具），自动递归登记 ~/Doubao 仓库群
DOUBAO_ROOT="${DOUBAO_ROOT:-$HOME/Doubao}"
GITA=""
if command -v gita >/dev/null 2>&1; then GITA="gita"
elif [ -x /usr/local/bin/gita ]; then GITA=/usr/local/bin/gita        # Intel Homebrew 全局
elif [ -x /opt/homebrew/bin/gita ]; then GITA=/opt/homebrew/bin/gita; fi # Apple Silicon
if [ -n "$GITA" ] && [ -d "$DOUBAO_ROOT" ]; then
  "$GITA" add -r "$DOUBAO_ROOT" >/dev/null 2>&1 \
    && echo "已用 gita 递归登记 $DOUBAO_ROOT 下仓库（运行 'gita ll' 总览）"
fi

# 安装全局凭证命令 secrets（软链到 ~/.local/bin/secrets，幂等）
SECRETS_SH="$DOUBAO_ROOT/skills/mac-system-toolkit/scripts/secrets.sh"
[ -f "$SECRETS_SH" ] && bash "$SECRETS_SH" install

echo "完成。注意：这些是全局默认；全新克隆仍要记得 git clone --recurse-submodules。"
