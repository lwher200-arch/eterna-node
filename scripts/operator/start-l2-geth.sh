#!/bin/bash
# OPERATOR ONLY: L2 execution layer on the sequencer host.
# RPC 9545, WS 9546, Engine API (authrpc) 9551, JWT config/jwt.txt.
# The `miner` namespace is enabled: op-batcher needs miner_setMaxDASize.
# --gcmode archive here (sequencer host); verifier nodes use full mode.
set -u
W="${ETERNA_HOME:-$HOME/eterna-chain-local/opstack-local}"
export PATH=$W/bin:$PATH
setsid $W/bin/op-geth --datadir $W/l2-data --networkid 42069 \
  --http --http.addr 127.0.0.1 --http.port 9545 \
  --http.api eth,net,web3,debug,miner --http.corsdomain "*" \
  --ws --ws.addr 127.0.0.1 --ws.port 9546 --ws.api eth,net,web3,miner \
  --authrpc.addr 127.0.0.1 --authrpc.port 9551 --authrpc.vhosts "*" \
  --authrpc.jwtsecret $W/config/jwt.txt \
  --syncmode full --gcmode archive --nodiscover --maxpeers 0 \
  > $W/logs/l2-geth.log 2>&1 < /dev/null &
echo "L2-GETH pid $!"
