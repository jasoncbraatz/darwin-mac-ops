#!/usr/bin/env bash
# FROZEN RULER for smDrainGate2 — lives in THIS repo ON PURPOSE.
#
# WHY IT IS NOT just `verify-smdrain.sh gate2`: rail.py's ruler_digest() hashes the
# verify_cmd line plus every file that line NAMES *and that resolves under this repo*.
# The blackbook verifier is an absolute path outside this repo, and the manifest is named
# by lane-id, not by path — so BOTH fall out of the digest. Measured 2026-09-04 by
# opus-smDrainDesk-02: all 11 smDrain ruler rows from the 09-03 drain froze with files={},
# and an empty files_json is indistinguishable from "this ruler has no file inputs".
# Corroborates leaves 2026-09-04-freezing-acceptance-command-freezing-acceptance-criteria
# and 2026-09-04-smdrainmail-4-rail-py-s-ruler.
#
# This shim IS inside the repo, so it IS digested. It pins the manifest's sha256, which
# makes narrowing the manifest a LOUD ruler-moved instead of a silent pass (the smDrainWisdom
# false complete, 48327fb1). `smdrain-lane.py park` is unaffected: it writes parked-gate2.json.
set -euo pipefail
LANE=gate2
MANIFEST="$HOME/repos/claude-blackbook/state/smdrain/lane-$LANE.json"
FROZEN_SHA=b271acb1dc964b9f1edc9fad669427a8a6cc723632afa750845f88f82000a5dd
[ -f "$MANIFEST" ] || { echo "RULER BROKEN: manifest $MANIFEST is missing (that is not a failing lane, it is a missing instrument)"; exit 2; }
GOT=$(shasum -a 256 "$MANIFEST" | awk '{print $1}')
if [ "$GOT" != "$FROZEN_SHA" ]; then
  echo "RULER MOVED: lane-$LANE.json sha256"
  echo "  frozen at rail-on : $FROZEN_SHA"
  echo "  on disk now       : $GOT"
  echo "The manifest IS the acceptance criteria. A worker may not narrow it; a CEO amends"
  echo "with rail.py ruler amend --project smDrainGate2 --by ceo --why '<why>' and re-pins this file."
  exit 2
fi
exec bash "$HOME/repos/claude-blackbook/scripts/verify-smdrain.sh" "$LANE"
