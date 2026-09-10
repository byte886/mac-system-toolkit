# 第四层：VPN / 代理控制

> 网络环境检测与代理管理。执行需要网络访问的操作前，先检测网络环境，根据目标资源决定是否需要代理。

---

## 一、核心原则

1. **先检测后决策**：不要默认开代理，也不要默认直连。先测试目标域名的连通性和速度，再决定。
2. **国内资源直连**：百度、必应国内版、国内镜像源等不需要代理。
3. **国外资源走代理**：Google、GitHub、Homebrew（bottles下载）、cargo crates.io、npm registry、Docker Hub、PyPI 等。
4. **终端代理按需设置**：只在需要的命令前设置代理环境变量，不全局持久化（除非用户要求）。
5. **操作 ClashX 前先确认状态**：通过菜单栏菜单读取当前代理状态和节点。

---

## 二、网络环境检测

### 快速检测（3秒内出结果）

```bash
# 检测直连 Google（判断是否需要代理）
curl -s --connect-timeout 3 -o /dev/null -w "直连Google: code=%{http_code} time=%{time_total}s\n" https://www.google.com 2>&1

# 检测代理是否可用（ClashX 默认端口 7890）
curl -s --connect-timeout 3 -x http://127.0.0.1:7890 -o /dev/null -w "代理Google: code=%{http_code} time=%{time_total}s\n" https://www.google.com 2>&1
```

### 完整检测（含国内/国外对比）

```bash
echo "=== 国内资源（直连）==="
curl -s --connect-timeout 3 -o /dev/null -w "百度: code=%{http_code} time=%{time_total}s\n" https://www.baidu.com 2>&1

echo "=== 国外资源（直连）==="
curl -s --connect-timeout 5 -o /dev/null -w "GitHub直连: code=%{http_code} time=%{time_total}s\n" https://github.com 2>&1
curl -s --connect-timeout 5 -o /dev/null -w "Google直连: code=%{http_code} time=%{time_total}s\n" https://www.google.com 2>&1

echo "=== 国外资源（代理）==="
curl -s --connect-timeout 5 -x http://127.0.0.1:7890 -o /dev/null -w "GitHub代理: code=%{http_code} time=%{time_total}s\n" https://github.com 2>&1
curl -s --connect-timeout 5 -x http://127.0.0.1:7890 -o /dev/null -w "Google代理: code=%{http_code} time=%{time_total}s\n" https://www.google.com 2>&1
```

### 决策逻辑

| 检测结果 | 决策 |
|---------|------|
| 直连国外资源 code=200 且 time<2s | 直连可用，不需要代理 |
| 直连国外资源超时或 code=000 | 需要代理 |
| 代理可用但直连也可用 | 优先直连（更快、更稳定），大文件下载用代理 |
| 代理不可用 | 检查 ClashX 是否运行、端口是否正确、节点是否有效 |

---

## 三、终端代理设置

### 临时设置（推荐，只影响当前命令）

```bash
# 方式1：命令前缀
https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 brew install tree

# 方式2：export 后执行（当前 shell 会话有效）
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
brew install tree
npm install
cargo build

# 取消代理
unset https_proxy http_proxy all_proxy
```

### 常用工具的代理配置

```bash
# git
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890
# 取消
git config --global --unset http.proxy
git config --global --unset https.proxy

# npm
npm config set proxy http://127.0.0.1:7890
npm config set https-proxy http://127.0.0.1:7890

# cargo（已配置中科大镜像，通常不需要代理）
# 但访问 crates.io 索引时可能需要
# 在 ~/.cargo/config.toml 中设置
# [http]
# proxy = "http://127.0.0.1:7890"

# pip
pip install --proxy http://127.0.0.1:7890 package

# docker
# ~/.docker/config.json 中设置 proxies
```

---

## 四、ClashX Pro 控制

### 基本信息

- **Bundle ID**：`com.west2online.ClashXPro`
- **代理端口**：HTTP `127.0.0.1:7890`，SOCKS5 `127.0.0.1:7890`
- **菜单栏图标位置**：动态变化，需重新发现

### 菜单栏交互（axcli）

ClashX 是菜单栏-only App，cu plane 可能看不到（`CU_AX_APP_NOT_SURFACE`），用 axcli 全局坐标点击。

```bash
AXCLI=~/.cargo/bin/axcli

# 点击菜单栏图标（坐标需动态发现）
$AXCLI mouse click <x> <y>
sleep 1

# 读取菜单项
$AXCLI --app "ClashX Pro" snapshot --depth 10

# 关闭菜单
$AXCLI --app "ClashX Pro" press "Escape"
```

### 动态发现图标位置

```bash
AXCLI=~/.cargo/bin/axcli
for i in 0 1 2 3 4 5; do
  echo "nth=$i: $($AXCLI --app 'ClashX Pro' get title "AXMenuBarItem >> nth=$i" 2>&1)"
  $AXCLI --app 'ClashX Pro' get position "AXMenuBarItem >> nth=$i" 2>&1
done
```

### 读取当前状态

菜单中可读取的信息：
- 出站模式（全局连接/规则判断/脚本模式/直接连接）
- 当前代理节点（如 "🇭🇰 香港 01"）
- 各规则组的当前节点（Proxy/Domestic/Others/Netflix/YouTube 等）

```bash
AXCLI=~/.cargo/bin/axcli
$AXCLI mouse click <x> <y>
sleep 1
$AXCLI --app "ClashX Pro" snapshot --depth 5 2>&1 | grep -E "出站模式|Proxy|Domestic"
$AXCLI --app "ClashX Pro" press "Escape"
```

### 切换出站模式

```bash
# 点击菜单栏 → 出站模式 → 选择模式
# 规则判断（推荐，国内直连国外代理）
# 全局连接（所有流量走代理）
# 直接连接（所有流量直连）
```

### 延迟测试与节点选择

ClashX Pro 菜单中每个代理组右侧有"前进"箭头，点击后可看到节点列表和延迟测试按钮。

操作流程：
1. 点击菜单栏图标
2. 点击目标规则组（如 Proxy）的"前进"箭头
3. 在节点列表中点击"延迟测试"
4. 等待延迟结果显示
5. 选择延迟最低的节点点击
6. 按 Escape 关闭菜单

### 增强模式（TUN）

ClashX Pro 的"增强模式"（TUN 模式）可以让所有应用流量走代理，不需要单独配置终端代理。

- 开启后：所有应用（包括终端）自动走代理，不需要设置环境变量
- 关闭后：只有配置了代理的应用才走代理
- 注意：增强模式可能需要管理员权限，首次开启会提示安装辅助工具

---

## 五、系统 VPN 配置

### 查看 VPN 状态

```bash
# 列出所有网络服务
networksetup -listallnetworkservices

# 查看 VPN 连接状态
scutil --nc list

# 查看特定 VPN 状态（替换 VPN 名称）
scutil --nc status "VPN名称"
```

### 连接/断开 VPN

```bash
# 连接 VPN
scutil --nc start "VPN名称"

# 断开 VPN
scutil --nc stop "VPN名称"
```

### 查看当前网络代理设置

```bash
# Wi-Fi 代理设置
networksetup -getwebproxy Wi-Fi
networksetup -getsecurewebproxy Wi-Fi
networksetup -getsocksfirewallproxy Wi-Fi
```

---

## 六、何时需要 VPN/代理的判断清单

执行以下操作前，先检测网络：

| 操作 | 默认需要代理？ | 国内替代 |
|------|--------------|---------|
| Google 搜索 | 是 | 百度/必应国内版 |
| GitHub 访问/克隆 | 通常是 | Gitee 镜像（部分项目） |
| Homebrew 安装 | 下载bottles时是 | 中科大/清华镜像 |
| cargo 依赖 | 索引下载时是 | 中科大镜像（已配置） |
| npm 安装 | 官方源时是 | npmmirror 淘宝镜像 |
| pip 安装 | 官方源时是 | 清华/阿里镜像 |
| Docker 拉取 | 是 | 国内镜像加速器 |
| 国内网站访问 | 否 | — |
| 飞书/微信 API | 否 | — |
| Apple 服务 | 通常否 | — |

---

## 七、常见问题排查

### 1. 代理端口不通

```bash
# 检查 ClashX 是否运行
ps aux | grep -i clash | grep -v grep

# 检查端口是否监听
lsof -i :7890

# 如果 ClashX 没运行，启动它
open -a "ClashX Pro"
```

### 2. 代理连接但速度慢

```bash
# 测试各节点延迟，选择最快的
# 在 ClashX 菜单中对目标规则组做延迟测试

# 测试当前代理速度
curl -s --connect-timeout 5 -x http://127.0.0.1:7890 -o /dev/null -w "速度: %{speed_download} bytes/s, 时间: %{time_total}s\n" https://speed.cloudflare.com/__down?bytes=10000000 2>&1
```

### 3. 终端 DNS 解析超时

```bash
# 症状：curl 报 "Could not resolve host" 或超时
# 原因：终端 DNS 直连超时，需要走代理
# 解决：设置代理环境变量
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890

# 或开启 ClashX 增强模式（TUN），所有流量自动走代理
```

### 4. Homebrew 下载慢/超时

```bash
# Homebrew 的 bottles 下载走 GitHub Releases，国内直连慢
# 解决1：带代理安装
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890
brew install package

# 解决2：使用国内镜像（中科大/清华）
export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles
export HOMEBREW_API_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles/api

# 解决3：brew 卡住 "Waiting for another Homebrew process"
pkill -9 -f brew
rm -f ~/Library/Caches/Homebrew/downloads/*.incomplete
```

### 5. cargo 安装依赖超时

```bash
# crates.io 索引下载慢
# 已配置中科大镜像（~/.cargo/config.toml），但仍可能需要代理
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890
cargo build
```

### 6. npm 安装慢

```bash
# 检查当前 registry
npm config get registry

# 切换国内镜像（淘宝）
npm config set registry https://registry.npmmirror.com

# 或带代理安装
export https_proxy=http://127.0.0.1:7890
npm install
```

---

## 八、快速命令参考

```bash
# 一键检测并决定是否需要代理
check_proxy() {
  local direct=$(curl -s --connect-timeout 3 -o /dev/null -w "%{http_code}" https://www.google.com 2>&1)
  if [ "$direct" = "200" ] || [ "$direct" = "301" ] || [ "$direct" = "302" ]; then
    echo "直连可用，不需要代理"
  else
    echo "直连不可用，设置代理"
    export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
  fi
}

# 测试代理速度
test_proxy_speed() {
  curl -s --connect-timeout 5 -x http://127.0.0.1:7890 -o /dev/null \
    -w "下载速度: %{speed_download} B/s, 总时间: %{time_total}s\n" \
    https://speed.cloudflare.com/__down?bytes=5000000 2>&1
}

# 读取 ClashX 当前节点
get_clash_status() {
  ~/.cargo/bin/axcli mouse click <x> <y>
  sleep 1
  ~/.cargo/bin/axcli --app "ClashX Pro" snapshot --depth 5 2>&1 | grep -E "出站模式|Proxy|Domestic"
  ~/.cargo/bin/axcli --app "ClashX Pro" press "Escape"
}
```

---

## 九、系统环境

- **ClashX Pro 代理端口**：HTTP `127.0.0.1:7890`，SOCKS5 `127.0.0.1:7890`
- **ClashX Pro bundle ID**：`com.west2online.ClashXPro`
- **axcli 路径**：`~/.cargo/bin/axcli`
- **cargo 镜像**：已配置中科大源（`~/.cargo/config.toml`）
- **终端 DNS**：直连经常超时，建议走代理
