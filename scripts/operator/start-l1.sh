#!/bin/bash
# OPERATOR ONLY: local L1 (op-geth --dev, chainId 1337, 2s blocks).
# Replace <LENGHAO_TAILSCALE_IP> with the operator's Tailscale IP.
# WS/authrpc stay loopback-only. --dev chain state lives in l1-dev-data
# and survives restarts with the same datadir.
set -u
W="${ETERNA_HOME:-$HOME/eterna-chain-local/opstack-local}"
export PATH=$W/bin:$PATH
exec $W/bin/op-geth --dev --dev.period 2 --datadir $W/l1-dev-data \
  --http --http.addr <LENGHAO_TAILSCALE_IP> --http.port 8545 --http.api eth,net,web3,debug,admin --http.corsdomain '*' \
  --ws --ws.addr 127.0.0.1 --ws.port 8546 --ws.api eth,net,web3 \
  --authrpc.port 8551 --authrpc.addr 127.0.0.1 --authrpc.vhosts '*' \
  --nodiscover --maxpeers 0 --rpc.allow-unprotected-txs
