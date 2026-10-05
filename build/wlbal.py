#!/usr/bin/env python3
"""wlbal.py -- TYPE-AWARE bracket check for Wolfram Language files.

Why this exists: a kind-agnostic checker reports a file as balanced when a
`)` sits where a `]` belongs, which is the single most common way a WL
script goes wrong here, and Syntax::sntx then names only the expression
AFTER the bad one.  That cost several probe runs.

Skips (* nested comments *) and strings with backslash escapes, and
requires every closing bracket to match the opener's kind.

    python3 build/wlbal.py Tests/installprobe.wl build/bundle.wl

Exit 1 if any file is unbalanced.  Lives in build/ rather than
scratch/P/ because other agents clean scratch mid-session.
"""
import sys

OPEN = {'(': ')', '[': ']', '{': '}'}
CLOSE = {')': '(', ']': '[', '}': '{'}


def check(path):
    lines = open(path, encoding='utf-8').read().split('\n')
    stack = []
    instr = False
    incom = False
    bad = False
    for ln, line in enumerate(lines, 1):
        j = 0
        while j < len(line):
            if incom:
                if line.startswith('*)', j):
                    incom = False
                    j += 2
                    continue
                j += 1
                continue
            if instr:
                if line[j] == '\\':
                    j += 2
                    continue
                if line[j] == '"':
                    instr = False
                j += 1
                continue
            if line.startswith('(*', j):
                incom = True
                j += 2
                continue
            c = line[j]
            if c == '"':
                instr = True
            elif c in OPEN:
                stack.append((c, ln))
            elif c in CLOSE:
                if not stack:
                    print(f'{path}:{ln}: UNMATCHED CLOSE {c}')
                    bad = True
                elif stack[-1][0] != CLOSE[c]:
                    o, oln = stack[-1]
                    print(f'{path}:{ln}: MISMATCH {c} closes {o} opened at line {oln}')
                    stack.pop()
                    bad = True
                else:
                    stack.pop()
            j += 1
    if incom:
        print(f'{path}: UNTERMINATED COMMENT (*')
        bad = True
    if instr:
        print(f'{path}: UNTERMINATED STRING "')
        bad = True
    for c, ln in stack:
        print(f'{path}:{ln}: UNCLOSED {c}')
        bad = True
    print(f'{path}: {"BALANCED" if not bad else "UNBALANCED"} ({len(lines)} lines)')
    return 0 if not bad else 1


rc = 0
for p in sys.argv[1:]:
    rc |= check(p)
sys.exit(rc)