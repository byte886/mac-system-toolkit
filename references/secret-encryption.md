# 凭证 / 密码统一加密约定

> 这是**全机唯一**的敏感凭证落盘约定：凡是需要保存到磁盘的密码、token、API key、secret（sudo 密码、GitHub PAT、Cloudflare webhook、Playwright token、各平台 API 凭证等），一律按本约定加密，**明文绝不进 git、不写进脚本**。
>
> **工具全局唯一一份**：命令 `secrets`（权威源 [`scripts/secrets.sh`](../scripts/secrets.sh)，随本技能 git 版本化，软链到 `~/.local/bin/secrets`）。**任何项目都不要再各自保存 secrets.sh 副本**，项目里只保留自己的 `.secrets/*.enc` 密文。算法与历史项目（高顿 `scripts/secrets.sh`，已抽离）完全一致，旧密文可直接被全局命令解密。

---

## 1. 固定算法（不要改）

```bash
openssl enc -aes-256-cbc -salt -pbkdf2 -base64      # 加密
openssl enc -aes-256-cbc -d -salt -pbkdf2 -base64   # 解密
```

**AES-256-CBC** + **PBKDF2** 派生密钥 + 随机 **salt** + **base64 文本**输出。统一参数是为了让不同机器、不同项目、新旧 `.enc` 互相可解；不要换算法或去掉 pbkdf2。

## 2. 全局工具安装（每台机器一次）

```bash
# 权威源在技能仓库里；执行一次 install，即软链为全局命令 secrets
bash ~/Doubao/skills/mac-system-toolkit/scripts/secrets.sh install
which secrets        # -> ~/.local/bin/secrets（该目录已在 PATH）
```
新机器跑 `scripts/setup-git-submodule-global.sh` 时也会顺带可用；之后在**任意目录**直接敲 `secrets`。

## 3. 主密码从哪来（关键红线）

密码来源**优先级**：

1. 环境变量 `ENC_PASS`（同时兼容旧名 `ENCRYPT_PASS`；业务脚本也可用自己的 `*_ENC_PASS`，如 `BAIDU_ENC_PASS`）；
2. 运行时交互安全输入 `read -s`（不回显）；
3. 都没有就**向用户询问**。

红线：

- **主密码绝不写进任何脚本、文档、git 仓库、`.enc` 文件名**；
- AI 只在会话记忆中临时持有，用户未提供时**直接问，不猜测、不写死**；
- `.enc` 即使进公开仓库，没有主密码也解不开；能不入库仍优先不入库（§4）。

## 4. 两级存放位置

| 级别 | 路径 | 装什么 | 是否进 git |
|------|------|--------|-----------|
| 全局凭证 | `$DOUBAO_SECRETS_DIR`，默认 `~/.doubao/secrets/<name>.enc` | 跨项目、与个人/机器绑定：sudo 密码、GitHub PAT、通用 API key | **永不入库**（家目录、仓库外） |
| 项目凭证 | `<项目>/.secrets/<name>.enc` | 只服务该项目/技能：如 mac-system-toolkit 的 Cloudflare webhook、高顿的百度凭证 | 仅 `.enc` 可随仓库，明文不入库 |

判断：换项目也要用 → 全局；只这个项目用 → 项目 `.secrets`。

### .gitignore 规则（项目内必须配）

```gitignore
# 凭证：明文绝不入库，仅 .enc 加密件放行
.secrets/*.json
.secrets/*.txt
.secrets/*.raw
.secrets/*.key
.secrets/*.pem
!*.enc
```
全局目录 `~/.doubao/secrets` 在所有仓库之外，天然不入库；脚本会把目录设 700、文件设 600。

## 5. 常用操作（统一用全局命令 secrets）

```bash
# —— 全局凭证（sudo 密码、GitHub PAT 等）——
ENC_PASS='主密码' secrets set sudo 'sudo密码'        # 存 -> ~/.doubao/secrets/sudo.enc
ENC_PASS='主密码' secrets get sudo                   # 取（解密到 stdout）
secrets path github_pat                              # 打印密文路径（不带 ENC_PASS 会交互问密码）

# —— 项目凭证（.enc 放项目 .secrets）——
ENC_PASS='主密码' secrets encrypt 'token明文' .secrets/power_webhook.enc   # 加密成文件
ENC_PASS='主密码' secrets decrypt .secrets/power_webhook.enc               # 解密整个内容
ENC_PASS='主密码' secrets json .secrets/baidu_credentials.enc access_token # 解密 JSON 并取一个字段

# 不想把明文留在命令历史：用 stdin
pbpaste | ENC_PASS='主密码' secrets encrypt - .secrets/x.enc
```

## 6. 业务脚本运行时如何取密（去明文改造范式）

**Bash**（参考本技能 `scripts/power.sh`）：

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 透传 ENC_PASS；未设置时 secrets 会交互询问
TOKEN="$(ENC_PASS="${ENC_PASS:-}" secrets decrypt "$SCRIPT_DIR/../.secrets/power_webhook.enc")"
```

**Python**（参考高顿 `scripts/baidu_upload.py`）：密码优先环境变量，否则 `getpass`：

```python
import os, subprocess, getpass
pwd = os.environ.get("BAIDU_ENC_PASS") or getpass.getpass("Enter decryption password: ")
token = subprocess.run(
    ["openssl","enc","-aes-256-cbc","-d","-pbkdf2","-base64",
     "-pass",f"pass:{pwd}","-in",".secrets/baidu_credentials.enc"],
    capture_output=True, text=True, check=True).stdout
```

## 7. 项目里不要再放 secrets.sh 副本（含迁移步骤）

凭证工具是**全局能力，不是某个项目的事**。项目内不要再复制一份 `secrets.sh`；只保留该项目的 `.secrets/*.enc` 密文。

把历史项目副本迁移到全局（以高顿为例，已完成）：

1. 全局装好 `secrets`（§2），先用它解密项目旧密文验证互通：`secrets decrypt .secrets/gh_token.enc`；
2. 删除项目内脚本：`git rm scripts/secrets.sh`；
3. 原项目特有的便捷子命令改用通用组合：
   - 旧 `secrets.sh gh-auth` → `secrets decrypt .secrets/gh_token.enc | gh auth login --with-token`；
   - 旧 `secrets.sh baidu access_token` → `secrets json .secrets/baidu_credentials.enc access_token`；
4. 更新项目文档里的命令路径；项目 `.secrets/*.enc` 原样保留。

## 8. 适用场景清单（遇到就用这套，不再发明新方案）

- sudo / 系统管理员密码；
- GitHub Personal Access Token、`gh auth login --with-token`；
- Cloudflare Tunnel / webhook token（本技能 power.sh）；
- 网盘/平台 OAuth：access_token / refresh_token / app_key / secret_key（一个 JSON 整体加密，用 `secrets json` 取字段）；
- Playwright extension token、各类 MCP/API key、数据库连接串。

## 9. 新机器恢复

1. `secrets install` 装好全局命令（§2）；
2. 全局凭证不在 git：经安全渠道把 `~/.doubao/secrets/*.enc` 拷到新机（或重新 `set`）；
3. 项目凭证随仓库的 `.enc`：clone 后即可被 `secrets` 解密，需主密码；
4. 主密码线下/当面获得，不随仓库同步。

## 10. 故障排查

| 现象 | 原因/处理 |
|------|----------|
| `command not found: secrets` | 没装全局命令，执行 §2 的 `secrets.sh install` |
| `bad decrypt` / `wrong final block length` | 密码错，或非统一参数加密；确认 `-pbkdf2 -base64` 且主密码正确 |
| 非交互卡住等待输入 | 没设 `ENC_PASS`；显式传入环境变量 |
| `.enc` 没出现在 git | 检查 .gitignore 是否 `!*.enc` 放行；全局目录本就不入库属正常 |
| 担心密文进公开仓 | `.enc` 有 AES-256+PBKDF2 保护可入库；要求更高则放全局目录不入库 |

## 11. 参考

- 工具实现：本技能 `scripts/secrets.sh`；首个去明文改造：`scripts/power.sh`
- 历史同范式（已抽离）：高顿 `scripts/baidu_upload.py`
- openssl enc 手册：`man openssl-enc`
