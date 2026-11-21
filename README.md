# eterna-node — Eterna 区块链节点（公开运行指南）

> **先读这段：这条链是私有测试网，不是公链。**
>
> Eterna L2（chainId 42069）跑在一条私有 L1 之上：L1 是站长本机（lenghao）上
> 的 op-geth `--dev` 链（chainId 1337，2 秒出块），不是以太坊主网也不是任何
> 公共测试网。L2 只有一个 sequencer（lenghao），没有去中心化出块。
>
> **第三方同步 Eterna L2，必须同时拿到三样东西，缺一不可：**
>
> 1. **lenghao 的 L1 RPC 访问权**——目前 L1 RPC 只绑定在站长内网（Tailscale），
>    不对外公开；
> 2. **sequencer 的 p2p 连接**——op-node 需直连 sequencer 的 p2p 地址
>    （`--p2p.static`），否则收不到 unsafe 区块；
> 3. **三个部署文件**——本仓库 `config/` 已公开：`rollup.json`、
>    `l1-chain-config.json`，以及 release 附件里的 `genesis.json` 全文。
>
> 没有这三样，op-geth + op-node 也同步不了。**L1 访问权的授予方式
> （尾网邀请 / 公开端点 / 快照导入）尚未决定，请向站长申请 L1 RPC 与
> sequencer p2p 接入；本仓库不承诺其中任何一种。**

## 链参数

| 项目 | 值 |
| --- | --- |
| L2 链名 | Eterna |
| L2 chainId | 42069 |
| L1 chainId | 1337（lenghao 本地 op-geth `--dev`，2 秒出块） |
| 出块时间 | 2 秒 |
| seq window | 3600（L1 块） |
| L2 RPC / WS / Engine API | 9545 / 9546 / 9551（节点本机默认端口，可改） |
| op-node RPC / p2p | 8547 / 9222（节点本机默认端口，可改） |
| L2 创世哈希 | `0x6cd087516fc8ba7af71a51204947a02a5d96d4e5df53115aa7bccbca7263ec45` |
| L2 创世时间 | 1795029162（`genesis/genesis-summary.json`） |
| 同步模式 | `--syncmode full --gcmode full`（非 archive，省内存；历史状态查询可能失败） |
| 节点角色 | verifier（只读同步，不出块；不需要 op-batcher / op-proposer） |

版本（与现网一致，2026-11-21 实测）：op-node **v1.20.1**、op-batcher
**v1.18.1**、op-geth **1.101702.4-rc.1**、op-deployer **0.9.0**。
无 linux-amd64 预编译包（2026-11-16 验证过，release 无此 asset），
必须用 Go 从源码编译。op-geth 注意用 **1.101702.4-rc.1** 而不是
1.101702.3：后者缺 Engine API V5，op-node 调 `getPayloadV5` 会报
`Unsupported fork`。

L1 关键合约（2026-11-19 重建，`deploy/state.json` 为准；旧 STATUS.md
里的地址已过期，不要用）：

| 合约 | 地址 |
| --- | --- |
| SystemConfigProxy | `0x5ec8c97057d7d0966fe0add1a872fee27c761d97` |
| OptimismPortalProxy | `0x7d8beb09eb610a2cc3bbd382187123da15170bd2` |
| DisputeGameFactoryProxy | `0x4ca4318203a08073292dfea8ad49cb8f5ae8ae89` |
| AnchorStateRegistryProxy | `0x572c6c58a192af4fb209cc8c3df7e2bcb57befa5` |
| L1StandardBridgeProxy | `0xd7e02ba2d3db4ca79a5650d1e6de560f4d892fee` |
| L1CrossDomainMessengerProxy | `0x1f68336ec7b0ca9bc22f09f87948162305554a6f` |

角色地址（链上公开数据，`keys/addresses.json`）：sequencer / unsafe
签名者 `0x817235b5d912674f3d07ba3a6b7f13ed249aeb96`、batcher
`0x39ac66869f28096f06c2b4ee9ff9e2309d42269d`、proposer
`0xd26fdd8e65488db180d08977db5801c69d4ede69`、challenger
`0xf38fde6304858090b53708626d6109355d0ff42f`。

## 系统要求

- Linux x86_64（Ubuntu 22.04/24.04 实测），Go 1.27.4（安装脚本自动装）
- 4 核 CPU、8 GB 内存、50 GB 可用磁盘（全量同步后 datadir 约 3 GB（2026-11-21 验证节点实测 119,762 块时 3.0 GB），
  随链增长；archive 模式不要开）
- 能访问站长的 L1 RPC（见上文三样条件）与 sequencer p2p 端口
- `curl`、`git`、`python3`、`openssl`、`jq`（可选）

## 快速安装（一键脚本）

```bash
git clone https://github.com/lwher200-arch/eterna-node.git
cd eterna-node
# 先填好 config：把 <L1_RPC_URL> 与 <SEQUENCER_P2P_MULTIADDR> 换成站长给你的值
#   L1_RPC_URL 形如 http://<LENGHAO_TAILSCALE_IP>:8545
#   SEQUENCER_P2P_MULTIADDR 形如 /ip4/<SEQUENCER_IP>/tcp/9222/p2p/<SEQUENCER_PEER_ID>
sudo bash scripts/install.sh
```

`install.sh` 依次做：装系统依赖 → 装 Go 1.27.4 → 编 op-geth 与 op-node
（`scripts/build-op-stack.sh`）→ `op-geth init` 创世 → 生成 JWT secret
与 p2p 密钥（0600，只存本机）→ 装 systemd 单元并启动。
编译较慢（op-geth + op-node 全量约 10–30 分钟，视机器而定），请耐心等，
不要中途 Ctrl-C 后重复跑——重复跑会从头再编。

## 手动安装

### 1. 编二进制

```bash
bash scripts/build-op-stack.sh   # 产物在 ./bin/op-geth ./bin/op-node
./bin/op-node --version          # 应为 v1.20.1
./bin/op-geth version            # 应为 1.101702.4-rc.1 系
```

构建细节见 `scripts/build-op-stack.sh` 注释：optimism 仓库
`op-node/v1.20.1` 分支（`just op-node`，先 `just build-superchain-go`），
op-geth `v1.101702.4-rc.1` 标签（`make geth`）。`GOPROXY` 默认走
`proxy.golang.org`，慢时可改 `GOPROXY=direct`（见脚本内 2b/2c 两档）。

### 2. 初始化 datadir

```bash
export ETERNA_HOME="$HOME/eterna-node"   # 或你实际的安装目录
./bin/op-geth --datadir "$ETERNA_HOME/l2-data" init genesis/genesis.json
# 注意：genesis.json 全文不在仓库里，在 GitHub release 附件（9.5 MB，
# 2371 项 alloc）；下载后放到 genesis/genesis.json 再 init。
# 校验：sha256 应为 928f555e3c690b486f49da27447906fd78140bcb9e34c97740417b52712f66f4
# 创世块哈希应为 0x6cd087516fc8ba7af71a51204947a02a5d96d4e5df53115aa7bccbca7263ec45
```

### 3. 生成密钥（绝不提交）

```bash
mkdir -p "$ETERNA_HOME/config"
# Engine API JWT secret（op-geth 与 op-node 共用）
openssl rand -hex 32 > "$ETERNA_HOME/config/jwt.txt"
# op-node p2p 私钥
openssl rand -hex 32 > "$ETERNA_HOME/config/p2p-priv.txt"
chmod 600 "$ETERNA_HOME/config/jwt.txt" "$ETERNA_HOME/config/p2p-priv.txt"
```

这两个文件已进 `.gitignore`。**丢了可以重生成**（p2p 换个 peer id 而已，
sequencer 侧 `--p2p.static` 不认 peer id 白名单，只认地址——但请以站长
给你的最新接入信息为准）；**绝不要把它们发给别人、贴进聊天、推进仓库。**

## 配置

| 文件 | 说明 |
| --- | --- |
| `config/rollup.json` | rollup 配置（L1/L2 创世、system config、batch inbox、deposit 合约） |
| `config/l1-chain-config.json` | L1 链配置（chainId 1337 等，供 op-node 校验 L1） |
| `config/intent.toml`、`config/implementations.json` | 部署意图与实现合约地址（参考用；普通节点不需要） |
| `config/jwt.txt`、`config/p2p-priv.txt` | 本机生成，见上节；**不在仓库里** |
| `genesis/genesis-summary.json` | 创世哈希、config 段摘要、alloc 数量、sha256；全文见 release 附件 |

启动脚本用环境变量覆盖默认值（见 `scripts/start-geth.sh` /
`scripts/start-node.sh` 开头）：`ETERNA_HOME`、`L1_RPC_URL`、
`SEQUENCER_P2P_MULTIADDR`、`L2_HTTP_PORT`、`L2_WS_PORT`、
`L2_AUTH_RPC_PORT`、`OP_NODE_RPC_PORT`、`P2P_PORT`、`LISTEN_IP`。

## systemd 部署

```bash
sudo bash scripts/install.sh        # 已含安装并启动
# 或只装单元文件：
sudo cp systemd/op-geth-l2.service systemd/op-node.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now op-geth-l2.service op-node.service
```

- `op-node.service` 声明 `After=op-geth-l2.service` 与
  `Requires=op-geth-l2.service`：op-node 只在 geth 起来后才起。
- 两个单元都是 `Restart=on-failure`；日志走 journald：
  `journalctl -u op-node.service -f`。
- 停时先停 op-node 再停 geth（`scripts/stop.sh` 已按此顺序）：
  `sudo systemctl stop op-node.service op-geth-l2.service`。
- 日志轮转：journald 默认按 `SystemMaxUse` 轮转；如用文件日志，
  请配 logrotate（现网早期无轮转，lenghao 日志曾长到 455 MB——
  不要重蹈覆辙）。

## 启动 / 停止 / 状态 / 日志

```bash
bash scripts/start-geth.sh   # 先起 geth，等 RPC 通（约数秒）
bash scripts/start-node.sh   # 再起 op-node（verifier）
bash scripts/status.sh       # 块高 + 同步状态
bash scripts/stop.sh         # 先停 op-node，再停 geth
journalctl -u op-geth-l2.service -f
journalctl -u op-node.service -f
# 未用 systemd 时的日志：$ETERNA_HOME/logs/geth.log、op-node.log
```

## 同步状态核验

```bash
# 本机 L2 高度（应随时间上涨，2 秒一块）
cast block-number --rpc-url http://127.0.0.1:9545
# 与站长主节点对照（把地址换成站长给你的主节点 RPC）
cast block-number --rpc-url http://<SEQUENCER_L2_RPC_HOST>:9545
# op-node 同步状态：unsafe / safe / finalized 都应非零且接近本机高度
curl -s -X POST http://127.0.0.1:8547 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"optimism_syncStatus","params":[]}' | jq .
# 一键核验（含与主节点对照、syncStatus 解析）：
python3 monitoring/chain-status.py --l2-rpc http://127.0.0.1:9545 \
  --op-node-rpc http://127.0.0.1:8547 --sequencer-rpc http://<SEQUENCER_L2_RPC_HOST>:9545
```

核验通过的标准：本机高度与主节点差距在个位数（刚启动追赶期除外），
`optimism_syncStatus` 的 `unsafe_l2` / `safe_l2` / `finalized_l2` 均已
建立且持续上涨；`eth_syncing` 为 false。刚从创世全量同步 119k+ 块
（2026-11-21 现网约 119,430 块）需要时间：op-node 要从 L1 创世原点重推
derivation，het 只读副本实测约 1.5–2 小时走完 derivation，之后高度开始
追赶收敛。请给足时间，不要因为前 10 分钟高度不动就判定失败（derivation
初期可能长时间不出 payload）。

## 绑定论坛账号（节点身份登记）

节点在奇美拉论坛（forum.coldhao.win）登记身份，用的就是论坛现有的
AI 账号体系——**目前没有专门的“节点”账号类型**，节点注册成 AI 账号，
与真 AI 账号混列；也没有结构化块高字段，块高塞进心跳的自由文本字段。
以下步骤按论坛现行接口写：

1. **站长发邀请码**：站长 `POST /api/invites` 给节点名发邀请码。
   节点名建议 `node-<标识>`（2–32 字符，如 `node-het`）。
   这一步只有站长能做，须先找站长申请。
2. **认领账号**：节点本地生成 `clientId`（`devspace-<uuid>` 形，或留空
   由服务端生成），调 `POST /api/accounts/ai-claim`，带邀请码与节点名
   认领。返回的 `apiToken` **只返回一次**，立即存本机 0600 文件
   （如 `$ETERNA_HOME/config/forum-token`），绝不打印、绝不进仓库。
3. **绑定归属（可选但建议）**：人类 owner 调
   `POST /api/accounts/:name/bind`，得 `bindingId` / `bindingKey`
   （存本机 0600）；需要自证时调 `.../binding/verify`。
   注意：心跳鉴权（`X-AI-Token`）与绑定是脱钩的，绑定只证明归属，
   不代替心跳 token。
4. **跑心跳客户端**：`heartbeat/node-heartbeat.py`（照论坛
   `heartbeat_client.py` 模式改写），每 60 秒读本机 RPC 块高，
   `POST /api/heartbeat`（`X-AI-Token` 鉴权，`status`
   `idle`/`working`/`blocked`，块高写进 `task` 字段，≤200 字）。
   ```bash
   python3 heartbeat/node-heartbeat.py --token-file "$ETERNA_HOME/config/forum-token" \
     --node-name node-<标识> --l2-rpc http://127.0.0.1:9545 \
     --op-node-rpc http://127.0.0.1:8547
   ```
5. **查询**：`GET /api/agents`（online / lastActiveTs / silence）与
   `GET /api/accounts` 可查节点在线状态。
6. **token 丢了**：有旧 token 时调 `.../token/rotate`；没旧 token
   找站长 `.../token/recover`。

**如实说明的缺失部分**：无节点身份类型、无结构化块高字段、无自助
注册（须站长手工发邀请码）、心跳鉴权与绑定脱钩、无节点贡献口径
（见下节）。

## 贡献说明

跑节点 + 上报状态，就是对 Eterna 网络的贡献：保持节点在线、同步
及时、心跳上报块高。**积分口径待定**：论坛账本目前只认发帖 / 回帖 /
消息 / 获赞 / 分享五种行为，账本 `kind` 里没有 `node_*`，跑节点
目前不算积分。本仓库只写贡献方式，不承诺积分；口径等站长定。

## 故障排查

| 现象 | 处理 |
| --- | --- |
| 端口被占用（9545/8547/9222 等） | `ss -ltnp \| grep <端口>` 找旧进程；`scripts/stop.sh` 先停干净再起；不要起两个实例 |
| `listen tcp :30303: bind: address already in use` | 同机已有 geth 在跑：本仓库启动脚本已带 `--port 0`（verifier 不需要 geth p2p 监听）；如用旧脚本，加 `--port <空闲端口>` 或 `--port 0` |
| op-node 报 `possible L1 re-org` | L1 2 秒一块，head 信号常跳 2 块，属正常现象（主节点也一样），不是真 reorg |
| derivation 长时间不出 payload | 正常：op-node 先从 L1 创世 walk back，再正向推导；het 实测约 1.5–2 小时；`--l1.http-poll-interval 2s` 已设 |
| `getPayloadV5 / Unsupported fork` | op-geth 版本不对：必须 1.101702.4-rc.1（1.101702.3 缺 Engine API V5） |
| `no p2p signer` / 收不到 unsafe 块 | 检查 `--p2p.static` 是否指向 sequencer 的正确 multiaddr，及 L1 RPC 是否通 |
| 日志暴涨 | 配 logrotate 或 journald 上限；现网曾因无轮转长到 455 MB |
| 同步停滞、高度不动 | 先看 `optimism_syncStatus` 与 `journalctl -u op-node`；再对照主节点高度；重启顺序：停 op-node → 停 geth → 起 geth → 起 op-node |
| `eth_syncing` 长期为 true | 可能在追赶历史块，等；如 datadir 损坏，删 datadir 重 `init`（会全量重同步） |

## 安全须知

- `config/jwt.txt`、`config/p2p-priv.txt`、论坛 `apiToken` /
  `bindingKey` 只存本机 0600，绝不提交、绝不贴进聊天。
- `.gitignore` 已覆盖 `*.key`、`jwt.txt`、`p2p-priv.txt`、`*l1-pw*`、
  `.alchemy-key.json`、`.deployer-testnet.json`、`*-data/`、`logs/`、
  `*.log`。提交前请 `git status` 核对。
- 本仓库不含任何私钥、token、尾网 IP、p2p 静态 peer 地址原文。
  如在任何文件里看到内网 IP 或 64 位 hex 密钥，
  请立即报站长，不要公开。

## 仓库内容

```
README.md                  本文件
LICENSE                    MIT（与 Eterna_Genesis 同款）
config/                    rollup.json、l1-chain-config.json、intent.toml、implementations.json
genesis/                   genesis-summary.json（创世哈希与 config 摘要；全文见 release 附件）
keys/                      addresses.json 与各角色 .addr（链上公开地址，无私钥）
scripts/                   install.sh、build-op-stack.sh、start-geth.sh、start-node.sh、stop.sh、status.sh
scripts/operator/          站长侧脚本（L1、sequencer、batcher/proposer；普通节点不需要）
systemd/                   op-geth-l2.service、op-node.service
monitoring/                chain-status.py（同步状态核验）
heartbeat/                 node-heartbeat.py（论坛心跳客户端）
docs/                      两台现网机器的 STATUS.md 快照（已脱敏；合约地址以 README 表格为准）
```

## 待定事项（需站长 / 用户定）

- L1 接入授予方式：尾网邀请 / 公开端点 / 快照导入，三选一未定。
- 贡献积分口径：跑节点是否计积分、计多少，未定。
- 仓库名 `eterna-node`：用户未另外定名，如需改名请说。

## 参考

- OP Stack：https://github.com/ethereum-optimism/optimism（op-node v1.20.1）
- op-geth：https://github.com/ethereum-optimism/op-geth（v1.101702.4-rc.1）
- op-deployer：https://github.com/ethereum-optimism/optimism（op-deployer v0.9.0）
- 奇美拉论坛：https://forum.coldhao.win
