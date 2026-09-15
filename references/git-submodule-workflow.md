# Git Submodule 多仓库操作规范（技能仓库群）

> 适用对象：`~/Doubao`（远程 `git@github.com:byte886/doubao-workspace.git`）这种**用 submodule 组织一组技能仓库**的工作区。
> 内容来源：git 官方文档 + GitHub Training《Submodule vs Subtree Cheat Sheet》要点沉淀 + 本仓库 2026-09-14 实际拆分经验。跨机器可直接照用。

---

## 0. 一句话心智模型

父仓库（superproject）**不保存子仓库的文件内容**，只保存两样东西：

1. `.gitmodules`：每个子模块的 `path ↔ url` 对照表；
2. 一个 **gitlink 指针**（tree 里 mode 为 `160000` 的特殊条目），记录"该子目录应锁定子仓库的哪个 commit"。

由此推出全部规律：

- 子模块是**独立仓库**，有自己的分支、提交、远程，要单独 commit / push；
- 子模块前进后，父仓库只是"看到指针变了"，需要再 `git add <子目录>` 提交一次指针；
- 所以一次改动 = **子仓库一次提交 + 父仓库一次提交**，推送顺序**先子后父**（否则父仓库指向的 commit 在子仓库远程不存在，别人拉不下来）。

---

## 1. 本仓库实际拓扑

```
~/Doubao                         byte886/doubao-workspace（父仓库, main）
└── skills/
    ├── captcha-reader           ── byte886/captcha-reader
    ├── face-detect              ── byte886/face-detect
    ├── idea-to-tickets          ── byte886/idea-to-tickets
    ├── image-text-redact        ── byte886/image-text-redact
    ├── mac-system-toolkit       ── byte886/mac-system-toolkit   ← 本文件所在仓库
    ├── multiplatform-media-fetch ── byte886/multiplatform-media-fetch
    ├── okf-wiki                 ── byte886/okf-wiki
    ├── photo-organize           ── byte886/photo-organize
    ├── web-research-toolkit     ── byte886/web-research-toolkit
    ├── work-doc-extract         ── byte886/work-doc-extract
    └── wechat-control           ── byte886/wechat-control
        └── third-party/wx-cli   ── byte886/wx-cli   （二级嵌套 submodule）
```

- 全部 **public、默认分支 main、SSH 地址** `git@github.com:byte886/<name>.git`；
- `chats/`、`scys_jewelry/`、`work/` 被父仓库 `.gitignore` 白名单忽略，不属于这套 submodule 体系；
- 标准布局：每个 `skills/<name>/.git` 是**指针文件**（内容 `gitdir: ../../.git/modules/skills/<name>`），真正的 git 元数据统一收在父仓库 `.git/modules/` 下。

---

## 2. 新机器上手（一次性）

### 2.1 前提：GitHub SSH 免密

```bash
ssh -T git@github.com        # 出现 "Hi byte886!" 即 OK
```

### 2.2 克隆（带全部子模块）

```bash
# 全新克隆，一条命令带齐所有层级（含 wechat-control 内嵌 wx-cli）
git clone --recurse-submodules git@github.com:byte886/doubao-workspace.git
```

已经普通 clone、子模块目录是空的，补拉：

```bash
git submodule update --init --recursive
```

### 2.3 配置全局默认项（强烈建议，跨机器复用）

直接跑本技能自带的幂等脚本（可重复执行）：

```bash
bash "$HOME/Doubao/skills/mac-system-toolkit/scripts/setup-git-submodule-global.sh"
```

它设置的 4 条全局配置（来自官方 Cheat Sheet，含义见脚本注释）：

| 配置 | 作用 |
|------|------|
| `diff.submodule=log` | `git diff` 直接显示子模块新增了哪些提交 |
| `status.submoduleSummary=true` | `git status` 给出子模块变化摘要 |
| `push.recurseSubmodules=on-demand` | **在父仓库 push 时自动先推有提交的子模块，免去手动"先子后父"** |
| `submodule.recurse=true` | `pull/fetch/checkout/switch` 默认递归子模块（`clone` 除外，clone 仍要显式 `--recurse-submodules`） |

---

## 3. 日常操作速查

### 3.1 看状态

```bash
git submodule status                 # 看父仓锁定的子模块指针；前缀含义见 §6
git submodule foreach --recursive 'git status -sb'   # 一屏遍历所有层级子仓的分支/脏状态/ahead-behind
```

### 3.2 拉取最新（父 + 子）

```bash
git pull --recurse-submodules                       # Git>=2.14，一步到位
# 等价两步：
git pull && git submodule update --init --recursive
```

### 3.3 修改某个 skill 并发布（标准流程，先子后父）

```bash
# ① 进子模块，正常开发提交推送
cd skills/mac-system-toolkit
# ...改文件...
git switch main                       # 注意：submodule update 后常处于 detached HEAD，先回到分支（见 §6）
git add -A && git commit -m "feat: ..."
git push origin main

# ② 回父仓库，提交"指针变化"并推送
cd ../..
git add skills/mac-system-toolkit
git commit -m "chore: 升级 mac-system-toolkit 子模块指针"
git push origin main                  # 已配 on-demand 时会自动确保子模块先推上去
```

### 3.4 让子模块跟随其远程最新（会改指针）

```bash
git submodule update --remote skills/<name>   # 把子模块切到其远程 main 最新
git add skills/<name> && git commit -m "chore: 更新 <name> 到最新" && git push
```
> 不加路径则对所有子模块生效；生产/稳定场景建议**逐个、显式**升级，不要无脑全量 `--remote`。

### 3.5 批量在所有子模块执行同一命令

```bash
git submodule foreach --recursive 'git fetch --prune'
git submodule foreach --recursive 'git log --oneline -1'
```

### 3.6 看子模块到底改了什么

```bash
git diff skills/<name>                 # 只显示指针变化
git diff --submodule=log skills/<name> # 显示子模块新增提交
git diff --submodule=diff skills/<name># 显示子模块内部文件级 diff
```

---

## 4. 新增一个技能为标准 submodule（保留历史，本仓实操流程）

把一个原本直接跟踪在父仓库里的目录 `skills/<name>` 拆成独立公开仓库、再以标准 submodule 引回：

```bash
set -e
cd ~/Doubao
name=<skill-name>
prefix=skills/$name
url=git@github.com:byte886/$name.git

# 1) 从父仓库历史中抽出该目录的独立历史（内容落到新仓库根），得到 commit SHA
sha=$(git subtree split --prefix=$prefix)

# 2) 建公开空仓并把独立历史推为 main
gh repo create byte886/$name --public
git push "$url" "${sha}:refs/heads/main"

# 3) 解除父仓库对该目录的普通跟踪，本地文件先备份到临时目录
git rm -r --cached "$prefix"
mv "$prefix" "/tmp/$name.bak"

# 4) 以标准 submodule 重新引入（自动生成 gitfile 布局 + 写 .gitmodules + 暂存 gitlink）
git submodule add "$url" "$prefix"

# 5) 校验拆分前后内容完全一致（应无输出）
diff -r "/tmp/$name.bak" "$prefix" --exclude=.git

# 6) 父仓库提交并推送
git commit -m "chore(skills): 将 $name 拆分为独立 Git Submodule"
git push origin main
rm -rf "/tmp/$name.bak"     # 确认无误后清理备份
```

---

## 5. 维护类操作

### 5.1 子模块改名 / 改远程 URL

```bash
# 改 .gitmodules 里对应段的 path/url 后：
git submodule sync --recursive                 # 把新 URL 同步进 .git/config
# 若是"改名"（旧 section 残留），需手动清掉旧注册再重新 init：
git config --remove-section submodule.skills/旧名
git submodule init skills/新名
```

### 5.2 非标准布局收编（子目录里是完整 .git 目录）

标准 submodule 的 `skills/<name>/.git` 应是指针文件。若它是一个完整 `.git` 目录（常见于先手动 clone 再 add）：

```bash
git submodule absorbgitdirs skills/<name>     # 元数据搬进 .git/modules，原处替换为 gitfile
# 嵌套子模块会一并随迁
```

### 5.3 彻底删除一个子模块

```bash
git submodule deinit -f skills/<name>
git rm -f skills/<name>
rm -rf .git/modules/skills/<name>            # 清残留元数据
# 手动从 .gitmodules 删除对应 [submodule] 段（git rm 通常已处理，确认一下）
git commit -m "chore: 移除子模块 <name>"
```

---

## 6. 故障排查

### 6.1 `git submodule status` 前缀

| 前缀 | 含义 | 处理 |
|---|---|---|
| 空格 ` ` | 检出的 commit 与父仓锁定指针一致，正常 | — |
| `-` | 子模块**未初始化/未检出** | `git submodule update --init --recursive`；若 `.git/config` 没注册先 `git submodule init` |
| `+` | 检出 commit 与父仓锁定指针**不一致**（漂移） | 确认子模块改动是否预期；预期则回父仓 `git add` 提交新指针，不预期则 `git submodule update` 回锁 |
| `U` | 合并冲突 | 解决冲突后 `git add` |

### 6.2 常见问题

- **detached HEAD**：`git submodule update` 后子模块默认处于"分离头指针"。**要在子模块里提交，必须先 `git switch main`**，否则提交不在任何分支上、易丢。
- **父仓库总显示某子模块 modified，进去却没改文件**：多为指针没对齐（`+`），或子模块有未跟踪文件/未推送提交；用 `git diff --submodule=log <path>` 看清。
- **改了 `.gitmodules` 的 URL 不生效**：忘了 `git submodule sync --recursive`。
- **二级嵌套（wechat-control/wx-cli）相关命令没作用到它**：命令加 `--recursive` / `--recurse-submodules`。
- **别人 clone 后子模块是空目录**：clone 时没加 `--recurse-submodules`，用 `git submodule update --init --recursive` 补。
- **CI / 新环境先对齐**：`git submodule sync --recursive && git submodule update --init --recursive --force`。

---

## 7. submodule vs subtree（官方 Cheat Sheet 沉淀）

本仓库已选定 **submodule**；subtree 仅作了解，不混用。

| 维度 | Submodule（本仓采用） | Subtree |
|---|---|---|
| 集成方式 | 引用独立仓库，只存 commit 指针 | 把子项目内容直接并入父仓目录 |
| 克隆 | 需 `--recurse-submodules` | 普通 clone 即可 |
| 历史 | 各仓历史独立 | 合并进父仓（常配 `--squash`） |
| 体积 | 父仓保持精简 | 增大父仓体积 |
| 反向提交 | 进子目录提交，两处推送 | `git subtree push --prefix=...` |
| 适用 | 独立发布/复用、各自演进的模块 | 偶尔引入、就地修改的第三方代码 |

官方对照命令（subtree 备查）：

```bash
git subtree add --prefix=dir <url> main --squash
git subtree pull --prefix=dir <url> main --squash
git subtree push --prefix=dir <url> main
```

---

## 8. 多仓库总览工具：gita（已采用）

### 8.1 它解决原生 git 的什么短板

`git submodule status` 只回答"指针对没对齐"，**不显示每个仓当前分支、有没有未提交改动、相对远程 ahead/behind**；想巡检 11 个仓只能逐个 `cd` 进去看。gita（[nosarthur/gita](https://github.com/nosarthur/gita)）就是补上这块的"仪表盘 + 批量遥控器"：一屏列出所有仓库，并对它们批量执行 git 命令。它**不替代 submodule**，而是建在其上的便捷外壳。

### 8.2 安装

统一用 **Homebrew 全局安装**（两台 Intel 黑苹果实测，2026-09-15），命令落到 `/usr/local/bin/gita`（Apple Silicon 为 `/opt/homebrew/bin/gita`），由 brew 统一升级/卸载，**不要再用手工 venv + 软链**。

gita 是纯 Python 小包，homebrew-core 提供 Intel bottle（约 626KB），运行时直接复用 brew 的 python@3.14。**关键加 `--ignore-dependencies`**：不加时 brew 会顺带把 python@3.14 的链式依赖（openssl/xz/sqlite）当过期项升级，而这些在 Intel 黑苹果上常无匹配 bottle、回退源码编译（很慢、易失败）；依赖本就齐备，无需重装。

```bash
# 交互终端：30-brew.zsh 已配中科大镜像，直接：
brew install --ignore-dependencies gita
gita --version            # 期望 gita 0.16.8.2+
which gita                # Intel -> /usr/local/bin/gita
```

非交互 shell（ssh、AI 自动化）不加载 30-brew.zsh，必须显式带上国内镜像，否则 bottle 走 ghcr.io 国外会龟速：

```bash
export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
export HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_AUTO_UPDATE=1
brew install --ignore-dependencies gita
```

维护：`brew upgrade gita` / `brew uninstall gita`。纳管清单存 `~/.config/gita/repos.csv`（**机器相关、不入库**；换机要么重新登记，要么拷贝后把里面的家目录名整体替换 wenjiechen↔chenwenjie）。

> 已废弃旧装法 `python3 -m venv ~/.local/venvs/gita` + 软链到 `~/.local/bin`：不是全局、要自己维护、还会因 PATH 顺序与 `/usr/local/bin` 打架。两台机器已于 2026-09-15 统一为 brew 全局并删除旧 venv。

### 8.3 登记仓库群（一次）

```bash
gita add -r ~/Doubao        # 递归登记：根仓 + skills 全部子模块 + 嵌套仓(wx-cli) + chats 下独立仓
gita ls                     # 列出已登记仓库名
```

- 递归 `-r` 幂等：已登记的不重复，新增 git 仓下次再跑会补上；它会把 `chats/` 下业务仓也纳入（如 gaodun 只在 .9 上，故 .9 纳管 14 个、本机 13 个，属正常差异）。
- 想精确控制就逐个显式 `gita add <repo路径>`（只登记真实存在的 git 仓，不存在的路径会报错、跳过即可）。

> 新机器跑 `scripts/setup-git-submodule-global.sh` 时，若检测到已装 gita 会自动执行递归登记。

### 8.4 日常命令

| 命令 | 作用 |
|------|------|
| `gita ll` | **总览**：每仓一行——名称 / 分支 / 状态符 / 最近提交 |
| `gita ls` | 只列已登记仓库名 |
| `gita st` | 对所有仓批量 `git status` |
| `gita fetch` / `gita pull` / `gita push` | 对所有仓批量执行；后接仓库名可只针对部分：`gita pull okf-wiki` |
| `gita br` | 批量查看各仓分支 |
| `gita log` / `gita last` | 批量查看提交 |
| `gita shell` | 进入对所有仓执行任意 git 命令的交互 |
| `gita rm <name>` | 取消登记（只移除 gita 记录，不删磁盘文件） |

### 8.5 `gita ll` 状态符含义

| 符号 | 含义 |
|---|---|
| `[]` | 工作区干净、与远程同步 |
| `*` | 有未提交修改 |
| `?` | 有未跟踪文件 |
| `>` / `<` / `=` | 领先远程 / 落后远程 / 已分叉 |
| `$` | 有 stash |

### 8.6 怎么读结果（状态巡检）

`gita ll` 每仓一行：技能子模块多处于 detached HEAD、无远程跟踪时显示 `∅`；在分支上且干净同步显示 `[]`；正在改的仓出现 `[*?]`（修改+未跟踪），根仓因子模块在改也会变 `[*]`。不用逐个 `cd` 进目录即可完成全仓巡检，状态符含义见 §8.5。

### 8.7 与原生 submodule 命令的分工

- **克隆、增删子模块、指针升级、改名/删除、故障排查** → 用本文件 §2–§5 的**原生 `git submodule`**（这些 gita 不管）；
- **一屏总览状态、批量 fetch/pull、跨仓巡检** → 用 **gita**。

---

## 9. 参考来源

- git 官方手册 `git-submodule`：<https://git-scm.com/docs/git-submodule>
- gitsubmodules 概念文档：<https://git-scm.com/docs/gitsubmodules>
- GitHub Training《Submodule vs Subtree Cheat Sheet》：<https://training.github.com/downloads/submodule-vs-subtree-cheat-sheet/>
- gita（可选多仓工具）：<https://github.com/nosarthur/gita>
- 整理日期：2026-09-14；以本机 git 2.55 实测为准。
