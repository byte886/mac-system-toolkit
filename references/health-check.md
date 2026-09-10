# 硬件健康检查指南

## 概述

综合健康检查覆盖：CPU 温度/负载、GPU 温度、内存压力、硬盘空间/SMART、网络连通性、风扇状态、电池健康（笔记本）。

**一键检查**：
```bash
bash /Users/wenjiechen/Doubao/skills/mac-system-toolkit/scripts/health_check.sh
```

## 检查项详解

### 1. CPU 温度与负载

```bash
# CPU 温度（需 iStats）
istats cpu

# CPU 负载（1分钟/5分钟/15分钟平均）
sysctl -n vm.loadavg

# CPU 使用率
top -l 1 -n 0 | grep "CPU usage"
```

**正常范围**：
| 状态 | 温度 | 负载（4核参考） |
|------|------|----------------|
| 空闲 | 40-55°C | < 1.0 |
| 轻度负载 | 50-65°C | 1.0-3.0 |
| 高负载 | 65-85°C | 3.0-7.0 |
| 危险 | > 90°C | > 8.0（持续） |

### 2. GPU 温度

```bash
# 集成 GPU 温度通常包含在 istats 输出中
istats scan | grep -i gpu

# Apple Silicon 的 GPU 与 CPU 共享温度传感器
```

**正常范围**：空闲 40-55°C，高负载 60-85°C，危险 > 90°C。

### 3. 内存压力

```bash
# 内存压力状态（normal/warning/critical）
memory_pressure | grep "System-wide memory free percentage"

# 内存使用概况
vm_stat | head -10

# 顶部进程内存占用
top -l 1 -o mem -n 10 | head -20
```

**判断标准**：
- **normal**：空闲内存 > 20%，正常
- **warning**：空闲内存 10-20%，关注
- **critical**：空闲内存 < 10%，可能卡顿，关闭不必要的 App

### 4. 硬盘检查

#### 空间使用

```bash
# 各挂载点空间
df -h

# 启动磁盘详情
diskutil info / | grep -E "Volume Name|Total Size|Free Space|SMART Status"
```

**空间判断**：
- 剩余 > 20%：健康
- 剩余 10-20%：关注，建议清理
- 剩余 < 10%：危险，系统可能变慢，必须清理

#### SMART 状态

```bash
# 查看 SMART 状态（内置磁盘）
diskutil info / | grep "SMART Status"

# 输出 "Verified" = 正常，"Failing" = 即将故障，立即备份
```

#### 外接硬盘

```bash
# 列出所有磁盘
diskutil list

# 查看特定磁盘信息（替换 diskN）
diskutil info diskN
```

### 5. 网络连通性

```bash
# 默认网关
route -n get default | grep gateway

# ping 网关（局域网连通性）
ping -c 3 -t 5 $(route -n get default 2>/dev/null | grep gateway | awk '{print $2}')

# ping 公网 DNS（互联网连通性）
ping -c 3 -t 5 8.8.8.8

# DNS 解析
nslookup google.com 2>&1 | head -5

# 代理连通性（如果启用）
curl -s --connect-timeout 5 -x http://127.0.0.1:7890 https://www.google.com -o /dev/null -w "Google via proxy: %{http_code} %{time_total}s\n"
```

**判断标准**：
- 网关 ping 通：局域网正常
- 8.8.8.8 ping 通：互联网正常
- DNS 解析成功：DNS 正常
- 代理测试 200：代理正常

### 6. 风扇状态

```bash
# 风扇转速（需 iStats）
istats fan

# 或用系统命令
ioreg -c IOHWSensor | grep -i fan
```

**判断标准**：
- 空闲时低转速（1000-2000 RPM）或停转：正常
- 空闲时高转速（>3000 RPM）：可能散热不良或后台高负载
- 温度高但风扇不转：可能风扇故障
- 风扇异响：硬件问题，建议检修

### 7. 电池健康（仅笔记本）

```bash
# 电池信息
system_profiler SPPowerDataType | grep -E "Cycle Count|Condition|Maximum Capacity|Full Charge Capacity|Charging"

# 或简化
pmset -g batt
```

**判断标准**：
- 循环计数 < 300：良好
- 循环计数 300-800：正常使用
- 循环计数 > 1000：建议更换
- 状态 Normal：正常
- 状态 Replace Soon / Replace Now：需要更换
- 最大容量 > 85%：良好；< 80%：建议更换

### 8. 系统运行时间与负载

```bash
# 运行时间
uptime

# 系统版本
sw_vers

# 内核日志中的硬件错误（最近）
log show --predicate 'eventMessage contains "error"' --last 1h 2>/dev/null | grep -i "thermal\|fan\|disk\|memory" | head -10
```

## 温度正常范围速查

| 部件 | 空闲 | 高负载 | 危险 |
|------|------|--------|------|
| CPU（Intel） | 40-55°C | 65-85°C | > 95°C |
| CPU（Apple Silicon） | 35-50°C | 55-80°C | > 90°C |
| GPU（独显） | 40-55°C | 65-85°C | > 95°C |
| GPU（集显/Apple Silicon） | 35-50°C | 55-80°C | > 90°C |
| SSD | 30-45°C | 40-60°C | > 70°C |
| HDD | 30-40°C | 35-50°C | > 60°C |
| 内存 | 30-45°C | 40-60°C | > 70°C |

详细温度说明见上方各检查项的正常范围。

## 健康度评分（参考）

可按以下维度粗略评分（每项 0-10 分，满分 80）：

| 维度 | 满分条件 | 扣分条件 |
|------|---------|---------|
| CPU 温度 | 空闲 < 60°C | 每超 5°C 扣 1 分 |
| CPU 负载 | 1分钟平均 < 2.0 | 每超 1.0 扣 1 分 |
| 内存压力 | normal | warning 扣 3 分，critical 扣 7 分 |
| 硬盘空间 | 剩余 > 20% | 每少 5% 扣 1 分 |
| SMART 状态 | Verified | Failing 直接 0 分 |
| 网络连通 | 网关+公网+DNS 全通 | 每项不通扣 2 分 |
| 风扇状态 | 转速正常无异响 | 不转扣 5 分，异响扣 3 分 |
| 系统稳定 | 运行 > 7 天无崩溃 | 最近崩溃扣 3 分 |

**评分参考**：> 70 优秀，55-70 良好，40-55 关注，< 40 需处理。

## 降温/优化建议

温度偏高或负载高时，按顺序尝试：
1. 活动监视器查看高 CPU/内存进程，关闭不必要的 App
2. 笔记本用散热支架，确保进风口不被遮挡
3. 台式机确保周围通风，不塞入密闭空间
4. 清理硬盘空间（剩余 < 15% 时系统会变慢）
5. 重启释放内存和缓存
6. 使用 1-2 年后清理风扇和散热片灰尘
7. 检查是否有恶意软件（异常高温可能是后台挖矿）
