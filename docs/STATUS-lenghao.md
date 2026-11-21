> 快照说明：以下为现网机器 STATUS.md 的脱敏快照（尾网 IP 已换成占位符）。文件内的合约地址是 2026-11-16 的旧值，已过期；当前地址以 README 表格（2026-11-19 重建，deploy/state.json 为准）为准。

# Eterna OP Stack 本地测试网 — 状态（2026-11-16 17:16，Phase 1a 已跑通）

工作目录：/home/lenghao/eterna-chain-local/opstack-local/
L1：op-geth --dev，chainId 1337，RPC http://127.0.0.1:8545（WS 8546，authrpc 8551）
L2：Eterna，chainId 42069，RPC http://127.0.0.1:9545（WS 9546，Engine API 9551）
  op-node RPC http://127.0.0.1:8547；batcher RPC 8548；proposer RPC 8549

## 服务（setsid 后台，日志在 logs/）
- L1 geth：start-l1.sh（--dev --dev.period 2，datadir l1-dev-data；重启加 --rpc.allow-unprotected-txs）
- L2 geth：start-l2-geth.sh（op-geth 1.101702.4-rc.1，datadir l2-data，--http.api 含 miner）
- op-node：start-l2.sh node（sequencer，--l2.enginekind geth）
- op-batcher：start-l2.sh batcher（calldata，--max-channel-duration 60）
- op-proposer：start-l2.sh proposer（--game-type 1 permissioned，--allow-non-finalized）
- 全部：bash start-l2.sh all（先起 L2 geth，再起这三个）

## 查状态
- L1/L2 块高：cast block-number --rpc-url http://127.0.0.1:8545（或 9545）
- 同步：curl -X POST http://127.0.0.1:8547 -d '{"jsonrpc":"2.0","id":1,"method":"optimism_syncStatus","params":[]}'
- batcher 提交数：cast nonce 0x39Ac66869F28096f06C2B4eE9ff9e2309D42269D --rpc-url http://127.0.0.1:8545
- 争议游戏数：cast call 0xb2db46405161eaab82aba8056381bfeab66c2077 "gameCount()(uint256)" --rpc-url http://127.0.0.1:8545

## L2 部署产物（deploy/）
- genesis.json（chainId 42069；已补 osakaTime: 0，哈希不变 0x3e485c79…）、rollup.json
- superchain.json：proxy 0x39dbe4d3e6417d5a6b47e4fa2b949d1829341e6e，impl 0xa303a644cfbc0c34f6a9dbeafdeba4c967ea01e7，proxyAdmin 0xc7bbbd450246918f524b944f4f34afba0d47f4f7
- implementations.json：OPCM v2 0xb1789b4a8c7d3468ab95e5818b44ab0cad051ded
- L1 关键合约：SystemConfig 0xc3574ab0c27db127eba066f5175b66241d08d237，DisputeGameFactory 0xb2db46405161eaab82aba8056381bfeab66c2077（type 1 已注册，initBond 0.08 ETH；type 0 已清空），AnchorStateRegistry 0x0ed26a16dd446422ab1229b44662af9a5adf0a15，OptimismPortal 0x6da7b7e7e525c4e5d6ab86e6ebe99fabd88e5e08

## 三合约（本地 L2，部署见 logs/deploy-local.log，冒烟 ALL PASS）
- KnowledgeRegistry 0x77A026A73cEC6853cC8BE8C2d26C15dA7A49d343
- ApprovalRegistry 0x057604f4738d3fF0aD6da086E0d92E52DBd75299
- AuthorizationRegistry 0x7eee6A0496b2D1eb18A994dB127188ebA27cD8e1
- 部署钱包：本地 l1-deployer（0xA8F5…，L2 有 100 ETH，系从预置账户 0xf39F… 转入）

## RCF 本地同步（state/，与 Base Sepolia 的 state 完全分开）
- grants-batch-local.json（3 条 live grant）、shadow-batch-local.json（20 条收据 10 批 + 10 拒）
- shadow-grant-state-local.json（3 条已上链）、shadow-state-local.json（20 条已上链）
- 核验：3/3 grant AUTHORIZED，20/20 收据 APPROVED/DENIED 与源一致
- 脚本已参数化（AUTH_REGISTRY / APPROVAL_REGISTRY / GRANTS_BATCH / RECEIPTS_BATCH / SHADOW_GRANT_STATE / SHADOW_STATE，缺省即 Base Sepolia 行为；hardhat.config.js 新增 localL2 网络）；备份在各文件旁 .bak-local

## 已知偏离（相对任务原文）
- L1 chainId 1337 而非 900：op-geth --dev 固定 1337；自定义 clique 创世被当前 op-geth 拒（只要 pre-merge 遗留字段）。
- fault proofs 保持默认开启：intent 无开关；proposer 跑 permissioned game（type 1）。
- op-reth 未用：无预编译包；执行层用 op-geth。op-node/batcher/proposer 无预编译包，系 Go 现编（op-node v1.20.1、op-batcher v1.18.1、op-proposer v1.17.1）。
- L2 op-geth 是 1.101702.4-rc.1（从模块缓存源码现编）：1.101702.3 缺 Engine API V5，Karst 链上 op-node 调 getPayloadV5 报 Unsupported fork。
- genesis.json 补了 osakaTime: 0：op-deployer 不出该字段，op-geth 的 IsOsaka 认它，缺了 getPayloadV5 同样报 Unsupported fork；创世哈希不变。
- DisputeGameFactory 的 base game 是手动注册的：OPCM 未把 game 注册进 factory（gameImpls 全空）；已按 OPCM 的 _makeGameArgs 注册 type 1（prestate 0x038512e0…、mipsSingleton、anchor、DelayedWeth、chainId、proposer、challenger）并设 bond 0.08 ETH，type 0 已清空。
- L1 需 Create2Deployer（0x4e59…）：全新 --dev 链上没有，bootstrap 的 CREATE2 全是空操作；已用 Arachnid 经典部署交易补上（先给发送方 0x3fab… 转 1 ETH，L1 重启加 --rpc.allow-unprotected-txs）。
- batcher 首次提交慢：空链通道要攒满 120KB 或等 sequencer window（3600 L1 块）；已加 --max-channel-duration 60（约 120 秒）。
- proposer/batchers 私钥改走环境变量（OP_BATCHER_PRIVATE_KEY / OP_PROPOSER_PRIVATE_KEY），不再出现在 ps 命令行。注意：旧版启动方式下 proposer 密钥曾短暂出现在 ps 输出里——仅本地测试网密钥，无真实价值；如介意可轮换 proposer/batcher 角色密钥并重注资。

## 未做
- het 第二节点：未做（主线占满；het 有 Docker，可后续起 L2 只读副本）。
- RCF 定期同步 cron：未设（等用户定；手动一次已跑通）。

## 2026-11-16 晚 — het 副本 + 本地 RCF 定时同步（Phase 1a 补完）
- L1 geth HTTP 从 127.0.0.1 改绑尾网 <LENGHAO_TAILSCALE_IP>（start-l1.sh 已重写，旧版备份 start-l1.sh.bak-20261116；其余参数与运行中进程一致，--dev 数据在 l1-dev-data，重启不断链，重启后 L1 高度连续）。WS/authrpc 仍 loopback。
- start-l2.sh（备份 start-l2.sh.bak-20261116）：op-node/batcher/proposer 的 L1 RPC 改走 http://<LENGHAO_TAILSCALE_IP>:8545；op-node 加 --p2p.listen.ip/--p2p.advertise.ip <LENGHAO_TAILSCALE_IP>:9222；op-node 加 OP_NODE_P2P_SEQUENCER_KEY（keys/sequencer.key，与 SystemConfig unsafeBlockSigner 0x817235B5d912674F3D07Ba3A6b7f13eD249AEB96 一致），gossip 发布已恢复（之前 38 次 "no p2p signer" 警告，现 "Publishing signed execution payload on p2p"）。
- 注意：重启时旧 batcher（PID 746141）SIGTERM 未退出、新 batcher 因 8548 端口占用启动失败；已 kill -9 旧进程并重起 batcher，现单实例。
- het 副本：/root/eterna-replica/（op-node + op-geth，只读）；L2 RPC http://<HET_TAILSCALE_IP>:9545，op-node RPC 8547，p2p 9222；UFW 已放行这三个端口（仅尾网 <TAILSCALE_CGNAT_RANGE>）。状态见 het 上 /root/eterna-replica/STATUS.md。副本经 DERP 中继连 lenghao（约 300ms，非直连）；初始状态用 admin.exportChain + import 导入 4813 块，op-node 仍在重推 derivation，见 het STATUS.md。
- 本地 RCF 定时同步 cron：eterna-chain-local-rcf-sync（每 30 分钟，owner goal:devspace-eterna，首跑 2026-11-16 19:21:54 CST）。手动触发已验：grant 0 新（3 个已在链）、收据 20 条写入 + verify 20/20 一致；本地 state 在 opstack-local/state/（与 Base Sepolia 完全分开）。
