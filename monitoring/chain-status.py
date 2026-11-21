#!/usr/bin/env python3
"""Generic Eterna node sync checker (adapted from the lenghao daily collector).

Reads local L2 height + eth_syncing, op-node optimism_syncStatus, and
optionally the sequencer's L2 height for a lag comparison. Prints a short
summary only: heights, sync state, lag. No tokens or keys are read.

Exit code: 0 = healthy, 1 = anomaly (RPC failure, syncing, lag > threshold).
"""
import argparse
import json
import sys
import urllib.error
import urllib.request

TIMEOUT = 10


def rpc(url, method, params=None):
    body = json.dumps(
        {"jsonrpc": "2.0", "method": method, "params": params or [], "id": 1}
    ).encode()
    req = urllib.request.Request(
        url, data=body, headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return json.loads(r.read().decode())


def block_number(url):
    return int(rpc(url, "eth_blockNumber")["result"], 16)


def main():
    ap = argparse.ArgumentParser(description="Eterna node sync checker")
    ap.add_argument("--l2-rpc", default="http://127.0.0.1:9545")
    ap.add_argument("--op-node-rpc", default="http://127.0.0.1:8547")
    ap.add_argument("--sequencer-rpc", default="",
                    help="sequencer L2 RPC for lag comparison, e.g. http://<HOST>:9545")
    ap.add_argument("--lag-threshold", type=int, default=5)
    args = ap.parse_args()

    problems = []
    try:
        height = block_number(args.l2_rpc)
    except Exception as e:
        print("L2 RPC FAILED: %s" % e)
        return 1
    try:
        syncing = bool(rpc(args.l2_rpc, "eth_syncing")["result"])
    except Exception:
        syncing = None
    try:
        st = rpc(args.op_node_rpc, "optimism_syncStatus")["result"]
        unsafe = st["unsafe_l2"]["number"]
        safe = st["safe_l2"]["number"]
        finalized = st["finalized_l2"]["number"]
    except Exception as e:
        print("op-node syncStatus FAILED: %s" % e)
        return 1

    print("L2 height: %d (eth_syncing=%s)" % (height, syncing))
    print("op-node: unsafe=%d safe=%d finalized=%d" % (unsafe, safe, finalized))
    if syncing:
        problems.append("L2 eth_syncing is true")
    if unsafe == 0 or safe == 0 or finalized == 0:
        problems.append("syncStatus not established yet (zeros)")
    if args.sequencer_rpc:
        try:
            ref = block_number(args.sequencer_rpc)
            lag = ref - height
            print("sequencer height: %d lag: %d" % (ref, lag))
            if abs(lag) > args.lag_threshold:
                problems.append("lag %d exceeds threshold %d" % (lag, args.lag_threshold))
        except Exception as e:
            print("sequencer RPC FAILED: %s" % e)
            problems.append("sequencer RPC unreachable")
    if problems:
        print("ANOMALY: " + "; ".join(problems))
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
