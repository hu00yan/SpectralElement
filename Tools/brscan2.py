#!/usr/bin/env python3
"""brscan2.py -- read-only Wolfram Language bracket scanner for SpectralElement.

Prints `0 issue(s)` when the file is clean.  Catches the two classes that a
plain depth count misses:

  1. a CLOSER that does not match its own opener, e.g. `aaabary(a, b, c, d);`
     which WL parses as a product of four symbols.  A depth counter calls
     that file balanced; the kernel does not.
  2. an UNCLOSED opener, including one hidden by (1).

Wolfram Language comments nest, so `(*` pushes a level and `*)` pops one;
comments and strings both span newlines.  Never writes anything.
"""
import sys

PAIRS = {'(': ')', '[': ']', '{': '}'}
OPEN = set(PAIRS)
CLOSE = {v: k for k, v in PAIRS.items()}


def scan(text):
    issues = []
    stack = []           # (opener_char, line, col)
    cdepth = 0           # (* *) nesting depth
    line, col, i, n = 1, 1, 0, len(text)
    in_string = False
    while i < n:
        c = text[i]
        if c == '\n':
            line += 1
            col = 1
            i += 1
            continue
        if cdepth > 0:
            if text.startswith('(*', i):
                cdepth += 1
                i += 2
                col += 2
                continue
            if text.startswith('*)', i):
                cdepth -= 1
                i += 2
                col += 2
                continue
            i += 1
            col += 1
            continue
        if in_string:
            if c == '\\':
                i += 2
                col += 2
                continue
            if c == '"':
                in_string = False
            i += 1
            col += 1
            continue
        if text.startswith('(*', i):
            cdepth = 1
            i += 2
            col += 2
            continue
        if c == '"':
            in_string = True
            i += 1
            col += 1
            continue
        if c in OPEN:
            stack.append((c, line, col))
        elif c in CLOSE:
            if not stack:
                issues.append("L%d:%d: unmatched closer '%s'" % (line, col, c))
            elif stack[-1][0] != CLOSE[c]:
                op, ol, oc = stack[-1]
                issues.append("L%d:%d: '%s' closes the '%s' opened at L%d:%d"
                              % (line, col, c, op, ol, oc))
                stack.pop()
            else:
                stack.pop()
        i += 1
        col += 1
    if cdepth > 0:
        issues.append("unterminated (* comment *)")
    if in_string:
        issues.append("unterminated string literal")
    for op, ol, oc in stack:
        issues.append("L%d:%d: '%s' is never closed" % (ol, oc, op))
    return issues


def main():
    if len(sys.argv) < 2:
        print("usage: brscan2.py <file.wl> [...]")
        return 2
    total = 0
    for path in sys.argv[1:]:
        try:
            with open(path, 'r', encoding='utf-8', errors='replace') as fh:
                issues = scan(fh.read())
        except OSError as exc:
            print("== %s\n   cannot read: %s" % (path, exc))
            total += 1
            continue
        if issues:
            print("== %s" % path)
            for msg in issues:
                print("   %s" % msg)
        else:
            print("== %s\n   every bracket is closed by its own partner" % path)
        total += len(issues)
    print("%d issue(s)" % total)
    print("VERDICT " + ("CLEAN" if total == 0 else "PROBLEMS"))
    return 0 if total == 0 else 1


if __name__ == "__main__":
    sys.exit(main())