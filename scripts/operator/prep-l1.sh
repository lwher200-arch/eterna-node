#!/bin/bash
# OPERATOR ONLY: generate fresh local role keys (l1-deployer, sequencer,
# batcher, proposer, challenger) with `cast wallet new`.
# The L1 genesis / datadir init step of the original script is NOT included
# here: it referenced an expired chainId-900 genesis that is not published.
# L1 deployment (genesis build + init) is an operator-side step; ask the
# chain operator for the current procedure.
set -u
W="${ETERNA_HOME:-$HOME/eterna-chain-local/opstack-local}"
export PATH=$W/bin:$PATH
mkdir -p $W/keys $W/config
cd $W || exit 1

for role in l1-deployer sequencer batcher proposer challenger; do
  if [ ! -f keys/$role.key ]; then
    echo "--- generating key: $role"
    # cast wallet new prints: "<address>\t<privateKey>" (no labels).
    OUT=$(cast wallet new 2>/dev/null)
    ADDR=$(echo "$OUT" | awk '{print $1}')
    PRIV=$(echo "$OUT" | awk '{print $2}')
    if ! echo "$ADDR" | grep -Eq '^0x[0-9a-fA-F]{40}$'; then echo "KEYGEN FAILED for $role (bad address)"; exit 1; fi
    if ! echo "$PRIV" | grep -Eq '^0x[0-9a-fA-F]{64}$'; then echo "KEYGEN FAILED for $role (bad key)"; exit 1; fi
    printf '%s' "$PRIV" > keys/$role.key
    printf '%s' "$ADDR" > keys/$role.addr
    chmod 600 keys/$role.key
    echo "  $role: $ADDR"
  else
    echo "--- key exists: $role $(cat keys/$role.addr)"
  fi
done
echo "--- keys ready. .addr files (public addresses) may be shared; .key files must never leave this host."
