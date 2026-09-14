#!/bin/bash
# MAC power control via Cloudflare Tunnel webhook
# Usage: ./power.sh {shutdown|restart} [delay_seconds]
# Outputs PID of background timer; kill it to cancel.
# Webhook token 不存明文：加密在 ../.secrets/power_webhook.enc，运行时按
# references/secret-encryption.md 统一约定解密（密码取 ENC_PASS 或交互输入）。

set -euo pipefail

ACTION="$1"
DELAY="${2:-30}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN="$(ENC_PASS="${ENC_PASS:-}" bash "$SCRIPT_DIR/secrets.sh" decrypt "$SCRIPT_DIR/../.secrets/power_webhook.enc")"
BASE_URL="https://power.ds-guides.wiki"

case "$ACTION" in
  shutdown) URL="$BASE_URL/shutdown?token=$TOKEN" ;;
  restart)  URL="$BASE_URL/restart?token=$TOKEN" ;;
  *)
    echo "Usage: $0 {shutdown|restart} [delay_seconds]"
    exit 1
    ;;
esac

( sleep "$DELAY" && curl -sf "$URL" ) &
PID=$!
echo "PID=$PID"
echo "ACTION=$ACTION"
echo "DELAY=${DELAY}s"
