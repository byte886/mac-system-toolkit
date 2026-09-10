# 窗口管理指南

## 系统环境

- **显示器**：2× 1920×1200（左屏 x=0-1920，右屏 x=1920-3840）
- **Dock**：底部，自动隐藏，tilesize 72，预留 ~90px（底部边界 y=1110）
- **菜单栏**：25px 高（顶部边界 y=25）
- **窗口管理工具**：Spectacle（已安装运行）

## Spectacle 快捷键（已验证）

| 动作 | 快捷键 | 结果 |
|------|--------|------|
| 左半屏 | ⌥⌘← | 左半屏 |
| 右半屏 | ⌥⌘→ | 右半屏 |
| 上半屏 | ⌥⌘↑ | 上半屏 |
| 下半屏 | ⌥⌘↓ | 下半屏 |
| 左上四分之一 | ⌃⌘← | 左上 |
| 右上四分之一 | ⌃⌘→ | 右上 |
| 左下四分之一 | ⌃⇧⌘← | 左下 |
| 右下四分之一 | ⌃⇧⌘→ | 右下 |
| 全屏 | ⌥⌘F | 全屏 |
| 居中 | ⌥⌘C | 居中 |
| 下三分一 | ⌃⌥← | 前三分之一 |
| 下三分二 | ⌃⌥→ | 后三分之一 |
| 下一显示器 | ⌃⌥⌘→ | 移到右屏 |
| 上一显示器 | ⌃⌥⌘← | 移到左屏 |
| 放大 | ⌃⌥⇧→ | 增大窗口 |
| 缩小 | ⌃⌥⇧← | 缩小窗口 |
| 撤销 | ⌥⌘Z | 撤销上次移动 |
| 重做 | ⌥⇧⌘Z | 重做 |

### 通过 shell 触发 Spectacle

```bash
# 键码：123=←, 124=→, 125=↓, 126=↑, 3=F, 8=C, 6=Z

# 前置窗口移到右半屏
osascript -e 'tell application "System Events" to key code 124 using {option down, command down}'

# 前置窗口移到左半屏
osascript -e 'tell application "System Events" to key code 123 using {option down, command down}'

# 全屏
osascript -e 'tell application "System Events" to key code 3 using {option down, command down}'

# 居中
osascript -e 'tell application "System Events" to key code 8 using {option down, command down}'

# 移到下一显示器
osascript -e 'tell application "System Events" to key code 124 using {control down, option down, command down}'
```

### 先激活再排列

总是先激活目标 App，确保快捷键作用于正确窗口：

```bash
osascript -e 'tell application "iTerm2" to activate'
sleep 0.5
osascript -e 'tell application "System Events" to key code 124 using {option down, command down}'
```

## AppleScript 精确布局

需要精确多窗口布局时用 AppleScript `set position/size`。

### 左屏布局模板（x=0-1920, y=25-1110）

| 布局 | App 1 | App 2 | App 3 |
|------|-------|-------|-------|
| 左右 50/50 | {0,25,960,1110} | {960,25,1920,1110} | — |
| 左右 70/30 | {0,25,1344,1110} | {1344,25,1920,1110} | — |
| 上下 | {0,25,1920,567} | {0,567,1920,1110} | — |
| 三格（Chrome+WeChat+iTerm） | {0,25,960,1085} | {960,25,1920,567} | {960,567,1920,1110} |
| 角落（仅 iTerm） | {960,567,1920,1110} | — | — |

### 示例：三格布局

```bash
osascript << 'EOF'
tell application "System Events"
  tell process "Google Chrome"
    set position of front window to {0, 25}
    set size of front window to {960, 1085}
  end tell
  tell process "WeChat"
    set position of front window to {960, 25}
    set size of front window to {960, 542}
  end tell
end tell
tell application "iTerm2"
  tell current window
    set bounds to {960, 567, 1920, 1110}
  end tell
end tell
EOF
```

### iTerm2 专用

```bash
# 设置 iTerm2 窗口 bounds
osascript -e 'tell application "iTerm2" to tell current window to set bounds to {960, 567, 1920, 1110}'
```

## 列出所有窗口

```bash
osascript -e 'tell application "System Events"
  repeat with p in (every application process whose visible is true)
    repeat with w in windows of p
      try
        set {wx,wy} to position of w
        set {ww,wh} to size of w
        log name of p & ": " & wx & "," & wy & " " & ww & "x" & wh
      end try
    end repeat
  end repeat
end tell'
```

## 窗口管理决策流程

1. **检查当前窗口**：列出所有可见窗口和位置
2. **确定目标显示器**：Doubao 在右屏（x>1920），其他 App 用左屏
3. **检查目标屏是否有现有窗口**：特别是 Chrome；如有多个窗口，先问用户如何排列
4. **选择布局**：单 App 最大化或角落；两 App 左右或上下；三 App 三格
5. **预留 Dock 边距**：底部边界 y=1110（不是 1200）
6. **不抢焦点**：排列完后重新激活 Doubao
7. **单屏回退**：只有一个显示器时，分屏或覆盖 Doubao 前先问用户

## 窗口管理原则

1. **窗口可见**：显示窗口时安排好不被遮挡，底部留 ~90px 给 Dock
2. **跨屏排列先问**：目标显示器已有多个窗口（尤其 Chrome）时，先问用户再移动/调整
3. **每 App 一个窗口**：复用现有窗口，不必要不新建

> 全局原则（不抢焦点、观察-行动循环、用户可移动鼠标）见 [SKILL.md](../SKILL.md) 和 [cu-plane-guide.md](cu-plane-guide.md)。
