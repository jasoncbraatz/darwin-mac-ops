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
# ── THE JUDGMENT HALF (v1.2, feynmanSync-11, 2026-09-08) ──────────────────────────────
# v1.1 closed both directions for the MECHANICAL half of the gate and was silent about the
# other half, which is the larger one nobody had counted. HANDOFF-GATE.md declares 53 ids;
# 51 reach units cover 29 of them. The remaining 19 subjects -- G-A "did we capture what
# happened", G-C "is what remains clear", G-D "did we VERIFY, not just assert", G-F "write
# the copy-paste prompt", G-G "improve the system itself", and fourteen more -- are walked
# by a session READING PROSE. Nothing recorded whether a session performed them.
#
#   A session that skipped G-D entirely and a session that ran it and found nothing
#   produced byte-identical evidence: none.
#
# That is the G-AK disease one layer out, and worse: G-AK at least rendered a header
# sometimes. So judgment steps get manifest rows (parent `judgment`) and three states of
# their own, and NOT ONE OF THEM IS `pass`, because nothing here grades an answer:
#
#   WITNESSED    the gate found the ARTIFACT this step is supposed to produce. Objective,
#                and deliberately NOT a prose regex -- a heading-shape guess would answer
#                "does this document contain a phrase I imagined", which is neither of the
#                two questions and would read as if it were both.
#   DECLARED     the session ASSERTED it performed the step (GATE_ANSWERED="G-C G-G").
#                Self-reported, and the word says so. An assertion recorded as an assertion
#                is worth something; an assertion recorded as a verdict is worth less than
#                nothing.
#   UNWITNESSED  no artifact, no assertion. Nobody can say whether this step happened.
#
# UNWITNESSED IS THE EXPECTED STATE TODAY AND THAT IS THE MEASUREMENT, not a red. Exactly
# one witness ships with v1.2 (G-F: its deliverable is a file, so its existence is checkable
# without guessing at anything). The other eighteen rows each carry, in the manifest's third
# column, a sentence naming what a witness for THAT step would be -- so the next session
# picks one up for the price of reading a row, instead of re-deriving this whole question.
#
# WHY NOT SIMPLY MECHANIZE THEM: most cannot be. "Is what remains crystal clear?" has no
# mechanical answer and pretending otherwise is how a guard that cannot fire gets built.
# The claim here is narrower and true: the gate can say whether anything witnessed the step,
# and that is strictly more than the nothing it could say before.
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

GATE_ROLLCALL_LIB_VERSION="1.3"

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
GATE_ROLL_WIT=""          # "<id>\t<evidence>" lines, for judgment steps with an artifact

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

# --- record that a JUDGMENT step produced its artifact ---------------------------------
# Called by the gate when it can SEE the thing a prose step was supposed to produce. It
# takes the evidence as a string and stores it verbatim, because "witnessed" with no note
# is an assertion wearing a measurement's clothes -- a reader must be able to check the
# claim without re-running the gate.
#
# This function does NOT grade the artifact and must never be given a quality judgment as
# its evidence. It answers "did this step leave a trace", full stop. The moment it starts
# answering "was the trace any good" it has collapsed the two questions this whole library
# exists to keep apart.
gate_witness() {   # <judgment-id> <evidence, verbatim and checkable>
  [ -n "${1:-}" ] || return 0
  case "$GATE_ROLL_WIT" in *"
$1	"*) return 0 ;; esac
  GATE_ROLL_WIT="${GATE_ROLL_WIT}
$1	${2:-artifact present}"
}

# --- did the session ASSERT it walked this step? ---------------------------------------
# GATE_ANSWERED="G-C G-G" (spaces or commas). Deliberately a SEPARATE state from WITNESSED:
# -10 chose an unconditional sidecar over an opt-in flag because opt-in instruments get
# forgotten, and that reasoning holds here -- which is exactly why an unset GATE_ANSWERED
# must produce UNWITNESSED rows rather than nothing at all. The flag being forgotten is then
# VISIBLE in the sidecar, instead of being the silence it replaced.
_rc_declared() {   # <id> -> 0 if the session claimed this step
  [ -n "${GATE_ANSWERED:-}" ] || return 1
  case " $(printf '%s' "$GATE_ANSWERED" | tr ',' ' ') " in *" $1 "*) return 0 ;; esac
  return 1
}

# --- the head id of a gate message ----------------------------------------------------
# The gate writes "<id>: ..." or "<id> CANNOT VERIFY: ...", so the id is everything up to
# the first ':' or space. No prefix guessing anywhere in this file: a message belongs to
# the row the MANIFEST says it belongs to, and to nothing otherwise. Prefix inference is
# how "G-A" would silently answer for "G-AB" — a confident wrong owner, which is the
# family of bug this whole instrument exists to stop reproducing.
# The manifest token that grants a judgment row the fourth word (v1.3). ONE definition, so the
# drill's mutant F can neuter the lookup by rewriting this line alone.
_rc_unwit_tok='^\[unwitnessable\]'

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
# parent "-"        the row is a REACH UNIT: a place `gate_ran` is called, one per check.
# parent "judgment" the row is a JUDGMENT STEP: a HANDOFF-GATE.md section a session walks by
#                   reading prose. No `gate_ran` marker exists or should; its states are
#                   WITNESSED / DECLARED / UNWITNESSED and never `pass`. The third column
#                   names what a witness for that step would be.
# any other parent  the row is a VERDICT ALIAS — a label the gate speaks under from inside a
#                   reach unit's branches (G-AL#board lives inside G-AL). Aliases are declared
#                   rather than inferred, so the roll call never has to guess who spoke.
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
      echo "# manifest_fp=$(_rc_manifest_fp "$_mf") units_declared=$(awk -F'\t' '!/^#/ && NF>=2 && $2=="-"' "$_mf" 2>/dev/null | grep -c . || echo 0) judgment_declared=$(awk -F'\t' '!/^#/ && NF>=2 && $2=="judgment"' "$_mf" 2>/dev/null | grep -c . || echo 0)"
      echo "# NOT-REACHED = declared and never reached. UNDECLARED = spoke without a manifest row."
      echo "# WITNESSED / DECLARED / UNWITNESSED / UNWITNESSABLE are the JUDGMENT states -- prose steps a session walks."
      echo "# UNWITNESSABLE = the manifest row is marked [unwitnessable]: no witness can exist by construction (G-O)."
      echo "# Not one of the three is 'pass': nothing here grades an answer, only whether one left a trace."
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
    local _units _aliasmap _judg _judgdesc _id _par _desc
    _units=""; _aliasmap=""; _judg=""; _judgdesc=""
    while IFS= read -r _line; do
      case "$_line" in ''|'#'*) continue ;; esac
      _id="${_line%%	*}"; _line="${_line#*	}"; _par="${_line%%	*}"; _desc="${_line#*	}"
      [ -n "$_id" ] || continue
      if [ "$_par" = "-" ]; then
        _units="$_units$_id
"
      elif [ "$_par" = "judgment" ]; then
        # NOT an alias. A judgment row parented to the literal word `judgment` would
        # otherwise map its verdicts onto a phantom check called "judgment" -- one
        # nonexistent owner absorbing nineteen steps, which is exactly the confident-wrong-
        # owner failure this library refuses everywhere else.
        _judg="$_judg$_id
"
        _judgdesc="$_judgdesc$_id	$_desc
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
        # A judgment row IS declared -- it is not UNDECLARED merely because no `gate_ran`
        # marker names it. It owns anything spoken under its own id.
        if [ -z "$_owner" ]; then
          case "
$_judg" in *"
$_head
"*) _owner="$_head" ;; esac
        fi
        if [ -z "$_owner" ]; then
          _owner="$(printf '%s' "$_aliasmap" | sed -n "s/^$_head	//p" | head -1)"
        fi
        if [ -z "$_owner" ]; then
          _owned="$_owned$_head	UNDECLARED
"
        elif [ "$_owner" != "$_head" ]; then
          # An ALIAS spoke for its parent (manifest: `G-AL#done  G-AL`). The verdict lands on
          # the parent by design -- but the parent's row must SAY who spoke, or a parent that
          # passed in its own voice and a parent that warned in its own voice read the same
          # once a child warns (SM 1218279533293599: `G-AL  warn  ` with G-AL itself silent).
          _owned="$_owned$_owner	$_sev	$_head
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
      if   printf '%s' "$_owned" | grep -q "^$_id	fail";    then _state="fail"
      elif printf '%s' "$_owned" | grep -q "^$_id	skipped"; then _state="skipped"
      elif printf '%s' "$_owned" | grep -q "^$_id	warn";    then _state="warn"
      elif printf '%s' "$_owned" | grep -q "^$_id	na";      then _state="n/a"
      elif printf '%s' "$GATE_ROLL_NA" | grep -q "^$_id	"; then
        _state="n/a"; _note="$(printf '%s' "$GATE_ROLL_NA" | sed -n "s/^$_id	//p" | head -1)"
      else
        case "$GATE_ROLL_SEEN" in
          *" $_id "*) _state="pass"; _note="reached; silent" ;;
          *) _state="NOT-REACHED"
             _note="declared in the manifest and never reached this run — a silent pass and a skipped check are NOT the same fact" ;;
        esac
      fi
      # The speaker, when it was not the row itself. Only ALIASES carried by this run are
      # named; a verdict the unit spoke in its own voice leaves the note as it was.
      [ -n "$_note" ] || _note="$(printf '%s' "$_owned" | awk -F'\t' -v i="$_id" -v s="$_state" '$1==i && $2==s && $3!="" { print "spoken by " $3 " (an alias declared under this row); the row itself was silent"; exit }')"
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

    # --- the JUDGMENT half: one row per prose step the gate declares but cannot run ----
    # Emitted AFTER the reach units and never mixed with them, because the two halves answer
    # different questions and a table that interleaves them invites exactly one mistake:
    # reading UNWITNESSED as a coverage gap. It is not. A judgment step has no box routing --
    # it is walked by a session, and every box will report the same thing about it.
    #
    # RESOLUTION ORDER, and the first line of it is the interesting one: if a judgment id
    # actually SPOKE a verdict, that verdict wins over any witness. A step that failed did
    # not merely leave a trace; saying WITNESSED over the top of its own FAIL would be the
    # substitution of "it happened" for "it went well" that the whole library refuses.
    local _jstate _jnote
    if [ -n "$_judg" ]; then
      printf '#--- judgment steps: HANDOFF-GATE.md sections a session walks by reading prose ---\n' >> "$_out"
      while IFS= read -r _id; do
        [ -n "$_id" ] || continue
        _jnote=""
        if   printf '%s' "$_owned" | grep -q "^$_id	fail";    then _jstate="fail"
        elif printf '%s' "$_owned" | grep -q "^$_id	skipped"; then _jstate="skipped"
        elif printf '%s' "$_owned" | grep -q "^$_id	warn";    then _jstate="warn"
        elif printf '%s' "$_owned" | grep -q "^$_id	na";      then _jstate="n/a"
        elif printf '%s' "$GATE_ROLL_WIT" | grep -q "^$_id	"; then
          _jstate="WITNESSED"
          _jnote="$(printf '%s' "$GATE_ROLL_WIT" | sed -n "s/^$_id	//p" | head -1)"
        elif _rc_declared "$_id"; then
          _jstate="DECLARED"
          _jnote="the session asserted it walked this step (GATE_ANSWERED) -- an assertion, recorded as one; nothing checked it"
        elif printf '%s' "$_judgdesc" | sed -n "s/^$_id	//p" | head -1 | grep -q "$_rc_unwit_tok"; then
          # THE FOURTH WORD (v1.3, SM 1218279408870769). A step the manifest itself marks
          # `[unwitnessable]` -- G-O: the paste happens in the chat, AFTER the gate -- can never
          # earn a witness, so leaving it in the UNWITNESSED bucket beside the rows that merely
          # lack a detector trains readers to scroll past that bucket: permanent red as
          # wallpaper, the disease the roll call treats, applied to its own instrument. The
          # token lives in the MANIFEST, not here, so the word cannot be applied by hand to a
          # row that is simply unbuilt; and it sits BELOW every rung above on purpose -- a
          # verdict spoken under the id, an artifact, or an assertion still outranks it.
          _jstate="UNWITNESSABLE"
          _jnote="cannot be witnessed from inside the gate by construction -- not a gap, not a red, not a detector nobody built. Row: $(printf '%s' "$_judgdesc" | sed -n "s/^$_id	\[unwitnessable\] *//p" | head -1)"
        else
          _jstate="UNWITNESSED"
          # "Row:" and not "A witness would be:" -- the manifest's third column already says
          # that in its own words, and the doubled phrase read as a stutter in the first live
          # sidecar. The row is quoted verbatim so the note carries the STEP as well as the
          # candidate witness; a reader who has never opened the manifest still learns both.
          _jnote="no artifact, no assertion -- nobody can say whether this step happened. Row: $(printf '%s' "$_judgdesc" | sed -n "s/^$_id	//p" | head -1)"
        fi
        printf '%s	%s	%s\n' "$_id" "$_jstate" "$_jnote" >> "$_out"
      done <<JUDG
$_judg
JUDG
    fi

    # --- a witness for a step no manifest row declares --------------------------------
    # Same reverse closure the mechanical half gets. A gate_witness call for an id nobody
    # declared is a witness nothing will ever read, which is worse than no witness: it looks
    # like coverage from inside the gate and is invisible from outside it.
    # printf '%s\n', not '%s': GATE_ROLL_WIT has no trailing newline, and `read` returns
    # non-zero at EOF WITHOUT one, so the last witness -- the most recently added, the one a
    # session is most likely to be debugging -- would be silently dropped by the loop.
    printf '%s\n' "$GATE_ROLL_WIT" | sed '/^$/d' | while IFS="	" read -r _id _rest; do
      [ -n "$_id" ] || continue
      case "
$_judg" in *"
$_id
"*) continue ;; esac
      printf '%s	UNDECLARED	gate_witness fired for this id but no manifest row declares it as a judgment step -- add a row: <id> <TAB> judgment <TAB> <what a witness would be>\n' "$_id" >> "$_out"
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
  awk -F'\t' '!/^#/ && NF>=2 && $2!="WITNESSED" && $2!="DECLARED" && $2!="UNWITNESSED" \
    { printf "  %-16s %-12s %s\n", $1, $2, substr($3,1,88) }' "$_f"
  local _bad _jn _jw _jd _ju
  _bad="$(awk -F'\t' '!/^#/ && ($2=="NOT-REACHED" || $2=="UNDECLARED" || $2=="cannot-verify")' "$_f" | grep -c . || true)"
  echo "  ── $_bad row(s) the coverage question cares about ──"
  # The judgment half prints as its own block. Interleaving it would invite the one wrong
  # reading available here: UNWITNESSED is not a coverage gap and not a red -- it is the
  # gate saying out loud that nothing recorded whether a prose step happened, which is a
  # fact it could not state at all before v1.2.
  _jn="$(awk -F'\t' '!/^#/ && ($2=="WITNESSED" || $2=="DECLARED" || $2=="UNWITNESSED")' "$_f" | grep -c . || true)"
  if [ "${_jn:-0}" -gt 0 ]; then
    echo
    echo "  ── judgment steps · walked by a session, not by this script ──"
    awk -F'\t' '!/^#/ && ($2=="WITNESSED" || $2=="DECLARED" || $2=="UNWITNESSED") \
      { printf "  %-16s %-12s %s\n", $1, $2, substr($3,1,88) }' "$_f"
    _jw="$(awk -F'\t' '!/^#/ && $2=="WITNESSED"'   "$_f" | grep -c . || true)"
    _jd="$(awk -F'\t' '!/^#/ && $2=="DECLARED"'    "$_f" | grep -c . || true)"
    _ju="$(awk -F'\t' '!/^#/ && $2=="UNWITNESSED"' "$_f" | grep -c . || true)"
    echo "  ── $_jn judgment step(s): $_jw witnessed, $_jd declared, $_ju with no evidence either way ──"
  fi
  return 0
}
