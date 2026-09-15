# 代理客户端菜单栏控制 / 系统 VPN / 故障排查

> 环境检测与终端代理设置见 [vpn-control.md](vpn-control.md)。本篇管"用 axcli 操作菜单栏代理客户端、系统级 VPN、出问题怎么排"。

---

## 一、代理客户端菜单栏控制（以 ClashX Pro 为例，ClashVerge 同理）

> 本节以 **ClashX Pro** 为例；若本机是 **ClashVerge**，菜单项名称与布局不同，但"菜单栏-only、用 axcli 点图标、坐标动态发现"的方法一致，端口仍以 `$PROXY_PORT` 实测为准（端口探测见 vpn-control.md）。

- **ClashX Pro Bundle ID**：`com.west2online.ClashXPro`（ClashVerge 用 `ls /Applications | grep -i clash` 另查）
- **代理端口**：HTTP/SOCKS5 同口（混合端口），不固定，用 vpn-control.md 第二节探测
- **菜单栏图标位置**：动态变化，需重新发现

### 菜单栏交互（axcli）

ClashX 是菜单栏-only App，cu plane 可能看不到（`CU_AX_APP_NOT_SURFACE`），用 axcli 全局坐标点击。

```bash
AXCLI=~/.cargo/bin/axcli
$AXCLI mouse click <x> <y>            # 点击菜单栏图标（坐标需动态发现）
sleep 1
$AXCLI --app "ClashX Pro" snapshot --depth 10   # 读取菜单项
$AXCLI --app "ClashX Pro" press "Escape"        # 关闭菜单
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

菜单中可读取：出站模式（全局/规则/脚本/直连）、当前代理节点（如 "🇭🇰 香港 01"）、各规则组当前节点（Proxy/Domestic/Others/Netflix/YouTube 等）。

```bash
$AXCLI mouse click <x> <y> && sleep 1
$AXCLI --app "ClashX Pro" snapshot --depth 5 2>&1 | grep -E "出站模式|Proxy|Domestic"
$AXCLI --app "ClashX Pro" press "Escape"
```

### 切换出站模式

点击菜单栏 → 出站模式 → 选择：规则判断（推荐，国内直连国外代理）/ 全局连接（所有流量走代理）/ 直接连接（全部直连）。

### 延迟测试与节点选择

1. 点击菜单栏图标
2. 点击目标规则组（如 Proxy）的"前进"箭头
3. 在节点列表中点击"延迟测试"，等待结果
4. 选延迟最低的节点点击，按 Escape 关闭菜单

### 增强模式（TUN）

ClashX Pro 的"增强模式"（TUN）让所有应用流量走代理，无需单独配终端代理。开启后所有应用（含终端）自动走代理；关闭后只有配置了代理的应用才走。首次开启可能提示安装辅助工具、需管理员权限。

---

## 二、系统 VPN 配置

```bash
# 查看
networksetup -listallnetworkservices          # 列出所有网络服务
scutil --nc list                              # VPN 连接状态
scutil --nc status "VPN名称"                  # 特定 VPN 状态

# 连接/断开
scutil --nc start "VPN名称"
scutil --nc stop "VPN名称"

# Wi-Fi 代理设置
networksetup -getwebproxy Wi-Fi
networksetup -getsecurewebproxy Wi-Fi
networksetup -getsocksfirewallproxy Wi-Fi
```

---

## 三、常见问题排查

### 1. 代理端口不通

```bash
ps aux | grep -iE 'clash|mihomo|verge' | grep -v grep   # 客户端是否在运行
lsof -i :${PROXY_PORT:-7890}                            # 端口是否监听
open -a "ClashX Pro"      # 没运行则启动（ClashVerge 机改为：open -a "ClashVerge"）
```

### 2. 代理连接但速度慢

```bash
# 测试当前代理速度
curl -s --connect-timeout 5 -x http://127.0.0.1:${PROXY_PORT:-7890} -o /dev/null \
  -w "速度: %{speed_download} bytes/s, 时间: %{time_total}s\n" \
  https://speed.cloudflare.com/__down?bytes=10000000 2>&1
# 慢则在 ClashX 菜单对目标规则组做延迟测试，选最快节点
```

### 3. 终端 DNS 解析超时

症状 `Could not resolve host` 或超时；原因终端 DNS 直连超时。解决：

```bash
export https_proxy=http://127.0.0.1:${PROXY_PORT:-7890} http_proxy=http://127.0.0.1:${PROXY_PORT:-7890}
# 或开启 ClashX 增强模式（TUN），所有流量自动走代理
```

### 4. Homebrew 下载慢/超时

```bash
# 解决1：带代理安装
export https_proxy=http://127.0.0.1:${PROXY_PORT:-7890} http_proxy=http://127.0.0.1:${PROXY_PORT:-7890}
brew install package
# 解决2：国内镜像
export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles
export HOMEBREW_API_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles/api
# 解决3：brew 卡住 "Waiting for another Homebrew process"
pkill -9 -f brew
rm -f ~/Library/Caches/Homebrew/downloads/*.incomplete
```

### 5. cargo / npm 安装慢

```bash
# cargo：已配中科大镜像，仍慢就带代理
export https_proxy=http://127.0.0.1:${PROXY_PORT:-7890}; cargo build
# npm：切淘宝镜像或带代理
npm config set registry https://registry.npmmirror.com
export https_proxy=http://127.0.0.1:${PROXY_PORT:-7890}; npm install
```

---

## 四、快速命令函数

```bash
# 一键检测并决定是否需要代理
check_proxy() {
  local direct=$(curl -s --connect-timeout 3 -o /dev/null -w "%{http_code}" https://www.google.com 2>&1)
  if [ "$direct" = "200" ] || [ "$direct" = "301" ] || [ "$direct" = "302" ]; then
    echo "直连可用，不需要代理"
  else
    echo "直连不可用，设置代理"
    export https_proxy=http://127.0.0.1:${PROXY_PORT:-7890} http_proxy=http://127.0.0.1:${PROXY_PORT:-7890} all_proxy=socks5://127.0.0.1:${PROXY_PORT:-7890}
  fi
}

# 测试代理速度（5MB）
test_proxy_speed() {
  curl -s --connect-timeout 5 -x http://127.0.0.1:${PROXY_PORT:-7890} -o /dev/null \
    -w "下载速度: %{speed_download} B/s, 总时间: %{time_total}s\n" \
    https://speed.cloudflare.com/__down?bytes=5000000 2>&1
}
```
