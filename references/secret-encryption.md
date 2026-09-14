# 凭证 / 密码统一加密约定

> 这是**全机唯一**的敏感凭证落盘约定：凡是需要保存到磁盘的密码、token、API key、secret（如 sudo 密码、GitHub PAT、Cloudflare webhook、Playwright token、各平台 API 凭证等），一律按本约定加密，**明文绝不进 git、不写进脚本**。
> 工具：[`scripts/secrets.sh`](../scripts/secrets.sh)。算法与高顿知识库项目 `scripts/secrets.sh` 完全一致，密文互通。

---

## 1. 固定算法（不要改）

```bash
openssl enc -aes-256-cbc -salt -pbkdf2 -base64      # 加密
openssl enc -aes-256-cbc -d -salt -pbkdf2 -base64   # 解密
```

- **AES-256-CBC**，密钥用 **PBKDF2** 从主密码派生，带随机 **salt**，输出 **base64 文本**（可直接入库、便于 diff）。
- 统一参数是为了让不同机器、不同项目生成的 `.enc` 能互相解密；不要换算法/去掉 pbkdf2。

## 2. 主密码从哪来（关键红线）

密码来源**优先级**：

1. 环境变量 `ENC_PASS`（非交互/脚本/CI 场景）：`ENC_PASS='主密码' secrets.sh get xxx`；
2. 运行时交互安全输入 `read -s`（不回显）；
3. 都没有就**向用户询问**。

红线：

- **主密码绝不写进任何脚本、文档、git 仓库、`.enc` 文件名**；
- AI 侧只在会话记忆中临时持有，用户未提供时**直接问，不猜测、不写死**；
- `.enc` 即使进了公开仓库，没有主密码也无法解密；但能不入库仍优先不入库（见 §3）。

## 3. 两级存放位置

| 级别 | 路径 | 装什么 | 是否进 git |
|------|------|--------|-----------|
| 全局凭证 | `$DOUBAO_SECRETS_DIR`，默认 `~/.doubao/secrets/<name>.enc` | 跨项目、与个人/机器绑定：sudo 密码、GitHub PAT、通用 API key | **永不入库**（在家目录，仓库外） |
| 项目凭证 | `<项目>/.secrets/<name>.enc` | 只服务于该项目/技能的凭证，如 mac-system-toolkit 的 Cloudflare webhook | 仅 `.enc` 可随仓库，明文不入库 |

判断：换个项目也要用的 → 全局；只这个项目用的 → 项目 `.secrets`。

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

全局目录 `~/.doubao/secrets` 在所有仓库之外，天然不会被提交；并设 `700/600` 权限（脚本自动处理）。

## 4. 常用操作（统一走 secrets.sh）

```bash
S=~/Doubao/skills/mac-system-toolkit/scripts/secrets.sh

# —— 全局凭证（sudo 密码、GitHub PAT 等）——
ENC_PASS='主密码' bash "$S" set sudo 'sudo密码'         # 存 -> ~/.doubao/secrets/sudo.enc
ENC_PASS='主密码' bash "$S" get sudo                    # 取（解密到 stdout）
bash "$S" path github_pat                               # 打印密文路径（不带 ENC_PASS 会交互问密码）

# —— 项目凭证（.enc 放项目 .secrets）——
mkdir -p .secrets
ENC_PASS='主密码' bash "$S" encrypt 'token明文' .secrets/power_webhook.enc   # 加密成文件
ENC_PASS='主密码' bash "$S" decrypt .secrets/power_webhook.enc               # 解密查看

# 不想把明文留在命令历史：用 stdin
pbpaste | ENC_PASS='主密码' bash "$S" encrypt - .secrets/x.enc
```

## 5. 业务脚本运行时如何取密（去明文改造范式）

**Bash**（参考本技能 `scripts/power.sh`）：

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 透传 ENC_PASS；未设置时 secrets.sh 会交互询问
TOKEN="$(ENC_PASS="${ENC_PASS:-}" bash "$SCRIPT_DIR/secrets.sh" decrypt "$SCRIPT_DIR/../.secrets/power_webhook.enc")"
```

**Python**（参考高顿 `scripts/baidu_upload.py`）：密码优先取环境变量，否则 `getpass`：

```python
import os, subprocess, getpass
pwd = os.environ.get("ENC_PASS") or getpass.getpass("Enter decryption password: ")
token = subprocess.run(
    ["openssl","enc","-aes-256-cbc","-d","-pbkdf2","-base64",
     "-pass",f"pass:{pwd}","-in",".secrets/power_webhook.enc"],
    capture_output=True, text=True, check=True).stdout.strip()
```

## 6. 适用场景清单（遇到就用这套，不再发明新方案）

- sudo / 系统管理员密码；
- GitHub Personal Access Token、`gh auth login --with-token`；
- Cloudflare Tunnel / webhook token（本技能 power.sh）；
- 网盘/平台 OAuth：access_token / refresh_token / app_key / secret_key（参考高顿 `.secrets/baidu_credentials.enc`，用一个 JSON 整体加密）；
- Playwright extension token、各类 MCP/API key、数据库连接串。

## 7. 新机器恢复

1. 全局凭证不在 git：通过安全渠道把 `~/.doubao/secrets/*.enc` 拷到新机（或按需重新 `set`）；
2. 项目凭证随仓库的 `.enc`：clone 后直接可用，解密需主密码；
3. 主密码通过线下/用户当面获得，不随仓库同步。

## 8. 故障排查

| 现象 | 原因/处理 |
|------|----------|
| `bad decrypt` / `wrong final block length` | 密码错，或不是用统一参数加密；确认 `-pbkdf2 -base64` 且主密码正确 |
| 非交互卡住等待输入 | 没设 `ENC_PASS`；脚本在等你输密码，或显式传入环境变量 |
| `.enc` 没出现在 git 里 | 检查 .gitignore 是否 `!*.enc` 放行；全局目录本就不入库属正常 |
| 担心密文进公开仓 | `.enc` 有 AES-256+PBKDF2 保护可入库；更高要求则改放全局目录不入库 |

## 9. 参考

- 同范式实现：高顿知识库 `scripts/secrets.sh`、`scripts/baidu_upload.py`
- openssl enc 手册：`man openssl-enc`
