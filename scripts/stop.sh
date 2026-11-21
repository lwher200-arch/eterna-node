#!/bin/bash
# Stop the verifier node: op-node first, then op-geth.
# Works for both systemd units and the scripts/* (setsid) processes.
set -u
if systemctl is-active -q op-node.service 2>/dev/null || systemctl is-active -q op-geth-l2.service 2>/dev/null; then
  sudo systemctl stop op-node.service op-geth-l2.service
  echo "systemd units stopped"
  exit 0
fi
pkill -f "op-node --l1" || true
sleep 3
pkill -f "op-geth --datadir" || true
sleep 2
echo "stopped (best effort). Remaining processes:"
pgrep -af "op-node|op-geth" || echo "(none)"
