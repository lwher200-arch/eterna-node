#!/bin/bash
# eterna-node one-click install (verifier node: op-geth + op-node only).
# Steps: system deps -> Go 1.27.4 -> build binaries -> init datadir ->
# generate jwt + p2p keys (0600, local only) -> install + start systemd units.
# Re-run is safe: existing binaries/keys/datadir are reused, not rebuilt.
# Needs: L1_RPC_URL and SEQUENCER_P2P_MULTIADDR from the chain operator.
#   L1_RPC_URL: http://<LENGHAO_TAILSCALE_IP>:8545
#   SEQUENCER_P2P_MULTIADDR: /ip4/<SEQUENCER_IP>/tcp/9222/p2p/<SEQUENCER_PEER_ID>
set -u
ETERNA_HOME="${ETERNA_HOME:-$HOME/eterna-node}"
L1_RPC_URL="${L1_RPC_URL:-}"
SEQUENCER_P2P_MULTIADDR="${SEQUENCER_P2P_MULTIADDR:-}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "$L1_RPC_URL" ] || [ -z "$SEQUENCER_P2P_MULTIADDR" ]; then
  echo "ERROR: set L1_RPC_URL and SEQUENCER_P2P_MULTIADDR first."
  echo "  Ask the chain operator for L1 RPC access and the sequencer p2p multiaddr."
  echo "  export L1_RPC_URL=http://<LENGHAO_TAILSCALE_IP>:8545"
  echo "  export SEQUENCER_P2P_MULTIADDR=/ip4/<SEQUENCER_IP>/tcp/9222/p2p/<SEQUENCER_PEER_ID>"
  exit 1
fi

echo "=== eterna-node install -> $ETERNA_HOME ==="
mkdir -p "$ETERNA_HOME"/{bin,config,logs,l2-data,op-node-data}
cp -r "$REPO_DIR/config" "$ETERNA_HOME/" 2>/dev/null || true
cp -r "$REPO_DIR/genesis" "$ETERNA_HOME/" 2>/dev/null || true
cp -r "$REPO_DIR/scripts" "$REPO_DIR/systemd" "$REPO_DIR/monitoring" "$REPO_DIR/heartbeat" "$ETERNA_HOME/" 2>/dev/null || true

# --- system deps (Debian/Ubuntu) ---
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq curl git build-essential python3 openssl jq >/dev/null
fi

# --- build binaries (skipped if already present) ---
export ETERNA_HOME
bash "$REPO_DIR/scripts/build-op-stack.sh"

# --- init datadir from genesis (release attachment) ---
GENESIS_JSON="$REPO_DIR/genesis/genesis.json"
if [ ! -f "$GENESIS_JSON" ]; then GENESIS_JSON="$ETERNA_HOME/genesis/genesis.json"; fi
if [ ! -f "$GENESIS_JSON" ]; then
  echo "ERROR: genesis.json not found. Download it from the GitHub release"
  echo "  (v0.1.0 assets) and place it at $REPO_DIR/genesis/genesis.json, then re-run."
  exit 1
fi
if [ ! -d "$ETERNA_HOME/l2-data/geth" ]; then
  echo "--- op-geth init (genesis)"
  "$ETERNA_HOME/bin/op-geth" --datadir "$ETERNA_HOME/l2-data" init "$GENESIS_JSON"
else
  echo "--- datadir already initialised, skipping init"
fi

# --- keys (generate once, 0600, never committed) ---
if [ ! -f "$ETERNA_HOME/config/jwt.txt" ]; then
  openssl rand -hex 32 > "$ETERNA_HOME/config/jwt.txt"
  chmod 600 "$ETERNA_HOME/config/jwt.txt"
  echo "--- generated config/jwt.txt"
fi
if [ ! -f "$ETERNA_HOME/config/p2p-priv.txt" ]; then
  openssl rand -hex 32 > "$ETERNA_HOME/config/p2p-priv.txt"
  chmod 600 "$ETERNA_HOME/config/p2p-priv.txt"
  echo "--- generated config/p2p-priv.txt"
fi

# --- systemd units ---
sudo cp "$REPO_DIR/systemd/op-geth-l2.service" "$REPO_DIR/systemd/op-node.service" /etc/systemd/system/
sudo sed -i "s|%ETERNA_HOME%|$ETERNA_HOME|g; s|%L1_RPC_URL%|$L1_RPC_URL|g; s|%SEQUENCER_P2P_MULTIADDR%|$SEQUENCER_P2P_MULTIADDR|g" \
  /etc/systemd/system/op-geth-l2.service /etc/systemd/system/op-node.service
sudo systemctl daemon-reload
sudo systemctl enable op-geth-l2.service op-node.service
sudo systemctl restart op-geth-l2.service
sleep 5
sudo systemctl restart op-node.service
echo "=== install done. Check status: bash $ETERNA_HOME/scripts/status.sh ==="
