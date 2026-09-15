#!/usr/bin/env bash
# =============================================================================
# secrets.sh — 全机唯一的凭证/密码加密工具（全局命令，规范见 references/secret-encryption.md）
#
# 设计为“全局唯一一份”：权威源在 mac-system-toolkit 技能里随 git 版本化，
# 通过 `secrets install` 软链到 ~/.local/bin/secrets（PATH 内），任何项目/目录
# 直接敲 `secrets` 使用；各项目不再各自保存副本，只保留自己的 .secrets/*.enc 密文。
#
# 算法（固定，勿改，保证各机器/各项目互通）：openssl enc -aes-256-cbc -salt -pbkdf2 -base64
#
# 密码来源优先级：ENC_PASS > ENCRYPT_PASS(兼容旧名) > 交互安全输入(read -s)
#   - 绝不把主密码硬编码进任何文件，绝不猜测；非交互场景用环境变量传入。
#
# 两级密文存放：
#   全局  $DOUBAO_SECRETS_DIR（默认 ~/.doubao/secrets）<name>.enc —— 跨项目、不进 git
#   项目  <项目>/.secrets/*.enc —— 项目专属；明文不入库、.enc 可随仓库
#
# 用法：
#   secrets install                         安装全局命令软链（新机器执行一次）
#   secrets encrypt <明文|-> [outfile]      加密字符串（- 从 stdin 读）
#   secrets decrypt <infile>                解密密文文件到 stdout
#   secrets json <infile> [field]           解密 JSON 密文；给字段只输出该字段
#   secrets set <name> <明文|->             加密存入全局目录 <name>.enc
#   secrets get <name>                      从全局目录读取并解密
#   secrets path <name>                     打印全局凭证密文路径
# =============================================================================
set -euo pipefail

COMMON=(-aes-256-cbc -salt -pbkdf2 -base64)
GLOBAL_DIR="${DOUBAO_SECRETS_DIR:-$HOME/.doubao/secrets}"
BIN_LINK="$HOME/.local/bin/secrets"

read_pass() {
  if   [ -n "${ENC_PASS:-}" ];     then PASS="$ENC_PASS"
  elif [ -n "${ENCRYPT_PASS:-}" ]; then PASS="$ENCRYPT_PASS"   # 兼容历史变量名
  else read -s -p "Enter encryption password: " PASS; echo
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

json_from() { # $1=JSON密文文件 $2=字段(可选)
  local json; json="$(dec_from "$1")"
  if [ -n "${2:-}" ]; then
    echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('$2',''))"
  else
    echo "$json"
  fi
}

set_global() { # $1=name $2=plain|-
  local out="$GLOBAL_DIR/$1.enc"
  mkdir -p "$GLOBAL_DIR"; chmod 700 "$GLOBAL_DIR"
  enc_to "$2" "$out"; chmod 600 "$out"
  echo "已保存（全局）: $out"
}

do_install() {
  local src
  src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  chmod +x "$src"
  mkdir -p "$(dirname "$BIN_LINK")"
  ln -sf "$src" "$BIN_LINK"
  echo "已安装全局命令: $BIN_LINK -> $src"
  echo "现在任意目录可用：secrets get <name> | secrets decrypt <file> | secrets json <file> [field]"
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [args]
  install                      安装全局命令软链到 ${BIN_LINK}（新机器一次）
  encrypt <plain|-> [outfile]  加密字符串（- 从 stdin 读）
  decrypt <infile>             解密密文文件到 stdout
  json <infile> [field]        解密 JSON 密文，可选只取一个字段
  set <name> <plain|->         加密存入全局目录 ${GLOBAL_DIR}
  get <name>                   解密全局凭证
  path <name>                  打印全局凭证密文路径
密码优先级：ENC_PASS > ENCRYPT_PASS(旧名兼容) > 交互输入；不硬编码、不猜测。
EOF
}

case "${1:-}" in
  install) do_install ;;
  encrypt) [ $# -ge 2 ] || { usage >&2; exit 1; }; enc_to "$2" "${3:-}" ;;
  decrypt) [ $# -ge 2 ] || { usage >&2; exit 1; }; dec_from "$2" ;;
  json)    [ $# -ge 2 ] || { usage >&2; exit 1; }; json_from "$2" "${3:-}" ;;
  set)     [ $# -ge 3 ] || { usage >&2; exit 1; }; set_global "$2" "$3" ;;
  get)     [ $# -ge 2 ] || { usage >&2; exit 1; }; dec_from "$GLOBAL_DIR/$2.enc" ;;
  path)    [ $# -ge 2 ] || { usage >&2; exit 1; }; echo "$GLOBAL_DIR/$2.enc" ;;
  -h|--help|help|"") usage ;;
  *) echo "未知命令: $1" >&2; usage >&2; exit 1 ;;
esac
