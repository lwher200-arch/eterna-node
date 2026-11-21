#!/bin/bash
# Build op-node (optimism monorepo) + op-geth from source.
# No linux-amd64 prebuilt binaries are published for these releases
# (verified 404, 2026-11-16), so source build is the only path.
# Proven on lenghao 2026-11-16: optimism @ op-node/v1.20.1 via `just`,
# op-geth @ v1.101702.4-rc.1 via `make geth`. Go 1.27.4.
# Reuses $ETERNA_HOME/src checkouts + module cache on re-run (fast rebuild).
set -u
W="${ETERNA_HOME:-$HOME/eterna-node}"
LOG="$W/logs/build-op-stack.log"
mkdir -p "$W/bin" "$W/logs" "$W/src"
echo "=== build-op-stack start $(date -u +%FT%TZ) ===" | tee -a "$LOG"
export GOMAXPROCS="${GOMAXPROCS:-4}"
export GOTOOLCHAIN=local
export GOCACHE="$W/src/gocache" GOPATH="$W/src/gopath"
export GOPROXY="${GOPROXY:-https://proxy.golang.org,direct}"
export GOSUMDB=off

# --- Go 1.27.4 (official tarball) ---
if [ ! -x "$W/go/bin/go" ]; then
  echo "--- downloading Go 1.27.4" | tee -a "$LOG"
  curl -sSL -o /tmp/go1.27.4.linux-amd64.tar.gz https://go.dev/dl/go1.27.4.linux-amd64.tar.gz
  tar -C "$W" -xzf /tmp/go1.27.4.linux-amd64.tar.gz
  rm -f /tmp/go1.27.4.linux-amd64.tar.gz
fi
export PATH="$W/go/bin:$PATH"
"$W/go/bin/go" version | tee -a "$LOG"

# --- just (prebuilt musl static; needed by the optimism justfile) ---
if [ ! -x "$W/bin/just" ]; then
  echo "--- downloading just" | tee -a "$LOG"
  TAG=$(curl -s https://api.github.com/repos/casey/just/releases/latest | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")
  curl -sSL -o /tmp/just.tar.gz "https://github.com/casey/just/releases/download/$TAG/just-${TAG}-x86_64-unknown-linux-musl.tar.gz"
  tar -C /tmp -xzf /tmp/just.tar.gz just
  cp /tmp/just "$W/bin/just"
  chmod +x "$W/bin/just"
fi
"$W/bin/just" --version | tee -a "$LOG"

# --- optimism monorepo: op-node (op-batcher/op-proposer NOT built here:
# a verifier node does not run them) ---
if [ ! -x "$W/bin/op-node" ]; then
  echo "--- cloning optimism @ op-node/v1.20.1" | tee -a "$LOG"
  [ -d "$W/src/optimism" ] || git clone --depth 1 --branch op-node/v1.20.1 https://github.com/ethereum-optimism/optimism.git "$W/src/optimism"
  cd "$W/src/optimism" || exit 1
  echo "--- build-superchain-go (generates superchain-configs.zip)" | tee -a "$LOG"
  "$W/bin/just" build-superchain-go >>"$LOG" 2>&1
  echo "--- building op-node" | tee -a "$LOG"
  # If proxy.golang.org is very slow, retry with GOPROXY=direct,https://proxy.golang.org
  "$W/bin/just" op-node >>"$LOG" 2>&1
  cp op-node/bin/op-node "$W/bin/"
fi
"$W/bin/op-node" --version | tee -a "$LOG"

# --- op-geth: v1.101702.4-rc.1 (NOT v1.101702.3: it lacks Engine API V5,
# op-node getPayloadV5 fails with "Unsupported fork") ---
if [ ! -x "$W/bin/op-geth" ]; then
  echo "--- cloning op-geth @ v1.101702.4-rc.1" | tee -a "$LOG"
  [ -d "$W/src/op-geth" ] || git clone --depth 1 --branch v1.101702.4-rc.1 https://github.com/ethereum-optimism/op-geth.git "$W/src/op-geth"
  cd "$W/src/op-geth" || exit 1
  echo "--- building op-geth (make geth)" | tee -a "$LOG"
  make geth >>"$LOG" 2>&1
  cp build/bin/geth "$W/bin/op-geth"
fi
"$W/bin/op-geth" version 2>&1 | head -5 | tee -a "$LOG"

echo "=== build-op-stack done $(date -u +%FT%TZ) ===" | tee -a "$LOG"
ls -la "$W/bin/"
