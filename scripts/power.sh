#!/bin/bash
# MAC power control via Cloudflare Tunnel webhook
# Usage: ./power.sh {shutdown|restart} [delay_seconds]
# Outputs PID of background timer; kill it to cancel.

ACTION="$1"
DELAY="${2:-30}"
TOKEN="***REMOVED***"
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
