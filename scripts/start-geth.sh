#!/bin/bash
# Start the L2 execution layer (op-geth) for an eterna-node verifier.
# RPC 9545, WS 9546, Engine API (authrpc) 9551, JWT config/jwt.txt.
# --syncmode full --gcmode full (not archive: saves RAM).
# Override ports/hosts with env: ETERNA_HOME, L2_HTTP_PORT, L2_WS_PORT,
# L2_AUTH_RPC_PORT, LISTEN_IP.
set -u
W="${ETERNA_HOME:-$HOME/eterna-node}"
export PATH="$W/bin:$PATH"
HTTP_PORT="${L2_HTTP_PORT:-9545}"
WS_PORT="${L2_WS_PORT:-9546}"
AUTH_PORT="${L2_AUTH_RPC_PORT:-9551}"
LISTEN_IP="${LISTEN_IP:-127.0.0.1}"
mkdir -p "$W/logs"
setsid "$W/bin/op-geth" --datadir "$W/l2-data" --networkid 42069 \
  --http --http.addr "$LISTEN_IP" --http.port "$HTTP_PORT" \
  --http.api eth,net,web3 --http.corsdomain "*" \
  --ws --ws.addr "$LISTEN_IP" --ws.port "$WS_PORT" --ws.api eth,net,web3 \
  --authrpc.addr 127.0.0.1 --authrpc.port "$AUTH_PORT" --authrpc.vhosts "*" \
  --authrpc.jwtsecret "$W/config/jwt.txt" \
  --syncmode full --gcmode full --nodiscover --maxpeers 0 \
  > "$W/logs/geth.log" 2>&1 < /dev/null &
echo "L2-GETH pid $!"
