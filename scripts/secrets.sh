#!/usr/bin/env bash
# =============================================================================
# secrets.sh — 统一凭证/密码加密工具（全机唯一约定，规范见 references/secret-encryption.md）
#
# 算法（固定，勿自行更改，以保证各机器/各项目互通）：
#   openssl enc -aes-256-cbc -salt -pbkdf2 -base64
#
# 密码来源优先级：环境变量 ENC_PASS  >  交互安全输入(read -s)
#   - 绝不把密码硬编码进任何文件，绝不猜测密码；脚本里不出现明文主密码。
#   - 非交互场景（脚本/CI）用 ENC_PASS=xxx secrets.sh ... 传入。
#
# 两级存放：
#   全局凭证  $DOUBAO_SECRETS_DIR（默认 ~/.doubao/secrets）/<name>.enc —— 跨项目、不进任何 git
#   项目凭证  <项目>/.secrets/*.enc —— 项目专属；明文不入库、.enc 可随仓库
#
# 用法：
#   secrets.sh encrypt <明文|-> [outfile]   加密一段字符串（- 表示从 stdin 读），默认输出到 stdout
#   secrets.sh decrypt <infile>             解密密文文件到 stdout
#   secrets.sh set <name> <明文|->          加密并存入全局目录 <name>.enc
#   secrets.sh get <name>                   从全局目录读取并解密
#   secrets.sh path <name>                  打印全局凭证密文路径
# =============================================================================
set -euo pipefail

# 加解密共用参数；解密时额外加 -d（-base64/-salt 在 -d 下同样需要/无害）
COMMON=(-aes-256-cbc -salt -pbkdf2 -base64)
GLOBAL_DIR="${DOUBAO_SECRETS_DIR:-$HOME/.doubao/secrets}"

read_pass() {
  if [ -n "${ENC_PASS:-}" ]; then
    PASS="$ENC_PASS"
  else
    read -s -p "Enter encryption password: " PASS; echo
  fi
  [ -n "$PASS" ] || { echo "错误：未提供加密密码（设置 ENC_PASS 或交互输入）" >&2; exit 1; }
}

# enc_to: $1=明文(- 表示stdin) $2=输出文件(空=stdout)
enc_to() {
  local plain="$1" out="${2:-}"
  read_pass
  if [ -n "$out" ]; then mkdir -p "$(dirname "$out")"; fi
  if [ "$plain" = "-" ]; then
    # shellcheck disable=SC2086
    openssl enc "${COMMON[@]}" -pass pass:"$PASS" ${out:+-out "$out"}
  else
    # shellcheck disable=SC2086
    printf '%s' "$plain" | openssl enc "${COMMON[@]}" -pass pass:"$PASS" ${out:+-out "$out"}
  fi
}

dec_from() { # $1=密文文件
  [ -f "$1" ] || { echo "错误：找不到密文文件 $1" >&2; exit 1; }
  read_pass
  openssl enc "${COMMON[@]}" -d -pass pass:"$PASS" -in "$1"
}

set_global() { # $1=name $2=plain|-
  local name="$1" out="$GLOBAL_DIR/$1.enc"
  mkdir -p "$GLOBAL_DIR"; chmod 700 "$GLOBAL_DIR"
  enc_to "$2" "$out"; chmod 600 "$out"
  echo "已保存（全局）: $out"
}

usage() {
  cat <<EOF
Usage: $0 <command> [args]
  encrypt <plain|-> [outfile]   加密字符串（- 从 stdin 读）
  decrypt <infile>              解密密文文件到 stdout
  set <name> <plain|->          加密存入全局目录 $GLOBAL_DIR
  get <name>                    解密全局凭证
  path <name>                   打印全局凭证密文路径
密码：优先 ENC_PASS 环境变量，否则交互输入；不硬编码、不猜测。
EOF
}

case "${1:-}" in
  encrypt) [ $# -ge 2 ] || { usage >&2; exit 1; }; enc_to "$2" "${3:-}" ;;
  decrypt) [ $# -ge 2 ] || { usage >&2; exit 1; }; dec_from "$2" ;;
  set)     [ $# -ge 3 ] || { usage >&2; exit 1; }; set_global "$2" "$3" ;;
  get)     [ $# -ge 2 ] || { usage >&2; exit 1; }; dec_from "$GLOBAL_DIR/$2.enc" ;;
  path)    [ $# -ge 2 ] || { usage >&2; exit 1; }; echo "$GLOBAL_DIR/$2.enc" ;;
  -h|--help|help|"") usage ;;
  *) echo "未知命令: $1" >&2; usage >&2; exit 1 ;;
esac
