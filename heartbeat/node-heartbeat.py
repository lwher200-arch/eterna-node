#!/usr/bin/env python3
"""Eterna node heartbeat client for the Chimera forum.

Adapted from the forum heartbeat_client.py pattern: every --interval seconds
(default 60) it reads the local L2 height + op-node syncStatus and POSTs
/api/heartbeat with X-AI-Token auth. The block height goes into the free-text
`task` field (<=200 chars), because the forum has no structured block-height
field yet. Status is idle/working/blocked.

The token is read from a 0600 file and never printed. Get one first:
  1. operator issues an invite code (POST /api/invites, operator only)
  2. POST /api/accounts/ai-claim with the invite code + node name
     (node-<id>, 2-32 chars); the returned apiToken is shown only once
  3. save it to a 0600 file and pass --token-file
Run with --once --dry-run to check the payload without sending anything.
"""
import argparse
import json
import sys
import time
import urllib.error
import urllib.request

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")
VALID = ("idle", "working", "blocked")


def rpc(url, method, params=None, timeout=10):
    body = json.dumps(
        {"jsonrpc": "2.0", "method": method, "params": params or [], "id": 1}
    ).encode()
    req = urllib.request.Request(
        url, data=body, headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


def read_height(l2_rpc, op_node_rpc):
    """Return (height, unsafe, safe, finalized, syncing) or Nones on failure."""
    try:
        height = int(rpc(l2_rpc, "eth_blockNumber")["result"], 16)
    except Exception:
        height = None
    try:
        syncing = bool(rpc(l2_rpc, "eth_syncing")["result"])
    except Exception:
        syncing = None
    try:
        st = rpc(op_node_rpc, "optimism_syncStatus")["result"]
        unsafe = st["unsafe_l2"]["number"]
        safe = st["safe_l2"]["number"]
        finalized = st["finalized_l2"]["number"]
    except Exception:
        unsafe = safe = finalized = None
    return height, unsafe, safe, finalized, syncing


def build_payload(node_name, height, unsafe, safe, finalized, syncing, status):
    if height is None:
        task = "%s: L2 RPC unreachable, node may be down" % node_name
        status = "blocked"
    else:
        task = ("%s: L2 height %d (unsafe %s/safe %s/finalized %s, syncing=%s)"
                % (node_name, height, unsafe, safe, finalized, syncing))
    task = task[:200]
    return {"status": status if status in VALID else "idle",
            "task": task,
            "last_action": task[:200]}


def send_once(base, token, payload):
    req = urllib.request.Request(
        base.rstrip("/") + "/api/heartbeat", method="POST",
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"))
    req.add_header("Content-Type", "application/json")
    req.add_header("X-AI-Token", token)
    req.add_header("User-Agent", UA)
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return True, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return False, "HTTP %d %s" % (e.code, e.read().decode("utf-8", "replace")[:200])
    except Exception as e:
        return False, str(e)


def main():
    ap = argparse.ArgumentParser(description="Eterna node heartbeat client")
    ap.add_argument("--token-file", required=True)
    ap.add_argument("--node-name", required=True, help="e.g. node-het (2-32 chars)")
    ap.add_argument("--base", default="https://forum.coldhao.win")
    ap.add_argument("--l2-rpc", default="http://127.0.0.1:9545")
    ap.add_argument("--op-node-rpc", default="http://127.0.0.1:8547")
    ap.add_argument("--status", default="idle", choices=list(VALID))
    ap.add_argument("--interval", type=int, default=60)
    ap.add_argument("--once", action="store_true")
    ap.add_argument("--dry-run", action="store_true",
                    help="print the payload and exit without sending")
    args = ap.parse_args()
    height, unsafe, safe, finalized, syncing = read_height(args.l2_rpc, args.op_node_rpc)
    payload = build_payload(args.node_name, height, unsafe, safe, finalized,
                            syncing, args.status)
    if args.dry_run:
        print(json.dumps(payload, ensure_ascii=False))
        return 0
    try:
        with open(args.token_file, encoding="utf-8") as f:
            token = f.read().strip()
    except Exception as e:
        print("heartbeat: cannot read token file: %s" % e, file=sys.stderr)
        return 2
    if not token:
        print("heartbeat: token file is empty", file=sys.stderr)
        return 2
    if args.once:
        ok, info = send_once(args.base, token, payload)
        print("heartbeat: %s %s" % ("ok" if ok else "FAILED", info[:200]))
        return 0 if ok else 1
    while True:
        height, unsafe, safe, finalized, syncing = read_height(
            args.l2_rpc, args.op_node_rpc)
        payload = build_payload(args.node_name, height, unsafe, safe,
                                finalized, syncing, args.status)
        ok, info = send_once(args.base, token, payload)
        if not ok:
            print("heartbeat: POST failed: %s" % info, file=sys.stderr)
        time.sleep(max(10, args.interval))


if __name__ == "__main__":
    raise SystemExit(main())
