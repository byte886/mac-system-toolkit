# 电源管理指南

## 概述

覆盖：豆包会话忙碌检测、Mac 关机/重启（延迟可取消）。

**架构**：
```
用户触发 → AI 检测/执行 → Cloudflare Tunnel (power.ds-guides.wiki) → 本机 127.0.0.1:8765 → Python webhook → osascript 关机/重启
```

**本机服务**（launchd 开机自启）：
- `com.user.powerwebhook` — webhook 服务
- `com.user.cloudflared-power` — Cloudflare 隧道

---

## 一、豆包忙碌检测

**触发词**："豆包忙吗"、"豆包忙不忙"、"检查豆包状态"

### 执行步骤

1. 用 `mac_computer_use_tool(plane="cu")` 调用 `cu.get_app_state("com.bot.pc.doubao", screenshot=True)` 获取豆包窗口截图。
2. **只看侧边栏**：识别哪些会话项右侧有加载转圈（spinner）或未读数字徽章。没有任何标记的会话跳过，不要逐个点开。
3. 对有标记的会话，点击进入查看：
   - 输入框是否有未发送内容
   - AI 最后回复是否完整（有无"正在处理""后台运行""等待完成"等表述）
   - 是否提到后台任务（上传、下载、渲染等）
4. 汇总报告：列出活跃会话名称 + 任务详情 + 是否建议等待。

### 报告模板

```
## 豆包会话忙碌检测报告

### 有活跃任务的会话（N个）
| 会话 | 状态 | 详情 |
|---|---|---|
| ... | ... | ... |

### 无活跃任务
其余会话侧边栏无转圈/数字徽章，跳过。

结论：忙碌/空闲。如有关机/重启意图，建议等待/可执行。
```

**不要**逐个检查所有会话；**不要**在无标记的会话上浪费时间。

---

## 二、Mac 关机

**触发词**："MAC关机"、"电脑关机"、"关机"

### 执行步骤

1. 先执行豆包忙碌检测（见上），告知用户当前是否有活跃任务。
2. 如用户确认关机，运行：
   ```bash
   bash /Users/wenjiechen/Doubao/skills/mac-system-toolkit/scripts/power.sh shutdown 30
   ```
3. 脚本输出 `PID=<数字>`，记录该 PID。
4. 告知用户："30秒后执行关机，说'取消'可停止。"
5. 等待期间若用户说"取消"，执行 `kill <PID>` 并确认已取消。
6. 30秒到后 webhook 自动触发关机，无需额外操作。

---

## 三、Mac 重启

**触发词**："MAC重启"、"电脑重启"、"重启"

与关机流程相同，将 `shutdown` 改为 `restart`：

```bash
bash /Users/wenjiechen/Doubao/skills/mac-system-toolkit/scripts/power.sh restart 30
```

---

## 四、取消机制

- 用户在延迟期间说"取消"、"停止"、"别关了"等，立即 `kill <PID>`。
- 验证：`ps -p <PID>` 应返回进程不存在。
- 告知用户已取消。

---

## 五、脚本用法

```bash
POWER_SCRIPT="/Users/wenjiechen/Doubao/skills/mac-system-toolkit/scripts/power.sh"

# 关机（默认30秒延迟）
bash "$POWER_SCRIPT" shutdown

# 关机（自定义延迟秒数）
bash "$POWER_SCRIPT" shutdown 60

# 重启
bash "$POWER_SCRIPT" restart 30

# 取消（用脚本输出的 PID）
kill <PID>
```

脚本输出格式：
```
PID=12345
ACTION=shutdown
DELAY=30s
```

---

## 六、安全注意事项

- **token 即钥匙**：`scripts/power.sh` 含 Cloudflare webhook token，**禁止提交到任何公开 Git 仓库**。
- **关机/重启不可逆**：触发前必须确认无未保存工作，先做豆包忙碌检测。
- **默认延迟 30 秒**：不要改为 0 秒即时执行，给用户取消的机会。
- **webhook 服务依赖**：确保 `com.user.powerwebhook` 和 `com.user.cloudflared-power` 服务在运行。检查：
  ```bash
  launchctl list | grep -E "powerwebhook|cloudflared-power"
  ```
