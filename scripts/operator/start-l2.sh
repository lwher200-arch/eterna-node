#!/bin/bash
# OPERATOR ONLY: L2 services (op-node sequencer + op-batcher + op-proposer).
# L2 op-geth must already be running (l2-geth.log, RPC 9545, authrpc 9551).
# Private keys are passed via env vars (not --private-key) so they do not
# appear in the process list. Replace <LENGHAO_TAILSCALE_IP> first.
# Usage: bash start-l2.sh [node|batcher|proposer|all]
set -u
W="${ETERNA_HOME:-$HOME/eterna-chain-local/opstack-local}"
export PATH=$W/bin:$PATH
ROLE=${1:-all}

# p2p private key (generate once, reuse)
if [ ! -f $W/config/p2p-priv.txt ]; then
  openssl rand -hex 32 > $W/config/p2p-priv.txt
  chmod 600 $W/config/p2p-priv.txt
fi

start_node() {
  # p2p gossip signing key via env (never in ps output)
  OP_NODE_P2P_SEQUENCER_KEY=$(cat $W/keys/sequencer.key | sed 's/^0x//') \
  setsid $W/bin/op-node \
    --l1 http://<LENGHAO_TAILSCALE_IP>:8545 \
    --l2 http://127.0.0.1:9551 \
    --rollup.config $W/deploy/rollup.json \
    --rollup.l1-chain-config $W/config/l1-chain-config.json \
    --l1.beacon.ignore \
    --rpc.addr 127.0.0.1 --rpc.port 8547 --rpc.enable-admin \
    --l2.jwt-secret $W/config/jwt.txt \
    --l2.enginekind geth \
    --sequencer.enabled --sequencer.l1-confs 1 --verifier.l1-confs 1 \
    --l1.trustrpc --l1.rpckind basic \
    --p2p.priv.path $W/config/p2p-priv.txt \
    --p2p.listen.ip <LENGHAO_TAILSCALE_IP> --p2p.listen.tcp 9222 --p2p.listen.udp 9222 --p2p.advertise.ip <LENGHAO_TAILSCALE_IP> \
    --p2p.peerstore.path $W/op-node-data/peerstore \
    > $W/logs/op-node.log 2>&1 < /dev/null &
  echo "op-node pid $!"
}

start_batcher() {
  OP_BATCHER_PRIVATE_KEY=$(cat $W/keys/batcher.key | sed 's/^0x//') \
  setsid $W/bin/op-batcher \
    --l1-eth-rpc http://<LENGHAO_TAILSCALE_IP>:8545 \
    --l2-eth-rpc http://127.0.0.1:9545 \
    --rollup-rpc http://127.0.0.1:8547 \
    --data-availability-type calldata \
    --max-channel-duration 60 \
    --rpc.addr 127.0.0.1 --rpc.port 8548 \
    --poll-interval 6s \
    > $W/logs/op-batcher.log 2>&1 < /dev/null &
  echo "op-batcher pid $!"
}

start_proposer() {
  OP_PROPOSER_PRIVATE_KEY=$(cat $W/keys/proposer.key | sed 's/^0x//') \
  setsid $W/bin/op-proposer \
    --l1-eth-rpc http://<LENGHAO_TAILSCALE_IP>:8545 \
    --rollup-rpc http://127.0.0.1:8547 \
    --game-factory-address 0x4ca4318203a08073292dfea8ad49cb8f5ae8ae89 \
    --game-type 1 \
    --allow-non-finalized \
    --rpc.addr 127.0.0.1 --rpc.port 8549 \
    --proposal-interval 12s \
    --poll-interval 12s \
    > $W/logs/op-proposer.log 2>&1 < /dev/null &
  echo "op-proposer pid $!"
}

case $ROLE in
  node) start_node ;;
  batcher) start_batcher ;;
  proposer) start_proposer ;;
  all) start_node; sleep 2; start_batcher; sleep 2; start_proposer ;;
  *) echo "usage: $0 [node|batcher|proposer|all]" ;;
esac
