#!/bin/bash
# gate-rollcall.sh — the gate's ROLL CALL: every check it RAN, by name, machine-readable.
# Sourceable library. Born P14, 2026-09-08 (opus-feynmanSync-10), from feynmanSync-09's catch.
#
# ── WHY THIS EXISTS ───────────────────────────────────────────────────────────────────
# -09 tried to answer "which gate checks only ever run on ONE box?" by diffing the two
# boxes' gate LOGS. G-AK appeared 2x in feynman's log and 0x in darwin's, which reads as
# "never runs on darwin" — the inverse of the truth. gate-selfcheck.sh prints G-AK's header
# only in its rc=1 and rc=2 branches, so zero occurrences on darwin meant THE CENSUS PASSED.
#
#   A check that passes quietly and a check that never ran are INDISTINGUISHABLE in gate
#   output — in the one direction that matters. Every box-coverage census built on that
#   output systematically reads "passed" as "never ran".
#
# The header cannot be the instrument, and that is structural rather than an oversight:
# measured 2026-09-08, gate-selfcheck.sh holds 101 `bold "=== ..."` header lines for ~39
# check ids, 62 of them indented inside a branch. The header is a VERDICT RENDERING
# DEVICE — it fires per-branch, so a check appears 0, 1 or 2 times depending on how it
# went. That is exactly the artifact -09 measured.
#
# So the roll call records REACH, at the top of each check, BEFORE any branching, and it
# records it whether the check goes green, red or silent. The verdict is resolved
# separately at emit time from the gate's own FAILS/WARNS/SKIPPED arrays, so this library
# never has to be told an answer twice.
#
# ── THE FLAG QUESTION, ANSWERED ───────────────────────────────────────────────────────
# -09 left the first decision open: a `--roll-call` flag, or an always-on sidecar? It is
# the sidecar, and the flag is only a VIEW of it. A flag would mean the roll call is
# produced by a DIFFERENT run than the one whose output you are reading — inferring what
# a real run did from a rehearsal, which is the same disease one layer out. Opt-in
# instruments also get forgotten (Jason: unarmed flags get forgotten). Recording is
# unconditional; `gate-selfcheck.sh --roll-call` just prints the table a run wrote anyway.
#
# ── THE CONTRACT ──────────────────────────────────────────────────────────────────────
# Six states, and NOT-REACHED is the one the whole thing exists for:
#   pass         reached, and no FAIL/WARN/SKIP entry carries its id
#   warn / fail  reached, and the gate's own arrays say so
#   skipped      reached, and an upstream step could not verify
#   n/a          reached, and it has no subject on this box (a ROUTING fact, not rot)
#   NOT-REACHED  declared in the manifest, and the run never got to it  ← the whole point
#   UNDECLARED   pushed a FAIL/WARN under an id no manifest row declares ← reverse closure
#
# Both directions are closed on purpose. Forward: a declared check that stops running is
# named. Reverse: a check added without a manifest row is named. A one-directional roll
# call would let a new check be invisible in the exact way G-AK was.
#
# ── PORTABILITY ───────────────────────────────────────────────────────────────────────
# darwin ships bash 3.2: NO associative arrays, no `mapfile`, no `${var^^}`. The seen-set
# is a space-sentinelled string, the same idiom gate-selfcheck.sh already uses for REPOS.
# `${arr[@]}` on an EMPTY array is an unbound-variable error under `set -u` in bash 3.2,
# so every array read here is guarded by its own `${#arr[@]}` first.
#
# ── FAIL-SAFE ─────────────────────────────────────────────────────────────────────────
# The roll call is an OBSERVER. It must never change a gate verdict: a broken sidecar
# writer that failed the wrap would be a control whose only exits are vandalism or
# dishonesty, which this estate has already learned gets ignored. Every emit path is
# guarded, and a manifest that cannot be read produces a sidecar SAYING SO rather than a
# silent empty one — three states, never collapsed into two.

GATE_ROLLCALL_LIB_VERSION="1.1"

# --- fingerprint the manifest, portably ------------------------------------------------
# gate-coverage.sh refuses to join sidecars measured against DIFFERENT manifests, because
# two boxes scored on different check lists produce a table full of confident, meaningless
# differences. v1.0 compared the manifest's BASENAME, which is not a comparison at all --
# every box calls it gate-checks.manifest, and one of them being three commits behind looks
# identical. Record a real fingerprint. Ladder because no single tool is on both boxes:
# sha256sum is GNU, shasum ships with macOS perl, and cksum is POSIX on both (CRC32+size --
# weak against an adversary, entirely adequate against "is this the same file").
_rc_manifest_fp() {   # <path> -> "<algo>:<digest>" or "none"
  [ -r "${1:-}" ] || { printf 'none
'; return 0; }
  if command -v sha256sum >/dev/null 2>&1; then
    printf 'sha256:%s
' "$(sha256sum "$1" 2>/dev/null | cut -c1-16)"
  elif command -v shasum >/dev/null 2>&1; then
    printf 'sha256:%s
' "$(shasum -a 256 "$1" 2>/dev/null | cut -c1-16)"
  else
    printf 'cksum:%s
' "$(cksum "$1" 2>/dev/null | awk '{print $1"-"$2}')"
  fi
}

GATE_ROLL_SEEN=" "        # space-sentinelled set of ids reached this run
GATE_ROLL_NA=""           # "<id>\t<why>" lines, for checks with no subject on this box

# --- which box is this? ---------------------------------------------------------------
# estate-boxes.txt is the fleet SSOT and names boxes darwin/feynman; `hostname -s` answers
# mbp2024. A cross-box join needs the ESTATE name, so resolve it from the SSOT and say so
# when we could not: a fallback name is still a name, but a reader must be able to tell.
_rc_box_name() {
  if [ -n "${GATE_BOX:-}" ]; then printf '%s\t%s\n' "$GATE_BOX" "env"; return 0; fi
  local _f="${ESTATE_BOXES:-$HOME/Scripts/estate-boxes.txt}"
  local _u _os _hit _n
  _u="$(id -un 2>/dev/null || echo '')"
  _os="$(uname -s 2>/dev/null | tr 'A-Z' 'a-z')"
  if [ -r "$_f" ] && [ -n "$_u" ] && [ -n "$_os" ]; then
    _hit="$(awk -v u="user=$_u" -v o="os=$_os" '
      /^[[:space:]]*#/ {next} NF==0 {next}
      { hu=0; ho=0; for(i=2;i<=NF;i++){ if($i==u) hu=1; if($i==o) ho=1 }
        if(hu && ho) print $1 }' "$_f" 2>/dev/null)"
    _n="$(printf '%s\n' "$_hit" | grep -c . 2>/dev/null || echo 0)"
    if [ "${_n:-0}" = "1" ]; then printf '%s\tssot\n' "$_hit"; return 0; fi
  fi
  printf '%s\tfallback\n' "$(hostname -s 2>/dev/null || uname -n 2>/dev/null || echo unknown)"
}

# --- record that a check was REACHED --------------------------------------------------
# Call ONCE at the top of each check, before any `if`. Idempotent: a check that loops or
# is re-entered still occupies exactly one manifest row, because a roll call that
# double-counts is the 2x-on-feynman artifact wearing a new hat.
gate_ran() {
  [ -n "${1:-}" ] || return 0
  case "$GATE_ROLL_SEEN" in *" $1 "*) return 0 ;; esac
  GATE_ROLL_SEEN="$GATE_ROLL_SEEN$1 "
}

# --- record that a check was reached but has NO SUBJECT here --------------------------
# n/a is a ROUTING fact (this box holds a subset of the estate; this platform has no TCC),
# and it is emphatically NOT the same as NOT-REACHED. Collapsing them would re-create the
# ambiguity this file exists to remove, one level in.
gate_ran_na() {
  [ -n "${1:-}" ] || return 0
  gate_ran "$1"
  GATE_ROLL_NA="${GATE_ROLL_NA}$1	${2:-no subject on this box}
"
}

# --- the head id of a gate message ----------------------------------------------------
# The gate writes "<id>: ..." or "<id> CANNOT VERIFY: ...", so the id is everything up to
# the first ':' or space. No prefix guessing anywhere in this file: a message belongs to
# the row the MANIFEST says it belongs to, and to nothing otherwise. Prefix inference is
# how "G-A" would silently answer for "G-AB" — a confident wrong owner, which is the
# family of bug this whole instrument exists to stop reproducing.
_rc_head() {   # <message> -> id, or empty
  printf '%s\n' "$1" | sed -n '1s/^\(G-[A-Za-z0-9#]*\)[: ].*/\1/p'
}

_rc_join() {   # join "$@" one per line, empty-safe under set -u
  [ "$#" -gt 0 ] || return 0
  printf '%s\n' "$@"
}

# --- emit the sidecar -----------------------------------------------------------------
# Reads the gate's own FAILS / WARNS / SKIPPED arrays (this library is SOURCED into the
# gate, so they are in scope) and the manifest. Writes TSV. Never returns non-zero.
#
# MANIFEST FORMAT — three tab-separated columns:
#   <id>  <parent>  <what it checks>
# parent "-" means the row is a REACH UNIT: a place `gate_ran` is called, one per check.
# Any other parent means the row is a VERDICT ALIAS — a label the gate speaks under from
# inside a reach unit's branches (G-AL#board lives inside G-AL). Aliases are declared
# rather than inferred, so the roll call never has to guess who spoke.
gate_rollcall_emit() {
  {
    local _dir _mf _box _boxsrc _bl _stamp _out _latest _line
    _dir="${GATE_ROLLCALL_DIR:-$HOME/.cache/gate-rollcall}"
    _mf="${GATE_CHECKS_MANIFEST:-$(dirname "${_GATE_SELF:-$0}")/gate-checks.manifest}"
    _bl="$(_rc_box_name)"; _box="${_bl%%	*}"; _boxsrc="${_bl##*	}"
    _stamp="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || echo unknown)"
    mkdir -p "$_dir" 2>/dev/null || { echo "gate-rollcall: cannot write $_dir" >&2; return 0; }
    _out="$_dir/$_box-$_stamp.tsv"; _latest="$_dir/$_box.tsv"

    {
      echo "# gate roll call — every check this run REACHED, and what became of it."
      echo "# lib=$GATE_ROLLCALL_LIB_VERSION box=$_box box_resolved_by=$_boxsrc utc=$_stamp"
      echo "# manifest=$_mf"
      echo "# manifest_fp=$(_rc_manifest_fp "$_mf") units_declared=$(awk -F'\t' '!/^#/ && NF>=2 && $2=="-"' "$_mf" 2>/dev/null | grep -c . || echo 0)"
      echo "# NOT-REACHED = declared and never reached. UNDECLARED = spoke without a manifest row."
      printf '#id\tstate\tnote\n'
    } > "$_out" 2>/dev/null || { echo "gate-rollcall: cannot write $_out" >&2; return 0; }

    if [ ! -r "$_mf" ]; then
      # Fail LOUD-but-harmless: a sidecar that says it could not read its manifest is
      # honest; an empty one would read as "the gate ran no checks", which is a lie in
      # exactly the direction this file exists to prevent.
      printf 'MANIFEST-UNREADABLE\tcannot-verify\t%s is missing or unreadable — this run has NO roll call, which is not the same as a run with no checks\n' "$_mf" >> "$_out"
      cp "$_out" "$_latest" 2>/dev/null || true
      printf '%s\n' "$_out"
      return 0
    fi

    # --- read the manifest: units (parent "-") in order, and alias->parent -------------
    local _units _aliasmap _id _par
    _units=""; _aliasmap=""
    while IFS= read -r _line; do
      case "$_line" in ''|'#'*) continue ;; esac
      _id="${_line%%	*}"; _line="${_line#*	}"; _par="${_line%%	*}"
      [ -n "$_id" ] || continue
      if [ "$_par" = "-" ]; then
        _units="$_units$_id
"
      else
        _aliasmap="$_aliasmap$_id	$_par
"
      fi
    done < "$_mf"

    # --- attribute every message this run produced to a reach unit --------------------
    # <owner>\t<state> lines. Worst state wins later: fail > skipped > warn.
    local _owned _sev _msg _head _owner
    _owned=""
    # NA is the gate's own array, same as the other three: gate_na pushes "<id> N/A: <why>".
    # Reading it here rather than asking checks to announce n/a twice keeps ONE source of
    # truth per state — a second place to declare n/a is a second place for it to rot.
    for _sev in fail warn skipped na; do
      case "$_sev" in
        fail)    [ "${#FAILS[@]}"   -gt 0 ] 2>/dev/null || continue; set -- "${FAILS[@]}" ;;
        warn)    [ "${#WARNS[@]}"   -gt 0 ] 2>/dev/null || continue; set -- "${WARNS[@]}" ;;
        skipped) [ "${#SKIPPED[@]}" -gt 0 ] 2>/dev/null || continue; set -- "${SKIPPED[@]}" ;;
        na)      [ "${#NA[@]}"      -gt 0 ] 2>/dev/null || continue; set -- "${NA[@]}" ;;
      esac
      for _msg in "$@"; do
        _head="$(_rc_head "$_msg")"
        [ -n "$_head" ] || continue
        _owner=""
        case "
$_units" in *"
$_head
"*) _owner="$_head" ;; esac
        if [ -z "$_owner" ]; then
          _owner="$(printf '%s' "$_aliasmap" | sed -n "s/^$_head	//p" | head -1)"
        fi
        if [ -z "$_owner" ]; then
          _owned="$_owned$_head	UNDECLARED
"
        else
          _owned="$_owned$_owner	$_sev
"
        fi
      done
    done

    # --- one row per reach unit, in manifest order ------------------------------------
    local _state _note
    while IFS= read -r _id; do
      [ -n "$_id" ] || continue
      _note=""
      if   printf '%s' "$_owned" | grep -q "^$_id	fail$";    then _state="fail"
      elif printf '%s' "$_owned" | grep -q "^$_id	skipped$"; then _state="skipped"
      elif printf '%s' "$_owned" | grep -q "^$_id	warn$";    then _state="warn"
      elif printf '%s' "$_owned" | grep -q "^$_id	na$";      then _state="n/a"
      elif printf '%s' "$GATE_ROLL_NA" | grep -q "^$_id	"; then
        _state="n/a"; _note="$(printf '%s' "$GATE_ROLL_NA" | sed -n "s/^$_id	//p" | head -1)"
      else
        case "$GATE_ROLL_SEEN" in
          *" $_id "*) _state="pass"; _note="reached; silent" ;;
          *) _state="NOT-REACHED"
             _note="declared in the manifest and never reached this run — a silent pass and a skipped check are NOT the same fact" ;;
        esac
      fi
      printf '%s\t%s\t%s\n' "$_id" "$_state" "$_note" >> "$_out"
    done <<UNITS
$_units
UNITS

    # --- reverse closure: anything that spoke without a manifest row ------------------
    printf '%s' "$_owned" | grep '	UNDECLARED$' | sort -u | while IFS='	' read -r _id _; do
      [ -n "$_id" ] || continue
      printf '%s\tUNDECLARED\tthis id reported a verdict but no manifest row declares it — add a row, or the next box-coverage census cannot see it\n' "$_id" >> "$_out"
    done

    # --- reached but not declared at all (an instrumented check with no row) ----------
    for _id in $GATE_ROLL_SEEN; do
      case "
$_units" in *"
$_id
"*) continue ;; esac
      printf '%s\tUNDECLARED\treached (gate_ran fired) but no manifest row declares it — the roll call can see it, a census reading the manifest cannot\n' "$_id" >> "$_out"
    done

    cp "$_out" "$_latest" 2>/dev/null || true
    printf '%s\n' "$_out"
  } 2>/dev/null || true
  return 0
}

# --- the VIEW (what `--roll-call` prints) ---------------------------------------------
gate_rollcall_print() {   # [tsv-path]
  local _f="${1:-${GATE_ROLLCALL_DIR:-$HOME/.cache/gate-rollcall}/$(_rc_box_name | cut -f1).tsv}"
  if [ ! -r "$_f" ]; then
    echo "gate roll call: no sidecar at $_f — run the gate once; it writes one every time." >&2
    return 2
  fi
  echo "── gate roll call · $_f ──"
  grep '^#' "$_f" | sed 's/^/  /'
  awk -F'\t' '!/^#/ && NF>=2 { printf "  %-16s %-12s %s\n", $1, $2, substr($3,1,88) }' "$_f"
  local _bad
  _bad="$(awk -F'\t' '!/^#/ && ($2=="NOT-REACHED" || $2=="UNDECLARED" || $2=="cannot-verify")' "$_f" | grep -c . || true)"
  echo "  ── $_bad row(s) the coverage question cares about ──"
  return 0
}
