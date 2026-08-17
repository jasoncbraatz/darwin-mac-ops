#!/usr/bin/env python3
"""gate v2.60 — G-F recipe slot 5: ASSIGN ONE AT-BAT, DO NOT OFFER A MENU (Jason ruling).

Wording-only clarification to an existing step, exactly the shape of v2.23 and v2.25 (both
Jason rulings to G-F). NO new G-letter, so the `G-A -> G-AL` front-door range refs are
UNCHANGED -- verified by this script's own assertion below, not assumed.

ED1  header version 2.59 -> 2.60 (G-L#35c requires the header version to have a changelog
     entry; ED3 writes it, and both land in the SAME edit per this file's oldest rule).
ED2  G-F recipe slot 5 (MISSION) restated as an ASSIGNMENT with a definition of done.
ED3  changelog entry, inserted directly above v2.59.
"""
import pathlib, re, shutil, sys

DRY = "--dry" in sys.argv
GATE = pathlib.Path.home() / "Desktop" / "downloads" / "HANDOFF-GATE.md"
BAK = GATE.with_name(GATE.name + ".bak-wt69-v260")

SENTINEL = "ASSIGN ONE AT-BAT, DO NOT OFFER A MENU"

ED1_ANCHOR = "Version 2.59 (2026-08-15)."
ED1_NEW = "Version 2.60 (2026-08-17)."

ED2_ANCHOR = (
    "5. **MISSION** — the specific phase/bundle from the ROADMAP, with the recommended FIRST action + the\n"
    "   sequence rationale (why this order).\n"
)
ED2_NEW = (
    "5. **MISSION — ASSIGN ONE AT-BAT, DO NOT OFFER A MENU** (Jason ruling, 2026-08-17, v2.60). Name the\n"
    "   specific phase/bundle from the ROADMAP as **the** at-bat — singular — give it a **definition of\n"
    "   done someone could mark right or wrong**, and state the recommended FIRST action + the sequence\n"
    "   rationale (why this order). Rank whatever else is live under a heading that says plainly it is\n"
    "   **context, not a menu**, and name your best guess at the *next* session's assignment. Keep a\n"
    "   one-line escape hatch — *\"if and only if this is genuinely blocked, take the first startable item\n"
    "   below and say which, in one line, at the top of your handoff\"* — which is what makes a single\n"
    "   assignment safe rather than brittle. **Why:** the outgoing session holds context the incoming one\n"
    "   cannot recover — what it just touched, what it deliberately left, which eyes are fresh — and a\n"
    "   ranked menu throws that away and asks a cold session to re-derive the ranking from a list it has\n"
    "   no basis to rank. Jason, after eleven consecutive menus: *\"letting the future session pick which\n"
    "   to do can be either daunting, or it looks at me cross-eyed for data that's already been written\n"
    "   down somewhere.\"* **A menu is a decision handed BACKWARDS through the gap — the one direction a\n"
    "   handoff cannot carry anything.**\n"
)

ED3_ANCHOR = "- v2.59 (2026-08-15) —"
ED3_NEW = (
    "- v2.60 (2026-08-17) — **G-F recipe slot 5: ASSIGN one at-bat, do not OFFER a menu** (Jason ruling, "
    "mid-session wealthTensor-69). Handoffs in `wealth-tensor` shipped a ranked \"take one, in this order\" "
    "list for **eleven** consecutive sessions, and every one of them obeyed the recipe as written — slot 5 "
    "said *\"the specific phase/bundle … with the recommended FIRST action\"*, and a ranked list with a "
    "recommendation at the top satisfies that sentence while doing the opposite of what it is for. Jason, "
    "shown one: *\"letting the future session pick which to do can be either daunting, or it looks at me "
    "cross-eyed for data that's already been written down somewhere.\"* **Two distinct failure modes, both "
    "caused by the menu rather than by the reader** — a session either burns its opening on a choice it is "
    "worse-positioned to make than the author was, or it goes hunting for the ranking evidence, which is "
    "already in the handoff it is standing in. **The asymmetry is the whole argument: the outgoing session "
    "knows what it just touched, what it deliberately left, and which eyes are fresh; the incoming one "
    "cannot recover any of it.** A menu spends none of that and asks a cold session to re-derive the "
    "ranking anyway — a decision handed BACKWARDS through the gap, which is the one direction a handoff "
    "cannot carry anything. Slot 5 now requires: ONE named at-bat, a **definition of done someone could "
    "mark right or wrong** (the same refusal `rail.py` makes a feature), the rest ranked under a heading "
    "that says it is **context, not a menu**, a named guess at the NEXT session's assignment (free — the "
    "thinking is already done), and the `-59`-style forcing line **re-pointed at the assignment instead of "
    "at the list**, so a single assignment stays safe rather than brittle. Applied live in the same pass to "
    "`wealth-tensor/docs/HANDOFF.md`, which now carries the rule in-file so the next handoff inherits the "
    "shape rather than the habit. Banked global as `assign-do-not-offer`. Undo: "
    "`.bak-wt69-v260`. **Wording-only clarification to an existing step — no new G-letter, so the "
    "`G-A→G-AL` front-door range refs are unchanged (verified in the patch script, not assumed).** Header "
    "version and this entry bumped in the SAME edit.\n"
    "- v2.59 (2026-08-15) —"
)

EDITS = (("ED1", ED1_ANCHOR, ED1_NEW), ("ED2", ED2_ANCHOR, ED2_NEW),
         ("ED3", ED3_ANCHOR, ED3_NEW))


def norm(s):
    return re.sub(r"\s+", " ", s)


def main():
    text = GATE.read_text(encoding="utf-8")

    if norm(SENTINEL) in norm(text):
        print("already applied; refusing (exit 2)")
        sys.exit(2)

    for label, anchor, _ in EDITS:
        n = text.count(anchor)
        assert n == 1, f"{label}: literal anchor count {n} != 1"

    new = text
    for _, anchor, repl in EDITS:
        new = new.replace(anchor, repl)

    # G-L#35c: the header version MUST have a changelog line. Assert it, do not hope.
    hv = re.search(r"Version (\d+\.\d+) \(", new).group(1)
    assert re.search(rf"^- v{re.escape(hv)} ", new, re.M), f"no changelog entry for v{hv}"

    # NO new G-letter => no range ref may point anywhere new. Compare the SET of range
    # TARGETS, not the count: ED3's own changelog entry quotes "G-A→G-AL" in prose, which
    # raises the count by one without moving a single ref. (A count guard fired on exactly
    # that at authoring time -- WT-108's lesson arriving a second time in one session.)
    rng = lambda s: set(re.findall(r"G-A→G-[A-Z]+", s))
    assert rng(new) == rng(text), f"range refs moved: {rng(new) ^ rng(text)}"
    old_letters = set(re.findall(r"^## (G-[A-Z]+)", text, re.M))
    new_letters = set(re.findall(r"^## (G-[A-Z]+)", new, re.M))
    assert old_letters == new_letters, f"G-letters changed: {new_letters ^ old_letters}"

    if DRY:
        print(f"DRY: three edits would apply cleanly; header -> v{hv}; "
              f"{len(new_letters)} G-letters unchanged")
        return

    shutil.copy2(GATE, BAK)  # the undo path comes FIRST
    GATE.write_text(new, encoding="utf-8")

    after = GATE.read_text(encoding="utf-8")
    assert norm(SENTINEL) in norm(after), "sentinel absent after apply"
    for label, anchor, repl in EDITS:
        assert repl in after, f"{label}: replacement absent after apply"
    assert "Version 2.59 (2026-08-15)." not in after, "old header version survived"
    print("APPLIED: v2.60; bak =", BAK.name)


if __name__ == "__main__":
    main()
