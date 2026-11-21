> 快照说明：以下为现网机器 STATUS.md 的脱敏快照（尾网 IP 已换成占位符）。文件内的合约地址是 2026-11-16 的旧值，已过期；当前地址以 README 表格（2026-11-19 重建，deploy/state.json 为准）为准。

# Eterna L2 只读副本 — het (ubuntu-4gb-nbg1-1)

只读副本：op-node (verifier) + op-geth，从 lenghao 的 sequencer 同步。不出块、不跑 batcher/proposer。
工作目录：/root/eterna-replica/（二进制 bin/、配置 config/、部署文件 deploy/、数据 l2-data/、日志 logs/）

## 服务（setsid 后台，日志在 logs/）
- L2 geth：start-geth.sh（op-geth 1.101702.4-rc.1，与 lenghao 同版本；--syncmode full --gcmode full（非 archive，省内存）；datadir l2-data；HTTP <HET_TAILSCALE_IP>:9545；authrpc 127.0.0.1:9551）
- op-node：start-node.sh（verifier 模式；--l1 http://<LENGHAO_TAILSCALE_IP>:8545；--l1.http-poll-interval 2s；--p2p.static 指向 lenghao sequencer（peerID <SEQUENCER_PEER_ID>，tcp 9222）；RPC <HET_TAILSCALE_IP>:8547；p2p <HET_TAILSCALE_IP>:9222）
- 启动顺序：先 geth，再 op-node。重启：kill 进程后跑对应脚本（geth 停前先停 op-node）。

## 查状态
- 块高：cast block-number --rpc-url http://<HET_TAILSCALE_IP>:9545（lenghao 对照：http://127.0.0.1:9545）
- 同步：curl -X POST http://<HET_TAILSCALE_IP>:8547 -d '{"jsonrpc":"2.0","id":1,"method":"optimism_syncStatus","params":[]}'
- 日志：logs/geth.log、logs/op-node.log

## 防火墙（UFW）
- 已放行（仅尾网 <TAILSCALE_CGNAT_RANGE>）：9545（L2 RPC）、8547（op-node RPC）、9222（p2p）。其余端口默认拒绝。注意：副本与 lenghao 之间走 DERP 中继（非直连，约 300ms）。

## 同步方式与状态（2026-11-16 19:30）
- 初始状态不用 derivation 全量走 L1：从 lenghao 用 admin.exportChain 导出整条 L2 链（/tmp/chain-20261116.rlp，4.4MB），scp 到 het，op-geth import 导入 4813 块（约 9 秒），创世哈希 0x3e485c79… 一致。
- import 后 geth 高度 4813，KnowledgeRegistry 字节码与 lenghao 逐字节一致（8451 字节），副本读到的状态是真的。
- op-node 仍在从 L1 创世原点（L1 435）重推 derivation：启动时先 walk back L1（约 2.4 块/秒），再正向推导（约 1.3 块/秒）。L1 经 DERP 中继，2 秒一块的 L1 使 op-node 的 head 信号常跳 2 块、报 "possible L1 re-org"（lenghao sequencer 本机也有同样警告，属正常现象，非真 reorg）。
- 截至 19:30：het 高度仍为导入的 4813，lenghao 约 5100+，差距约 300 块；op-node 的 unsafe/safe/finalized 尚未建立（syncStatus 全 0）。预计 derivation 走完需约 1.5–2 小时，之后 het 高度开始追赶、差距收敛到个位数。
- 未验证：derivation 正向推导时 channel 能否正常完成并出 payload（首次启动时 10 分钟内零 payload，疑与 reset 周期有关；已加 --l1.http-poll-interval 2s，但警告频率未降，待观察）。如 derivation 长期不出 payload，需另查 channel bank / reset 逻辑。

## 已知限制
- geth 为 full 模式（非 archive）：只能查近期状态，历史状态查询可能失败。
- 单 sequencer，副本只读；lenghao 停则副本停。
- 密钥：config/jwt.txt（0600）与 config/p2p-priv.txt（0600）仅存 het 本机，不进 git、不进聊天。
