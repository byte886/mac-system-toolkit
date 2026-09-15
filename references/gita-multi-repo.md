# gita：多仓库总览与批量遥控（建在 submodule 之上的仪表盘）

> 与原生 submodule 命令的分工：**克隆、增删子模块、指针升级、改名/删除、故障排查**用 [git-submodule-workflow.md](git-submodule-workflow.md) 的原生 `git submodule`；**一屏总览状态、跨目录批量 fetch/pull/super、按组巡检**用 gita。gita 不替代 submodule，而是建在其上的便捷外壳。

---

## 一、它解决原生 git 的什么短板

`git submodule status` 只回答"指针对没对齐"，**不显示每个仓当前分支、有没有未提交改动、相对远程 ahead/behind**；想一次巡检十几个仓只能逐个 `cd` 进去看。gita（[nosarthur/gita](https://github.com/nosarthur/gita)）就是补上这块的"仪表盘 + 批量遥控器"：一屏列出所有仓库，并对它们批量执行 git 命令。

---

## 二、安装

统一用 **Homebrew 全局安装**（两台 Intel 黑苹果实测，2026-09-15），命令落到 `/usr/local/bin/gita`（Apple Silicon 为 `/opt/homebrew/bin/gita`），由 brew 统一升级/卸载，**不要再用手工 venv + 软链**。

gita 是纯 Python 小包，homebrew-core 提供 Intel bottle（约 626KB），运行时直接复用 brew 的 python。**关键加 `--ignore-dependencies`**：不加时 brew 会顺带把 python 的链式依赖（openssl/xz/sqlite）当过期项升级，而这些在 Intel 黑苹果上常无匹配 bottle、回退源码编译（很慢、易失败）；依赖本就齐备，无需重装。

```bash
# 交互终端（已配国内 brew 镜像）：
brew install --ignore-dependencies gita
gita --version            # 期望 gita 0.16.8.2+
which gita                # Intel -> /usr/local/bin/gita
```

非交互 shell（ssh、AI 自动化）不加载 brew 镜像配置，必须显式带上国内镜像，否则 bottle 走国外源会龟速：

```bash
export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
export HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_AUTO_UPDATE=1
brew install --ignore-dependencies gita
```

维护：`brew upgrade gita` / `brew uninstall gita`。纳管清单存 `~/.config/gita/repos.csv`（**机器相关、不入库**；换机要么重新登记，要么拷贝后把里面的家目录用户名整体替换）。

---

## 三、登记仓库群（一次）

```bash
gita add -r ~/Doubao        # 递归登记：根仓 + skills 全部子模块 + 嵌套仓 + chats 下独立仓
gita ls                     # 列出已登记仓库名
```

- 递归 `-r` 幂等：已登记的不重复，新增 git 仓下次再跑会补上。纳管数随各机业务仓而变，以 `gita ls` 现场实测为准，两机数量不同属正常差异。
- 想精确控制就逐个显式 `gita add <repo路径>`（只登记真实存在的 git 仓，不存在的路径会报错、跳过即可）。

> 新机器跑 `scripts/setup-git-submodule-global.sh` 时，若检测到已装 gita 会自动执行递归登记。

---

## 四、日常命令（均可从任意目录发起，不用逐个 cd）

### 总览 / 登记

| 命令 | 作用 |
|------|------|
| `gita ll` | **一屏总览**：名称 / 分支 / 状态符 / 最近提交 |
| `gita ls` | 只列已登记仓库名；`gita ls <name>` 可看某仓绝对路径 |
| `gita rm <name>` | 取消登记（只移除 gita 记录，**不删磁盘文件**） |
| `gita rename <旧名> <新名>` | 改登记名 |
| `gita freeze` | 导出全部仓的 CSV（remote/name/path…），用于备份或换机对照（见 §七） |

### 批量 git（核心）

| 命令 | 作用 |
|------|------|
| `gita fetch` / `pull` / `push` [仓名…] | 不给仓名=全部；给仓名/组名=只针对它们，如 `gita pull okf-wiki` |
| `gita st` / `br` / `last` / `lo` | 批量 `status` / 本地分支 / HEAD 提交 / 最近 7 条一行 log |
| `gita super [仓名…] <git 命令>` | **代发任意 git 命令或别名**，如 `gita super mac-system-toolkit log --oneline -3` |
| `gita shell [仓名…] <shell 命令>` | 代发任意 **shell** 命令（super 跑 git，shell 跑非 git 的 shell 命令；都不是"进入交互"） |

### 圈定操作范围（仓多时用，避免误操作到无关仓）

```bash
gita group add -n skills captcha-reader face-detect mac-system-toolkit ...  # 建组并纳仓
gita group ll            # 看有哪些组；group rmrepo / group rm 移除
gita context auto        # 按当前所在目录，自动把批量操作限定到对应组
gita context skills      # 手动选定某个组；gita context none 取消限定
```

设了 context 后，上面所有批量命令只作用于该组。

> ⚠️ `gita clean` 会批量删除未跟踪文件（等价 `git clean`，不可恢复）；用前先 `gita st` 看清，不要对全仓直接跑。

---

## 五、`gita ll` 状态符含义

| 符号 | 含义 |
|---|---|
| `[]` | 工作区干净、与远程同步 |
| `∅` | 本地没有远程跟踪分支（`submodule update` 后的 detached HEAD 子模块最常见，**不是报错**） |
| `*` / `+` | 有未提交修改 / 有已暂存(staged)改动 |
| `?` | 有未跟踪文件 |
| `>` / `<` / `=` | 领先远程 / 落后远程 / 已分叉 |
| `$` | 有 stash |

### 怎么读结果（状态巡检）

`gita ll` 每仓一行：技能子模块多处于 detached HEAD、无远程跟踪时显示 `∅`；在分支上且干净同步显示 `[]`；正在改的仓出现 `[*?]`（修改+未跟踪），根仓因子模块在改也会变 `[*]`。不用逐个 `cd` 进目录即可完成全仓巡检。

---

## 六、与原生 submodule 命令的分工

- **克隆、增删子模块、指针升级、改名/删除、故障排查** → 用 [git-submodule-workflow.md](git-submodule-workflow.md) §2–§5 的**原生 `git submodule`**（这些 gita 不管）；
- **一屏总览状态、跨目录批量 fetch/pull/super、按组巡检** → 用 **gita**；
- 两条批量通道的边界：`gita super` 按**登记名/组**选仓、依赖 gita 已登记；`git submodule foreach --recursive` 严格按 **submodule 层级**递归（含二级嵌套）、不依赖 gita，适合结构性操作或新机尚未装 gita 时。

---

## 七、换机 / 双机对齐纳管清单

纳管清单是机器相关文件 `~/.config/gita/repos.csv`（含绝对路径，**不入库**）。双机家目录用户名不同，不要直接拷贝覆盖：

```bash
gita add -r ~/Doubao        # 新机优先递归重登（幂等，自动用本机绝对路径）
gita freeze                 # 源机导出 remote/name/path 的 CSV，用于对照
```

只在某台机存在的业务仓，另一台自然不会被登记，属正常差异。

---

## 参考来源

- gita：<https://github.com/nosarthur/gita>
- 安装与用法以 2026-09-15 双机（Intel、gita 0.16.8.2、Homebrew 7.0.1）实测为准。
