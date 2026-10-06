#!/usr/bin/env python3
"""specF strict gate: STRICT one-statement-per-line bracket audit.

wlcheck.py (sdeA) does NET balance only, and net balance is defeatable:
one extra ']' next to one missing ']' nets to zero, wlcheck prints "ok",
and `wolframscript -script` then SILENTLY SKIPS the rest of the file and
still exits 0.  Observed twice in specF.  So specF scripts are written
one statement per line, and this gate audits EACH line independently
(every line must start and end at depth 0).  Plus: the script must end
with a terminal `sf["DONE-<tag>"]` sentinel, verified in the run log.
"""
import sys

OPEN, CLOSE = "([{", ")]}"
bad = 0
for path in sys.argv[1:]:
    raw = open(path).read()
    # strip comments (*...*, nesting) and strings, preserving newlines
    out, i, n, dc, line, probs = [], 0, len(raw), 0, 1, []
    while i < n:
        if raw[i] == "\n":
            line += 1; out.append("\n"); i += 1; continue
        if dc:
            if raw.startswith("(*", i): dc += 1; out.append("  "); i += 2; continue
            if raw.startswith("*)", i): dc -= 1; out.append("  "); i += 2; continue
            out.append(" "); i += 1; continue
        if raw.startswith("(*", i): dc = 1; out.append("  "); i += 2; continue
        if raw[i] == '"':
            out.append(" "); i += 1
            while i < n and raw[i] != '"':
                if raw[i] == "\\": out.append(" "); i += 1; out.append(" "); i += 1; continue
                if raw[i] == "\n": probs.append((line, "unterminated string")); line += 1; out.append("\n")
                else: out.append(" ")
                i += 1
            if i >= n: probs.append((line, "string never closed"))
            else: out.append(" "); i += 1
            continue
        out.append(raw[i]); i += 1
    if dc: probs.append((line, "comment never closed"))
    for ln, txt in enumerate(out if False else "".join(out).split("\n"), 1):
        stack = []
        for c in txt:
            if c in OPEN: stack.append(c)
            elif c in CLOSE:
                if not stack:
                    probs.append((ln, "stray '%s'" % c)); break
                want = {"(": ")", "[": "]", "{": "}"}[stack[-1]]
                if c != want:
                    probs.append((ln, "'%s' closes '%s'" % (c, stack[-1]))); break
                stack.pop()
        if stack:
            probs.append((ln, "line ends at depth %d (multi-statement line)" % len(stack)))
    if "DONE-" not in raw: probs.append((0, "no terminal DONE-<tag> sentinel"))
    # THE "." TRAP.  In wolframscript -script mode a statement ended by a
    # bare "." (instead of ";") makes the NEXT statement parse as
    # `Null . head` when the preceding statement evaluated to Null --
    # i.e. `SetDelayed::write: Tag Dot in Null . head is Protected` --
    # and that statement is SILENTLY SKIPPED while the script exits 0.
    # sf[] ends in Print[], so it returns Null: this bites on every line
    # following an sf[] call.  Always terminate with ";".
    for ln, txt in enumerate("".join(out).split("\n"), 1):
        s = txt.rstrip()
        if s.endswith(".") and not s.endswith(".."):
            probs.append((ln, "statement terminated by '.' -- use ';' (Null . head trap)"))
    if probs:
        bad = 1
        print("FAIL %s" % path)
        for p in probs[:8]: print("   line %s: %s" % p)
    else:
        print("ok %s" % path)
sys.exit(bad)
