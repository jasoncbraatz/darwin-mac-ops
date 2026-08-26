#!/usr/bin/env bash
# estate-leakguard-drill.sh — prove the ESTATE pre-commit hook's identity layer refuses a
# staged credential this box actually holds. Uses a FAKE secret in a throwaway $HOME and
# installs nothing.
#
# It runs the hook DIRECTLY rather than through `git commit`, and copies only the three
# files under test into a temp hook dir with a stub `_chain.sh`. Driving a real commit
# was tried first and hangs: under a synthetic $HOME the downstream chain waits on state
# that only the real home has. That is a property of the fixture, not of the hook -- the
# hook is exercised on every commit this Mac makes -- but a drill that hangs is a drill
# nobody runs, so the unit under test is the unit that gets tested.
#
# Paths are resolved BEFORE any HOME=... prefix: bash applies command-prefix assignments
# left to right, so `HOME=$T TOOL=$HOME/x` silently points at nothing.
set -uo pipefail
SRC="${SRC:-$HOME/code/darwin-mac-ops/hooks}"; LG="${LG:-$HOME/Scripts/leakguard.py}"
R=$(mktemp -d); H=$(mktemp -d); K=$(mktemp -d); trap 'rm -rf "$R" "$H" "$K"' EXIT
FAKE="cfESTATEproof00000000000000000000000000000000000000"
mkdir -p "$H/.config/cloudflare"; printf '%s\n' "$FAKE" > "$H/.config/cloudflare/token"
cp "$SRC/pre-commit" "$SRC/secret-re.sh" "$K/"
printf '#!/bin/bash\nexit 0\n' > "$K/_chain.sh"; chmod +x "$K"/*
P=0; F=0
ok(){ P=$((P+1)); printf '  ok   %s\n' "$1"; }
no(){ F=$((F+1)); printf '  FAIL %s\n' "$1"; }
hook(){ ( cd "$R" && HOME="$H" ESTATE_LEAKGUARD="$1" bash "$K/pre-commit" 2>&1 ); }

cd "$R" && git init -q . && git config user.email t@t && git config user.name t

printf 'ordinary prose, nothing to see\n' > fine.md && git add fine.md
OUT=$(hook "$LG"); RC=$?
[ "$RC" -eq 0 ] && ok "a clean staged index passes" || { no "clean index blocked"; printf '%s\n' "$OUT" | sed 's/^/       /'; }

printf 'oops: %s\n' "$FAKE" > leak.md && git add leak.md
OUT=$(hook "$LG"); RC=$?
[ "$RC" -ne 0 ] && ok "a held credential in the index is BLOCKED" || no "the leak passed"
case "$OUT" in *"THIS BOX HOLDS"*) ok "the block explains itself";; *) no "the block explains itself";; esac
case "$OUT" in *"$FAKE"*) no "the hook must not echo the secret";; *) ok "the hook did not echo the secret";; esac
case "$OUT" in *"leakguard.py mask"*) ok "it says how to look at the file safely";; *) no "no safe-look instruction";; esac
case "$OUT" in *leak.md*) ok "it names the offending path";; *) no "it names the offending path";; esac

OUT=$(hook "$H/absent.py"); RC=$?
[ "$RC" -eq 0 ] && ok "a missing leakguard does not block the estate" || no "missing leakguard blocked"
case "$OUT" in *"identity layer inert"*) ok "...but it says so out loud";; *) no "inert layer was silent";; esac

git rm -q --cached leak.md >/dev/null 2>&1; rm -f leak.md
OUT=$(hook "$LG"); RC=$?
[ "$RC" -eq 0 ] && ok "unstaging the leak clears the block" || { no "still blocked after unstaging"; printf '%s\n' "$OUT" | sed 's/^/       /'; }

# negative control: the SHAPE layer must still be the one catching a shaped token
printf 'ghp_%s\n' "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" > gh.md && git add gh.md
OUT=$(hook "$H/absent.py"); RC=$?
[ "$RC" -ne 0 ] && ok "shape layer still blocks with the identity layer inert" || no "shape layer regressed"

echo "estate-leakguard-drill: $P passed, $F failed"
[ "$F" -eq 0 ] && { echo "ALL GREEN"; exit 0; } || exit 1
