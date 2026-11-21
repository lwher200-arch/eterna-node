#!/bin/bash
# Quick status: L2 height + op-node syncStatus.
set -u
W="${ETERNA_HOME:-$HOME/eterna-node}"
HTTP_PORT="${L2_HTTP_PORT:-9545}"
RPC_PORT="${OP_NODE_RPC_PORT:-8547}"
echo "--- L2 height (local op-geth :$HTTP_PORT)"
curl -s -X POST "http://127.0.0.1:$HTTP_PORT" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
echo
echo "--- op-node syncStatus (:$RPC_PORT)"
curl -s -X POST "http://127.0.0.1:$RPC_PORT" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"optimism_syncStatus","params":[]}'
echo
echo "--- processes"
pgrep -af "op-node --l1|op-geth --datadir" || echo "(no node processes running)"
