#!/bin/bash
# =============================================================================
# secret-re.sh — the ONE secret-shape regex for the whole estate (SSOT).
#
# Born 2026-08-08 (S45). Before this file, the credential regex lived inline in
# gate-selfcheck.sh (G-E) only, and the estate's pre-commit protection was
# per-repo and uneven: ~/Desktop/downloads blocked a credential-shaped literal at
# commit time while ~/code/darwin-mac-ops -- the repo that HOLDS gate-selfcheck.sh
# -- accepted the same literal without a murmur an hour earlier (S44 finding).
#
# Two readers, one needle, so detect-at-wrap and refuse-at-commit can never
# disagree about what a secret looks like:
#   * ~/Scripts/gate-selfcheck.sh  G-E   (WARN at wrap, whole tracked tree)
#   * ~/code/darwin-mac-ops/hooks/pre-commit (BLOCK at commit, staged index)
#
# Sourced, never executed. Defines: SECRET_RE, GE_ALLOW, ge_load_allow, ge_allowed.
#
# ⚠ SELF-INDICT RULE (global lesson 2026-07-07): a tracked file that NAMES the
# needle matches itself. The patterns below are safe because each one's literal
# text fails its own match (e.g. "shpat_[a-f0-9]{32}" has no 32 hex chars, and
# "[A-Z ]*" is not itself in [A-Z ]). Verify that property before adding a
# pattern, or this file becomes its own first false positive. Do NOT paste a
# real-shaped example key into this file or the allowlist -- S44 spelled out
# AWS's documentation example key in a comment and G-E bit the very file
# written to quiet it.
# =============================================================================

# Tight patterns: each requires the real high-entropy tail, so prose mentions of
# "shpat_" or a regex literal in a doc do not trip it.
SECRET_RE='shpat_[a-f0-9]{32}|sk-[A-Za-z0-9]{32,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{50,}|xox[baprs]-[0-9A-Za-z-]{20,}|AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY-----'

# Repo-backed home. A ~/Scripts copy is SILENTLY swallowed by that repo's '*secret*'
# ignore rule -- a control file git ignores is not backed, and it took a `git status`
# that showed nothing to notice (S44). ~/Scripts/gate-secret-sweep.allow is a symlink here.
GE_ALLOW="${GE_ALLOW:-$HOME/code/darwin-mac-ops/gate-secret-sweep.allow}"

declare -a GE_PATS=(); declare -a GE_NOREASON_PATS=()
GE_NOREASON=0; GE_SUPPRESSED=0

# ge_load_allow -- parse GE_ALLOW into GE_PATS. The reason after '#' is MANDATORY:
# an exemption nobody justified is indistinguishable from an oversight six weeks later.
ge_load_allow() {
  GE_PATS=(); GE_NOREASON_PATS=(); GE_NOREASON=0; GE_SUPPRESSED=0
  [ -f "$GE_ALLOW" ] || return 0
  local al pat reason
  while IFS= read -r al; do
    al="${al%%$'\r'}"
    case "$al" in ''|'#'*) continue ;; esac
    pat="${al%%#*}"; reason="${al#*#}"
    pat="$(printf '%s' "$pat" | sed -E 's/[[:space:]]+$//')"
    [ -z "$pat" ] && continue
    if [ "$reason" = "$al" ] || [ -z "$(printf '%s' "$reason" | tr -d '[:space:]')" ]; then
      GE_NOREASON=$((GE_NOREASON+1))
      GE_NOREASON_PATS[${#GE_NOREASON_PATS[@]}]="$pat"
    fi
    GE_PATS[${#GE_PATS[@]}]="$pat"
  done < "$GE_ALLOW"
  return 0
}

# ge_allowed <repo-basename>/<path> -- 0 if suppressed by an allowlist glob.
ge_allowed() {
  local k="$1" p
  [ "${#GE_PATS[@]}" -eq 0 ] && return 1
  for p in "${GE_PATS[@]}"; do
    case "$k" in $p) return 0 ;; esac
  done
  return 1
}

# ge_mask <line> -- print the matched token with its high-entropy tail masked.
# Never print the raw line: truncation can DISPLAY a leading jsCode comment while
# HIDING the real secret deeper on the same line (2026-07-07, COGS workflows).
ge_mask() {
  printf '%s' "$1" | grep -oE "$SECRET_RE" | head -1 | sed -E 's/(.{10}).*/\1…MASKED/'
}

# =============================================================================
# THE SECOND SHAPE: a PRIMARY ACCOUNT NUMBER  (S15 smDrainHandoff, SM 1217561601836055)
#
# SECRET_RE above is a set of VENDOR-PREFIX needles. A card number has no vendor
# prefix and no high-entropy tail — it is sixteen digits — so G-AF could report
# 114 of 114 repos protected while every one of them accepted a live PAN without
# a murmur. That is the coverage-vs-capability gap in its purest form: coverage
# (N of N repos wired) and capability (the scanner can SEE the thing) read
# IDENTICALLY when green, and only one of them was ever measured.
# (Global lesson 2026-08-17-secret-scanning-gate-reports-coverage-n, filed from
# the AAR of a real PAN written into a wisdom repo while this hook was green.)
#
# A DIGIT-RUN REGEX IS NOT A CARD-NUMBER DETECTOR (global lesson 2026-08-07):
# 'a run of >=12 digits' fires on timestamps, order ids, phone strings and shas.
# Three independent constraints turn it into one, and all three are required:
#   1. LENGTH   — exactly 13..19 digits after separators are stripped
#   2. IIN      — a real issuer prefix, at a length that issuer actually issues
#   3. LUHN     — the mod-10 check digit is correct (1 in 10 random runs survive)
# Regex can only do (1). So the grep below is a cheap SHORTLIST and the verdict
# is ge_pan_token()'s; a caller that greps PAN_RE and reports the hit WITHOUT
# calling ge_pan_token has built the false-positive machine this comment warns
# about, and it fails closed on every commit in the estate.
#
# ⚠ SELF-INDICT, same rule as SECRET_RE: nothing below is a Luhn-valid 13..19
# digit run. '5[1-5]' and '6011' are prefixes, not cards. NEVER paste a
# card-shaped literal here or into gate-secret-sweep.allow — synthesize it at
# runtime the way hooks-drill.sh synthesizes the shpat_ needle.
# =============================================================================

# Cheap ERE shortlist: 13..19 digits with optional single space/dash separators.
# Deliberately a SUPERSET — it is wrong on its own and is never the verdict.
# The flanking [^0-9] guards are not cosmetic: without them this matches the first
# 19 digits of a 40-digit blob and hands ge_pan_token a substring of a nonce. They
# also carry most of the shortlist's SPEED -- an untethered run matched a large
# fraction of every minified/lockfile line in the estate.
PAN_RE='(^|[^0-9])[2-6]([ -]?[0-9]){12,18}([^0-9]|$)'

# ge_luhn <digits> -- 0 iff the mod-10 check digit is correct.
ge_luhn() {
  local d="$1" n=${#1} sum=0 i=0 dbl=0 v
  i=$((n-1))
  while [ "$i" -ge 0 ]; do
    v=$(( 10#${d:i:1} ))
    if [ "$dbl" -eq 1 ]; then v=$(( v * 2 )); [ "$v" -gt 9 ] && v=$(( v - 9 )); fi
    sum=$(( sum + v )); dbl=$(( 1 - dbl )); i=$(( i - 1 ))
  done
  [ $(( sum % 10 )) -eq 0 ]
}

# ge_pan_brand <digits> -- 0 iff the IIN is a real issuer AND the length is one
# that issuer actually issues. The length pairing is doing real work: a 16-digit
# run starting '34' is NOT an Amex, it is an order id, and accepting it would
# roughly triple the false-positive surface for no detection gained.
ge_pan_brand() {
  local d="$1" n=${#1} p4="${1:0:4}"
  case "$d" in
    4*)                     [ "$n" -eq 13 ] || [ "$n" -eq 16 ] || [ "$n" -eq 19 ] ;; # Visa
    34*|37*)                [ "$n" -eq 15 ] ;;                                        # Amex
    5[1-5]*)                [ "$n" -eq 16 ] ;;                                        # Mastercard
    2[2-7]*)                [ "$n" -eq 16 ] && [ "$((10#$p4))" -ge 2221 ] \
                                            && [ "$((10#$p4))" -le 2720 ] ;;          # Mastercard 2-series
    6011*|65*|64[4-9]*)     [ "$n" -eq 16 ] ;;                                        # Discover
    35*)                    [ "$n" -eq 16 ] ;;                                        # JCB
    # Diners is 36 and 300-305/3095, at 14 digits. '38'/'39' are DELIBERATELY absent:
    # they were reassigned decades ago and no issuer uses them, but they matched 109
    # of the 169 estate-wide hits in the S15 measurement -- every one a Shopify
    # Metafield GID ("gid://shopify/Metafield/38466447245480"). Carrying a dead IIN
    # range costs zero detection and buys a false-positive class big enough to get
    # the whole hook uninstalled.
    30[0-5]*|3095*|36*)     [ "$n" -eq 14 ] ;;                                        # Diners
    *) return 1 ;;
  esac
}

# ge_pan_token <line> -- print the first CONFIRMED PAN on the line, masked to the
# PCI-permitted first-6/last-4 display form, and return 0. Print nothing, rc 1,
# if the line carries no PAN.
#
# Tokenizing, and why it is not a regex: every character that cannot appear
# INSIDE a written card number becomes a separator, leaving chunks of
# [0-9 -]. A chunk whose digit count exceeds 19 is NOT a PAN — it is a sha, a
# nonce or a concatenated id — and skipping it is the single largest
# false-positive reduction available. But a long chunk can still CONTAIN a PAN as
# one of its space/dash-delimited words ("4111... 20260904"), so an over-long
# chunk is re-tried word by word rather than dropped.
ge_pan_token() {
  local line="$1" chunk d n w
  # DECIMAL FRACTIONS ARE NOT CARDS (parity-33, 2026-09-05). A float such as
  # 1.5577777773141861 (a telemetry ratio in auto-bridge's ledger-dump.sql) tokenizes
  # on the '.' into a 16-digit chunk that is Luhn-valid one time in ten and carries a
  # real IIN one time in three -- the hook blocked a ruling bank on seven of them.
  # Rule: a number whose INTEGER part is at most 12 digits and which carries a
  # fractional part is a decimal, never a PAN; blank it before tokenizing. A run of
  # 13+ digits before the '.' is left alone (a PAN glued to '.2026' is still caught).
  line="$(printf '%s' "$line" | sed -E 's/(^|[^0-9])[0-9]{1,12}\.[0-9]+/\1 /g')"
  while IFS= read -r chunk || [ -n "$chunk" ]; do
    [ -z "$chunk" ] && continue
    d="${chunk//[^0-9]/}"; n=${#d}
    if [ "$n" -ge 13 ] && [ "$n" -le 19 ]; then
      if ge_pan_brand "$d" && ge_luhn "$d"; then
        printf '%s……%s' "${d:0:6}" "${d: -4}"; return 0
      fi
    elif [ "$n" -gt 19 ]; then
      for w in $(printf '%s' "$chunk" | tr ' -' '\n\n'); do
        d="${w//[^0-9]/}"; n=${#d}
        [ "$n" -ge 13 ] && [ "$n" -le 19 ] || continue
        if ge_pan_brand "$d" && ge_luhn "$d"; then
          printf '%s……%s' "${d:0:6}" "${d: -4}"; return 0
        fi
      done
    fi
  # `|| [ -n "$chunk" ]` is load-bearing, not defensive: a PAN at END OF LINE
  # produces a final chunk with no trailing newline, which plain `read` DISCARDS.
  # Measured, not guessed -- the detector silently missed every unbroken 16-digit
  # run that ended a line while happily catching the same number mid-line.
  done < <(printf '%s\n' "$line" | tr -c '0-9 -' '\n')
  return 1
}
