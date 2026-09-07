#!/usr/bin/env bash
# gate-platform-na-drill.sh — the control on gate-selfcheck's PLATFORM exemption.
#
# WHY THIS EXISTS. A platform N/A is the cheapest possible way to switch a working check off:
# it turns a red into a quiet line, it looks principled, and nobody re-reads it. The estate has
# already been bitten by the softer version of this -- an exemption keyed on a flag silently
# disabled a whole warning, and the drill that caught it did so in one run (feynmanSync-05).
# So the exemption gets a control, and the control asserts BOTH directions:
#
#   Linux   -> the step is recorded N/A and its body is skipped   (the exemption works)
#   Darwin  -> the exemption declines and the body runs           (the check still fires)
#
# The second is the one that matters. A one-directional drill on an exemption proves only that
# it can hide things.
#
# It executes gate-selfcheck's OWN gate_platform_na by extracting the function text from the
# file, exactly as gate-charter-drill.sh does for gate_charter_is_na. Testing a copy would grade
# this drill's copy, not the gate.
set -uo pipefail
GATE="${GATE_SELFCHECK:-$HOME/Scripts/gate-selfcheck.sh}"
[ -r "$GATE" ] || { echo "gate-platform-na-drill: cannot read $GATE"; exit 2; }
pass=0; fail=0
ok()  { echo "  ok   $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1"; [ -n "${2:-}" ] && echo "       $2"; fail=$((fail+1)); }

# -- extract the real function (plus the gate_na it depends on) --------------------------
SRC="$(awk '/^gate_na\(\) \{/,/^\}/' "$GATE"; awk '/^gate_platform_na\(\) \{/,/^\}/' "$GATE")"
case "$SRC" in
  *gate_platform_na*) ok "extracted gate_platform_na from $GATE (not a copy)" ;;
  *) bad "could not extract gate_platform_na from $GATE" "the drill would otherwise grade its own copy"; echo; echo "gate-platform-na-drill: $pass passed, $fail failed"; exit 1 ;;
esac

# -- direction 1: a non-macOS kernel gets the N/A -----------------------------------------
OUT="$(NA=(); eval "$SRC"; if gate_platform_na "Linux" "G-ZZ" "no subject here"; then echo "RC0"; fi; printf '%s\n' "${NA[@]:-}")"
case "$OUT" in *RC0*) ok "Linux: the exemption fires (rc 0, caller skips the body)" ;; *) bad "Linux: the exemption did NOT fire" "$OUT" ;; esac
case "$OUT" in *"G-ZZ N/A: no subject here"*) ok "Linux: it is RECORDED as N/A, not silently dropped" ;; *) bad "Linux: nothing was recorded in NA[]" "$OUT" ;; esac

# -- direction 2 · THE CONTROL: macOS must NOT get it -------------------------------------
OUT2="$(NA=(); eval "$SRC"; if gate_platform_na "Darwin" "G-ZZ" "no subject here"; then echo "EXEMPTED"; else echo "RAN"; fi; printf 'NA=%s\n' "${#NA[@]}")"
case "$OUT2" in *RAN*) ok "Darwin: the exemption DECLINES — the real check still runs and can still go red" ;; *) bad "Darwin: the exemption fired on the platform that HAS the subject" "this is the off-switch failure mode; $OUT2" ;; esac
case "$OUT2" in *"NA=0"*) ok "Darwin: nothing recorded as N/A (the control)" ;; *) bad "Darwin: something was recorded as N/A" "$OUT2" ;; esac

# -- direction 3: an empty/garbled uname must NOT be read as macOS -------------------------
# fails toward MORE checking on macOS and toward N/A elsewhere is the wrong way round here:
# an unreadable uname on a Mac would silence a real check. But it also must not crash.
OUT3="$(NA=(); eval "$SRC"; if gate_platform_na "" "G-ZZ" "no subject here"; then echo "EXEMPTED"; else echo "RAN"; fi)"
case "$OUT3" in *EXEMPTED*) ok "empty uname: exempts rather than crashing (a garbled uname is not a Mac)" ;; *) bad "empty uname: did not exempt" "$OUT3" ;; esac

# -- direction 4: no env var can buy the exemption -----------------------------------------
# The whole point. If a session could export its way to N/A, this is an off-switch with a
# comment on it. grep the FILE, because the function signature alone cannot show this.
# CODE ONLY. The first cut of this check grepped the whole file and went red on the COMMENT
# above gate_platform_na, which says in as many words that GATE_FORCE_LINUX must not exist --
# i.e. it failed the gate for documenting the very property being asserted. Comments are
# stripped before the match, and the drill keeps its teeth: it looks for an env expansion
# reaching the exemption in executable text.
_code="$(grep -vE '^[[:space:]]*#' "$GATE")"
_hits="$(printf '%s\n' "$_code" | grep -nE 'FORCE_LINUX|FORCE_PLATFORM|GATE_UNAME|GATE_OS' || true)"
if [ -n "$(printf '%s' "$_hits" | tr -d '[:space:]')" ]; then
  bad "an env var reaches the platform exemption" "$(printf '%s\n' "$_hits" | head -3)"
else
  ok "no env var can assert the platform, in code (uname is passed in, only by the call sites)"
fi

# and the paired CONTROL: the stripping must not be so eager that it would miss a real one.
_decoy="$(printf 'x=1\nif [ "${GATE_FORCE_LINUX:-}" ]; then :; fi\n' | grep -vE '^[[:space:]]*#' | grep -cE 'FORCE_LINUX')"
if [ "${_decoy:-0}" -ge 1 ]; then ok "  ...and a decoy env var in live code WOULD still be caught (control)"
else bad "the comment-stripping also hides real code" "the check above is now decorative"; fi

# -- direction 5: every call site passes a MEASURED uname, never a literal -------------------
_sites="$(grep -n 'gate_platform_na ' "$GATE" | grep -v '^\s*#' | grep -v 'gate_platform_na() {')"
_n="$(printf '%s\n' "$_sites" | grep -c 'gate_platform_na ')"
_bad="$(printf '%s\n' "$_sites" | grep -v 'uname -s' || true)"
if [ -z "$(printf '%s' "$_bad" | tr -d '[:space:]')" ]; then
  ok "all $_n call site(s) pass \$(uname -s), none a hardcoded platform"
else
  bad "a call site hardcodes its platform" "$_bad"
fi

echo
echo "gate-platform-na-drill: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && { echo "the platform exemption fires where there is no subject, and DECLINES where there is."; exit 0; }
exit 1
