#!/bin/bash
# Start op-node in verifier mode (read-only replica: no sequencer,
# no batcher/proposer). L2 op-geth must already be running.
# Needs L1_RPC_URL + SEQUENCER_P2P_MULTIADDR from the chain operator:
#   L1_RPC_URL=http://<LENGHAO_TAILSCALE_IP>:8545
#   SEQUENCER_P2P_MULTIADDR=/ip4/<SEQUENCER_IP>/tcp/9222/p2p/<SEQUENCER_PEER_ID>
# Override ports with env: OP_NODE_RPC_PORT, P2P_PORT, LISTEN_IP.
set -u
W="${ETERNA_HOME:-$HOME/eterna-node}"
export PATH="$W/bin:$PATH"
L1_RPC_URL="${L1_RPC_URL:-}"
SEQUENCER_P2P_MULTIADDR="${SEQUENCER_P2P_MULTIADDR:-}"
if [ -z "$L1_RPC_URL" ] || [ -z "$SEQUENCER_P2P_MULTIADDR" ]; then
  echo "ERROR: set L1_RPC_URL and SEQUENCER_P2P_MULTIADDR (see README)."
  exit 1
fi
RPC_PORT="${OP_NODE_RPC_PORT:-8547}"
P2P_PORT="${P2P_PORT:-9222}"
AUTH_PORT="${L2_AUTH_RPC_PORT:-9551}"
LISTEN_IP="${LISTEN_IP:-127.0.0.1}"
mkdir -p "$W/logs" "$W/op-node-data/peerstore"
if [ ! -f "$W/config/p2p-priv.txt" ]; then
  openssl rand -hex 32 > "$W/config/p2p-priv.txt"
  chmod 600 "$W/config/p2p-priv.txt"
fi
setsid "$W/bin/op-node" \
  --l1 "$L1_RPC_URL" \
  --l2 "http://127.0.0.1:$AUTH_PORT" \
  --rollup.config "$W/config/rollup.json" \
  --rollup.l1-chain-config "$W/config/l1-chain-config.json" \
  --l1.beacon.ignore \
  --rpc.addr "$LISTEN_IP" --rpc.port "$RPC_PORT" --rpc.enable-admin \
  --l2.jwt-secret "$W/config/jwt.txt" \
  --l2.enginekind geth \
  --verifier.l1-confs 1 \
  --l1.trustrpc --l1.rpckind basic \
  --l1.http-poll-interval 2s \
  --p2p.priv.path "$W/config/p2p-priv.txt" \
  --p2p.peerstore.path "$W/op-node-data/peerstore" \
  --p2p.static "$SEQUENCER_P2P_MULTIADDR" \
  --p2p.listen.ip "$LISTEN_IP" --p2p.listen.tcp "$P2P_PORT" --p2p.listen.udp "$P2P_PORT" \
  --p2p.advertise.ip "$LISTEN_IP" \
  > "$W/logs/op-node.log" 2>&1 < /dev/null &
echo "OP-NODE pid $!"
