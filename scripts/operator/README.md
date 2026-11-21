# scripts/operator — 站长侧脚本（普通节点不需要）

这里是 lenghao 主节点（sequencer + L1）的原始启动 / 准备脚本，已脱敏
（尾网 IP 换成占位符）。普通 verifier 节点只需要 `scripts/` 下的
start-geth.sh / start-node.sh，不要跑这里的脚本。

- `start-l1.sh`：本地 L1（op-geth `--dev`，chainId 1337，2 秒出块）。
- `start-l2-geth.sh`：主节点 L2 op-geth（`--gcmode archive`，含 `miner` API，
  供 batcher 用；副本节点用 full 模式即可）。
- `start-l2.sh`：op-node sequencer + op-batcher + op-proposer（`all` 一起起）。
  私钥走环境变量，不出现在 ps 输出里。
- `prep-l1.sh`：生成各角色密钥（`cast wallet new`）。L1 创世 / datadir
  初始化是站长侧部署步骤，不在公开仓库里——本仓库不含已过期的
  `config/l1-genesis.json`（chainId 900）。

所有 `<...>` 占位符须先替换成真实值再用；不要把替换后的文件提交回仓库。
