# 第四层：文件搜索

> 高速文件搜索，按场景选择工具，不要用一个工具暴力搜索所有场景。

---

## 一、工具矩阵

| 工具 | 速度 | 索引 | 范围 | 最佳用途 |
|------|------|------|------|---------|
| **mdfind** | ~0.1s | ✅ Spotlight 索引 | 全盘（含隐藏/系统文件） | 系统级文件名/内容搜索，即时 |
| **fd** | ~0.05s | ❌ 实时扫描 | 指定目录树 | 已知目录下的文件名搜索，默认尊重 .gitignore |
| **rg** | ~0.1s | ❌ 实时扫描 | 指定目录树 | **内容**搜索（在文件内部 grep） |
| **ncdu** | 交互式 | ❌ 实时扫描 | 指定目录 | 磁盘空间分析，找空间占用大户 |

**核心规则**：
- 文件可能在全盘任何位置 → `mdfind`（有索引，即时）
- 知道目录位置 → `fd`（文件名）或 `rg`（内容）
- `ncdu` 只用于磁盘空间分析，不用于找文件

---

## 二、按文件名搜索 — 系统级（mdfind）

```bash
# 按名称片段（不区分大小写，子串匹配）
mdfind -name "quarterly_report"

# 按名称通配符
mdfind "kMDItemFSName == '*budget*.xlsx'c"

# 只搜文件（排除文件夹）
mdfind -onlyin "$HOME" -name "contract" | grep -v '/$'

# 按精确扩展名，全盘搜索
mdfind -name ".mov" | grep -iE '\.mov$' | head -20

# 在指定位置搜索
mdfind -onlyin "/Users/wenjiechen/Documents" -name "report"
```

**注意**：`mdfind -name` 是子串匹配。如果 Spotlight 索引过期，`mdutil -E /` 重建索引（需要几分钟，仅在结果明显错误时执行）。

---

## 三、按文件名搜索 — 已知目录（fd）

```bash
# 当前目录下文件名包含 "report"（尊重 .gitignore）
fd "report"

# 包含隐藏文件，不过滤 gitignore
fd -H "report" /path/to/dir

# 按扩展名
fd -e pdf /Users/wenjiechen/Documents

# 文件名正则匹配
fd -H "\.(mov|mp4)$" /Users/Shared/Aerial

# 不区分大小写
fd -i "aerial"

# 只列出匹配的目录
fd -t d "project"

# 只列出匹配的文件
fd -t f "backup"
```

---

## 四、按内容搜索（rg）

```bash
# 在目录下的文件中搜索文本
rg "API_KEY" /path/to/project

# 忽略大小写
rg -i "error" ~/Documents

# 只显示文件名（不显示匹配行）
rg -l "TODO" /path/to/project

# 显示行号和上下文
rg -n -C 2 "bug" /path/to/code

# 搜索隐藏文件 + 忽略 .gitignore
rg -uuu "secret" /path

# 按文件类型过滤
rg -t py "def main" /path/to/python

# 每个文件的匹配计数
rg -c "error" /var/log
```

---

## 五、磁盘空间分析（ncdu）

```bash
# 交互式分析目录（方向键导航，d 删除，q 退出）
ncdu /Users/wenjiechen

# 非交互式：只显示最大的目录
ncdu -o - /Users/wenjiechen | head -30
# 或用 du 快速取 Top N
du -sh /Users/wenjiechen/* 2>/dev/null | sort -rh | head -20

# 带深度限制分析（大目录更快）
ncdu -d 2 /Users/wenjiechen
```

---

## 六、决策流程

```
需要找文件？
│
├─ 大概知道在哪？
│   ├─ 知道 → fd <名称> <目录>    （文件名）
│   │        rg <文本> <目录>    （内容）
│   └─ 不知道 → mdfind -name "<名称>"  （系统级，有索引）
│
├─ 想知道空间被什么占了（不是找文件）？
│   └─ ncdu <目录>                 （磁盘空间分析）
│
├─ 搜索没结果但文件确实存在？
│   └─ 1) 检查工具是否搜了正确范围
│      2) mdfind 索引过期 → mdutil -E /（重建，几分钟）
│      3) fd 搜隐藏文件 → 加 -H 参数
│      4) rg 搜二进制文件 → 加 -a 参数
```

---

## 七、最佳实践

1. **位置不确定时先用 mdfind** — 有索引，即时，不需要猜目录
2. **fd 加 -H** 当需要搜隐藏文件时（如 dotfiles、.config）
3. **rg -uuu** 绕过 .gitignore；谨慎使用（node_modules 等会淹没结果）
4. **特殊字符加引号**：`fd "\.(mov|mp4)$"` 而不是 `fd \.(mov|mp4)$`
5. **中文文件名** fd/rg/mdfind 都支持，无需特殊处理
6. **尊重范围**：不要对整个 home 目录跑 `rg`（慢），先缩小到项目目录

---

## 八、常用命令速查

```bash
# 全盘找所有大视频文件
mdfind "kMDItemFSName == '*.mov'" | xargs ls -lS 2>/dev/null | head -20

# 最快方式找项目
mdfind -name "game-project"

# ~/Documents 中哪个文件包含 "oclp"
rg -li "oclp" ~/Documents

# home 目录 Top 10 空间占用
du -sh ~/Documents/* ~/Downloads/* ~/Desktop/* 2>/dev/null | sort -rh | head -10

# 找最近 7 天修改的 xlsx 文件
mdfind "kMDItemFSName == '*.xlsx' && kMDItemFSContentChangeDate >= \$time.today(-7)" | head -20
```

---

## 九、依赖安装

```bash
# mdfind 系统自带，无需安装

# fd / ripgrep / ncdu
brew install fd ripgrep ncdu

# 验证
fd --version
rg --version
ncdu --version
```
