#!/bin/bash
# Mac 综合健康检查脚本
# 检查项：CPU温度/负载、内存压力、硬盘空间/SMART、网络连通性、风扇状态、系统运行时间
# 用法：bash health_check.sh [--full] [--json]
#   --full  包含 iStats 完整传感器扫描
#   --json  输出 JSON 格式（默认人类可读）

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FULL_MODE=false
JSON_MODE=false

for arg in "$@"; do
  case "$arg" in
    --full) FULL_MODE=true ;;
    --json) JSON_MODE=true ;;
  esac
done

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# JSON 收集器
JSON_RESULTS="{}"

add_json() {
  local key="$1" value="$2"
  JSON_RESULTS=$(echo "$JSON_RESULTS" | python3 -c "import sys,json; d=json.load(sys.stdin); d['$key']='$value'; print(json.dumps(d))")
}

print_header() {
  if [ "$JSON_MODE" = false ]; then
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Mac 综合健康检查${NC}"
    echo -e "${BLUE}  $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
  fi
}

print_section() {
  if [ "$JSON_MODE" = false ]; then
    echo -e "${BLUE}【$1】${NC}"
  fi
}

print_ok() {
  if [ "$JSON_MODE" = false ]; then
    echo -e "  ${GREEN}✓${NC} $1"
  fi
}

print_warn() {
  if [ "$JSON_MODE" = false ]; then
    echo -e "  ${YELLOW}⚠${NC} $1"
  fi
}

print_error() {
  if [ "$JSON_MODE" = false ]; then
    echo -e "  ${RED}✗${NC} $1"
  fi
}

print_header

# ========== 1. 系统信息 ==========
print_section "系统信息"
MODEL=$(sysctl -n hw.model 2>/dev/null || echo "未知")
OS_VER=$(sw_vers -productVersion 2>/dev/null || echo "未知")
UPTIME=$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}' | xargs)
echo "  机型: $MODEL"
echo "  系统: macOS $OS_VER"
echo "  运行时间: $UPTIME"
add_json "model" "$MODEL"
add_json "os_version" "$OS_VER"
add_json "uptime" "$UPTIME"
echo ""

# ========== 2. CPU 温度与负载 ==========
print_section "CPU 温度与负载"

# CPU 负载
LOAD=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2, $3, $4}' | tr ' ' '/')
CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo "?")
echo "  核心数: $CPU_CORES"
echo "  负载(1/5/15分钟): $LOAD"

# 判断负载
LOAD1=$(echo "$LOAD" | cut -d'/' -f1)
LOAD_STATUS=$(python3 -c "print('正常' if float('$LOAD1') < float('$CPU_CORES')*0.7 else ('偏高' if float('$LOAD1') < float('$CPU_CORES') else '危险'))" 2>/dev/null || echo "未知")
case "$LOAD_STATUS" in
  正常) print_ok "CPU 负载正常" ;;
  偏高) print_warn "CPU 负载偏高" ;;
  危险) print_error "CPU 负载过高" ;;
esac
add_json "cpu_load" "$LOAD"
add_json "cpu_load_status" "$LOAD_STATUS"

# CPU 温度（需 iStats）
if command -v istats &>/dev/null; then
  CPU_TEMP=$(istats cpu 2>/dev/null | grep -i "temp" | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
  if [ -n "$CPU_TEMP" ]; then
    echo "  CPU 温度: ${CPU_TEMP}°C"
    TEMP_STATUS=$(python3 -c "print('正常' if float('$CPU_TEMP') < 65 else ('偏高' if float('$CPU_TEMP') < 85 else '危险'))" 2>/dev/null || echo "未知")
    case "$TEMP_STATUS" in
      正常) print_ok "CPU 温度正常" ;;
      偏高) print_warn "CPU 温度偏高" ;;
      危险) print_error "CPU 温度过高" ;;
    esac
    add_json "cpu_temp" "$CPU_TEMP"
    add_json "cpu_temp_status" "$TEMP_STATUS"
  fi
else
  print_warn "iStats 未安装，无法读取 CPU 温度。运行 check_temp.sh 安装"
fi
echo ""

# ========== 3. 内存压力 ==========
print_section "内存压力"

MEM_FREE_PCT=$(memory_pressure 2>/dev/null | grep "System-wide memory free percentage" | grep -oE '[0-9]+' | head -1)
if [ -n "$MEM_FREE_PCT" ]; then
  echo "  空闲内存: ${MEM_FREE_PCT}%"
  if [ "$MEM_FREE_PCT" -gt 20 ]; then
    print_ok "内存压力正常"
    MEM_STATUS="正常"
  elif [ "$MEM_FREE_PCT" -gt 10 ]; then
    print_warn "内存压力偏高，建议关闭不必要的 App"
    MEM_STATUS="偏高"
  else
    print_error "内存压力危险，系统可能卡顿"
    MEM_STATUS="危险"
  fi
  add_json "memory_free_pct" "$MEM_FREE_PCT"
  add_json "memory_status" "$MEM_STATUS"
else
  print_warn "无法读取内存压力信息"
fi
echo ""

# ========== 4. 硬盘检查 ==========
print_section "硬盘空间"

df -h / | tail -1 | while read line; do
  DISK=$(echo "$line" | awk '{print $1}')
  TOTAL=$(echo "$line" | awk '{print $2}')
  USED=$(echo "$line" | awk '{print $3}')
  AVAIL=$(echo "$line" | awk '{print $4}')
  USED_PCT=$(echo "$line" | awk '{print $5}' | tr -d '%')
  echo "  磁盘: $DISK"
  echo "  总计: $TOTAL / 已用: $USED / 可用: $AVAIL"
  echo "  使用率: ${USED_PCT}%"
done

USED_PCT=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$USED_PCT" -lt 80 ]; then
  print_ok "硬盘空间充足"
  DISK_STATUS="正常"
elif [ "$USED_PCT" -lt 90 ]; then
  print_warn "硬盘空间偏少，建议清理"
  DISK_STATUS="偏少"
else
  print_error "硬盘空间严重不足，系统可能变慢"
  DISK_STATUS="危险"
fi
add_json "disk_used_pct" "$USED_PCT"
add_json "disk_status" "$DISK_STATUS"

# SMART 状态
SMART=$(diskutil info / 2>/dev/null | grep "SMART Status" | awk -F': ' '{print $2}' | xargs)
if [ -n "$SMART" ]; then
  echo "  SMART 状态: $SMART"
  if [ "$SMART" = "Verified" ]; then
    print_ok "SMART 状态正常"
  else
    print_error "SMART 状态异常，立即备份数据！"
  fi
  add_json "smart_status" "$SMART"
fi
echo ""

# ========== 5. 网络连通性 ==========
print_section "网络连通性"

# 默认网关
GATEWAY=$(route -n get default 2>/dev/null | grep gateway | awk '{print $2}')
if [ -n "$GATEWAY" ]; then
  echo "  网关: $GATEWAY"
  if ping -c 2 -t 3 "$GATEWAY" &>/dev/null; then
    print_ok "局域网连通"
    add_json "lan_status" "正常"
  else
    print_error "局域网不通"
    add_json "lan_status" "异常"
  fi
fi

# 公网连通
if ping -c 2 -t 5 8.8.8.8 &>/dev/null; then
  print_ok "互联网连通（8.8.8.8）"
  add_json "internet_status" "正常"
else
  print_warn "无法 ping 通 8.8.8.8（可能被防火墙拦截）"
  add_json "internet_status" "未知"
fi

# DNS 解析
if nslookup google.com 2>/dev/null | grep -q "Address"; then
  print_ok "DNS 解析正常"
  add_json "dns_status" "正常"
else
  print_error "DNS 解析失败"
  add_json "dns_status" "异常"
fi

# 代理连通性（如果 ClashX 在运行）
if lsof -i :7890 &>/dev/null; then
  PROXY_TEST=$(curl -s --connect-timeout 5 -x http://127.0.0.1:7890 https://www.google.com -o /dev/null -w "%{http_code}" 2>/dev/null || echo "000")
  if [ "$PROXY_TEST" = "200" ]; then
    print_ok "代理连通（ClashX :7890）"
    add_json "proxy_status" "正常"
  else
    print_warn "代理端口在监听但测试失败（HTTP $PROXY_TEST）"
    add_json "proxy_status" "异常"
  fi
else
  echo "  代理: 未检测到 ClashX 运行"
  add_json "proxy_status" "未运行"
fi
echo ""

# ========== 6. 风扇状态 ==========
print_section "风扇状态"

if command -v istats &>/dev/null; then
  FAN_INFO=$(istats fan 2>/dev/null)
  FAN_COUNT=$(echo "$FAN_INFO" | grep "Total fans" | grep -oE '[0-9]+')
  RUNNING_FANS=$(echo "$FAN_INFO" | grep -E "Fan [0-9]+ speed" | grep -vE "0 RPM" | wc -l | tr -d ' ')
  echo "  风扇总数: $FAN_COUNT"
  echo "  运转中: $RUNNING_FANS 个"
  echo "$FAN_INFO" | grep -E "Fan [0-9]+ speed" | while read line; do
    echo "  $line"
  done
  add_json "fan_count" "$FAN_COUNT"
  add_json "fan_running" "$RUNNING_FANS"
else
  print_warn "iStats 未安装，无法读取风扇转速"
fi
echo ""

# ========== 7. 完整传感器（--full 模式） ==========
if [ "$FULL_MODE" = true ] && command -v istats &>/dev/null; then
  print_section "完整传感器扫描"
  istats scan 2>/dev/null || istats 2>/dev/null
  echo ""
fi

# ========== 总结 ==========
if [ "$JSON_MODE" = false ]; then
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}  检查完成${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
  echo "提示："
  echo "  - 温度/风扇详情运行: bash $SCRIPT_DIR/check_temp.sh"
  echo "  - 完整传感器扫描: bash $0 --full"
  echo "  - JSON 输出: bash $0 --json"
else
  echo "$JSON_RESULTS" | python3 -m json.tool
fi
