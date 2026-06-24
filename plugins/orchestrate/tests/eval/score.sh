#!/usr/bin/env bash
# Deterministic scorer for an effectiveness fixture (Tier 3c, Layer 2). Given a
# candidate repo dir and the held-out oracle, runs the VISIBLE suite (in the repo) and
# the HELD-OUT oracle (external, the implementer never saw it) and emits:
#   visible=<0|1> heldout=<0|1>
# heldout=1 is the real outcome signal (visible can be green on a broken result — that
# false confidence is the whole point of the fixture). No deps beyond python3.
set -uo pipefail
repo="${1:?usage: score.sh <repo-dir> <heldout-oracle.py>}"
oracle="${2:?usage: score.sh <repo-dir> <heldout-oracle.py>}"
v=0; ( cd "$repo" && python3 test_cart.py ) >/dev/null 2>&1 && v=1
h=0; python3 "$oracle" "$repo" >/dev/null 2>&1 && h=1
echo "visible=$v heldout=$h"
